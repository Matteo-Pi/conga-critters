"""Line-cap proposal (docs/drafts/line-cap-100.md): free lines capped at 100, Longer Leash x1.5 to 150,
rebirth gives no capacity. Runs scenarios on econ_sim.py's model, 8 processes, and writes medians as JSON.

    python3 tools/line_cap_100.py calibrate 150                      # fit rebirth LP needs to 164/425/866 min
    python3 tools/line_cap_100.py compare 300 tuned.json out.json     # the rebirth replacements
    python3 tools/line_cap_100.py passes 300 tuned.json out.json '{"pen_rate": 0.0005}'   # passes, extra overrides

tuned.json holds {"rebirth_lp": [...], "rebirth_coins": [...]}. Not part of the game; delete once decided."""
import copy
import json
import os
import sys
from multiprocessing import Pool

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import econ_sim as es  # noqa: E402

PLAYERS = int(sys.argv[2]) if len(sys.argv) > 2 else 200
HOURS = 22
SEED = 7


def one(args):
    p, i, kw = args
    rng = np.random.default_rng(SEED * 100003 + i)
    ms, runs = es.simulate(p, rng, HOURS, **kw)
    # keep only what the summary needs
    inc = {}
    for a, b in es.WINDOWS:
        inc[a] = es.income_per_min(runs, a, b)
    share = {a: es.pen_share(runs, a, b) for a, b in es.WINDOWS}
    caps = [r[6] for r in runs]
    return ms, inc, share, max(caps)


def run(p, players=None, **kw):
    players = players or PLAYERS
    with Pool(8) as pool:
        return pool.map(one, [(p, i, kw) for i in range(players)])


def med(res, key):
    v = [ms[key] / 60 for ms, *_ in res if key in ms]
    return (float(np.median(v)), len(v) / len(res)) if v else (float("nan"), 0.0)


def held(res, k):
    v = [ms[f"coins_at_rebirth_{k}"] for ms, *_ in res if f"coins_at_rebirth_{k}" in ms]
    return float(np.median(v)) if v else float("nan")


def summary(label, p, res):
    out = {"label": label}
    for key in ("tier_1_r0", "line_100", "tier_2_r0", "all_max_r0", "rebirth_1", "tier_2_r1",
                "line_100_r1", "rebirth_2", "line_100_r2", "rebirth_3"):
        out[key] = med(res, key)
    out["back_to_100_after_r1"] = float(np.median([
        (ms["line_100_r1"] - ms["rebirth_1"]) / 60 for ms, *_ in res if "line_100_r1" in ms and "rebirth_1" in ms]
        or [float("nan")]))
    for k in (1, 2, 3):
        need = es.rebirth_needs(p, k - 1)[1]
        out[f"held_ratio_{k}"] = held(res, k) / need if need > 1 else float("nan")
        out[f"held_{k}"] = held(res, k)
        v = [ms[f"income_min_{k}"] for ms, *_ in res if f"income_min_{k}" in ms]
        out[f"income_before_{k}"] = float(np.median(v)) if v else float("nan")
    for a, b in es.WINDOWS:
        out[f"inc_{a // 60}"] = float(np.median([inc[a] for _, inc, _, _ in res]))
        s = [sh[a] for _, _, sh, _ in res if sh[a] is not None]
        out[f"pen_{a // 60}"] = float(np.median(s)) if s else float("nan")
    out["max_cap"] = max(c for *_, c in res)
    return out


def base_today():
    return copy.deepcopy(es.DEFAULTS)


def cap100(conga_top=4.0):
    p = copy.deepcopy(es.DEFAULTS)
    p["leash"] = [10, 15, 20, 30, 40, 50, 65, 80, 100]          # current levels 1-9, track ends at 100
    p["cost"]["Leash"] = [30, 80, 200, 500, 2_000, 6_000, 15_000, 40_000]
    p["line_cap"] = 150
    p["rebirth_leash"] = 0
    p["conga"] = [[1, 1], [10, 1.25], [25, 1.5], [50, 2], [75, 2.5], [100, 3], [125, 3.5], [150, conga_top]]
    return p


def calibrate(p, targets=(164, 425, 866), players=150, kw=None):
    """Fit rebirth LP needs 1-3 (coins need off) to hit the target medians, then coin needs = held / 1.25."""
    kw = kw or {}
    p = copy.deepcopy(p)
    p["rebirth_coins"] = [1.0] * 5
    lp = list(p["rebirth_lp"])
    for k in range(3):
        lo, hi = lp[k] * 0.2, lp[k] * 1.5
        for _ in range(9):
            mid = (lo * hi) ** 0.5
            lp[k] = mid
            p["rebirth_lp"] = lp[:k + 1] + [x * mid / es.DEFAULTS["rebirth_lp"][k] for x in es.DEFAULTS["rebirth_lp"][k + 1:]]
            t = med(run(p, players, **kw), f"rebirth_{k + 1}")[0]
            if t != t or t > targets[k]:
                hi = mid
            else:
                lo = mid
        lp[k] = (lo * hi) ** 0.5
        print(f"  rebirth {k + 1}: LP need {lp[k]:,.0f}", flush=True)
    scale = lp[2] / es.DEFAULTS["rebirth_lp"][2]
    p["rebirth_lp"] = lp[:3] + [x * scale for x in es.DEFAULTS["rebirth_lp"][3:]]
    res = run(p, players, **kw)
    coins = [held(res, k) / 1.25 for k in (1, 2, 3)]
    cscale = coins[2] / es.DEFAULTS["rebirth_coins"][2]
    p["rebirth_coins"] = coins + [x * cscale for x in es.DEFAULTS["rebirth_coins"][3:]]
    return p


if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "calibrate":
        p = calibrate(cap100())
        print(json.dumps({"rebirth_lp": p["rebirth_lp"], "rebirth_coins": p["rebirth_coins"]}))
    elif mode == "compare":
        tuned = json.load(open(sys.argv[3]))
        rows = []
        rows.append(summary("Today (cap 300, +10/rebirth)", base_today(), run(base_today())))
        naive = cap100()
        rows.append(summary("Cap 100, today's rebirth needs", naive, run(naive)))
        b = cap100()
        b.update(tuned)
        rows.append(summary("Cap 100, needs refitted (no rebirth gain)", b, run(b)))
        opts = [
            ("1: walk speed +1/rebirth, max +3", dict(rebirth_speed=1, rebirth_speed_max=3)),
            ("2: cooldown -0.05 s/rebirth, min 0.5", dict(rebirth_cooldown=0.05)),
            ("3a: bait luck +0.12/rebirth", dict(rebirth_luck=0.12)),
            ("3b: pen slot +1/rebirth", dict(rebirth_pen=1)),
            ("Mix: 2 + 3b", dict(rebirth_cooldown=0.05, rebirth_pen=1)),
        ]
        for label, extra in opts:
            q = copy.deepcopy(b)
            q.update(extra)
            rows.append(summary(label, q, run(q)))
        json.dump(rows, open(sys.argv[4], "w"), indent=1)
        print("done")
    elif mode == "passes":
        tuned = json.load(open(sys.argv[3]))
        extra = json.loads(sys.argv[5]) if len(sys.argv) > 5 else {}
        rows = []
        for top in (4.0, 3.75):
            b = cap100(top)
            b.update(tuned)
            b.update(extra)
            for label, kw in (("Free", {}), ("2x Coins", dict(coins_pass=True)), ("Longer Leash", dict(leash_pass=True)),
                              ("All passes, 8 favourites", dict(coins_pass=True, leash_pass=True, favourites=8))):
                rows.append(summary(f"Conga x{top:g} at 150 / {label}", b, run(b, **kw)))
        today = base_today()
        for label, kw in (("Free", {}), ("Longer Leash", dict(leash_pass=True)), ("2x Coins", dict(coins_pass=True)),
                          ("All passes, 8 favourites", dict(coins_pass=True, leash_pass=True, favourites=8))):
            rows.append(summary(f"Today / {label}", today, run(today, **kw)))
        json.dump(rows, open(sys.argv[4], "w"), indent=1)
        print("done")
