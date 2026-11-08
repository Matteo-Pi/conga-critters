#!/usr/bin/env python3
"""Conga Critters economy model.
 
Repo path: /tools/econ_sim.py. Companion to /docs/economy.md, whose section 6 reports
this script's output. It simulates players run by run: walking out, throwing, cuts,
delivery, the pen, upgrades, biome unlocks and rebirths. Every number in DEFAULTS
mirrors economy.md section 5: change both together, then re-run.
 
What it leaves out (economy.md 6.9): what storage holds (only the Storage track's coin
cost is modelled), stealing gains, daily coin rewards, events other than Golden Hour,
tier-matched event biomes, offline time, Index detours and players who don't play
optimally. VIP, Friend Boost and event coin boosts can be tried with --set extra_coin.
 
Usage:
    python3 tools/econ_sim.py                                  # free player and each pass
    python3 tools/econ_sim.py --players 1000 --hours 22 --seed 7
    python3 tools/econ_sim.py --free-only --favourites         # favourites after a rebirth
    python3 tools/econ_sim.py --free-only --set 'pen_rate=0.0005'
    python3 tools/econ_sim.py --free-only --set extra_coin=2    # a flat +100% coin bonus (economy.md 6.10)
    python3 tools/econ_sim.py --free-only \\
        --set 'tiers=[["Sunny Meadow",1,1,0],["Jungle",10,5,1000],["Snowy Peaks",100,25,50000],["Tier 4",1000,125,4000000]]' \\
        --set 'rebirth_lp=[1000000,2500000,10000000,25000000,60000000]'
"""
from __future__ import annotations
 
import argparse
import copy
import json
 
import numpy as np
 
DEFAULTS = dict(
    # ---- critters (economy.md 5.1-5.2)
    weights=[70, 22, 6, 1.6, 0.35, 0.05],          # Common .. Mythic
    golden_table=[0, 0, 70, 22, 7, 1],              # Golden Bait rarity weights
    value=[5, 15, 50, 200, 1_000, 10_000],          # coins
    lp=[1, 2, 4, 8, 16, 32],                        # Lead Power
    species=[3, 2, 2, 1, 1, 1],                     # species per rarity per launch biome
    golden=0.02, rainbow=0.001, golden_x=3, rainbow_x=10,
    golden_hour=5 / 60,                             # share of play time in Golden Hour
    # ---- world (5.3) and movement (spec 3.1, 4.3)
    tiers=[["Sunny Meadow", 1, 1, 0], ["Jungle", 10, 5, 1_000], ["Snowy Peaks", 100, 25, 50_000]],
    bands=[["Near", 65, 1.0], ["Mid", 200, 1.25], ["Far", 335, 1.5]],
    pen_to_gate=120, first_pen_to_gate=40,          # studs
    base_speed=20, throw_every=1.0, join_delay=1.8, overhead=8.0,
    cut_chance=0.12, cut_max_share=0.5, beginner_shield=300,
    conga=[[1, 1], [10, 1.25], [25, 1.5], [50, 2], [100, 3], [150, 3.5], [200, 4], [300, 5]],
    line_cap=300, luck_cap=10,
    # ---- upgrades (5.5): cost[track][n - 2] is the price of level n
    leash=[10, 15, 20, 30, 40, 50, 65, 80, 100, 125, 150, 175, 200],
    bait_step=0.12,
    cost=dict(
        Leash=[30, 80, 200, 500, 2_000, 6_000, 15_000, 40_000, 250_000, 700_000, 2e6, 5e6],
        Bait=[50, 150, 400, 1_000, 3_000, 10_000, 30_000, 80_000, 250_000, 700_000, 2e6, 5e6, 12e6, 30e6],
        Pen=[100, 300, 800, 2_500, 8_000, 25_000, 70_000, 200_000, 600_000, 1.5e6, 4e6, 10e6],
        Speed=[75, 250, 800, 3_000, 10_000, 40_000, 150_000, 500_000],
        Storage=[2_000, 20_000, 200_000, 1e6, 3e6, 8e6],   # only its cost is modelled
    ),
    # ---- pen income (5.6), rebirth (5.7), Index (5.8), Golden Bait (5.9)
    pen_rate=0.0006,                                # coins/s per coin of value in a pen slot
    rebirth_tier=2,                                 # tiers index that rebirth needs (Snowy Peaks)
    rebirth_lp=[1e6, 2.5e6, 5e6, 12.5e6, 30e6],
    rebirth_coins=[20e6, 200e6, 800e6, 3e9, 12e9],
    rebirth_growth_lp=2.5, rebirth_growth_coins=4,  # each rebirth after the table
    rebirth_bonus=0.15, rebirth_leash=10,
    # per-rebirth gains besides the bonus (all 0 today; docs/drafts/line-cap-100.md compares them)
    rebirth_speed=0, rebirth_speed_max=0,           # walk speed +n per rebirth, at most +max
    cooldown=0.8, rebirth_cooldown=0.0, cooldown_min=0.5,  # throw cooldown (inside throw_every) − n per rebirth
    rebirth_luck=0.0,                               # bait luck +n per rebirth (before the band's factor)
    rebirth_pen=0,                                  # pen slots +n per rebirth
    leash_pass_x=1.5,                               # Longer Leash multiplier
    index_bonus=0.10,                               # per completed Normal set, added together; no cap
    extra_coin=1.0,                                 # other coin boosts as one multiplier (VIP 1.1, Friend Boost, events)
    golden_bait_per_hour=4,                         # daily ladder + Stand, per hour played
)
 
TRACK_MAX = {"Leash": 13, "Bait": 15, "Pen": 13, "Speed": 9, "Storage": 7}   # with DEFAULTS


def track_max(p):
    """Levels per track: level 1 plus one per cost (so a --set cost table changes it)."""
    return {k: len(p["cost"][k]) + 1 for k in TRACK_MAX}


def throw_every(p, rebirths):
    """Seconds per throw while filling: the 0.8 s cooldown plus aiming, less any rebirth cut."""
    cut = min(p["rebirth_cooldown"] * rebirths, p["cooldown"] - p["cooldown_min"])
    return p["throw_every"] - max(0.0, cut)
 
 
def rarity_probs(weights, luck):
    """Luck multiplies every rarity above the table's lowest one (spec 4.2)."""
    w = np.array(weights, float)
    lowest = int(np.flatnonzero(w)[0])
    w[lowest + 1:] *= luck
    return w / w.sum()
 
 
def variant_chances(p, golden_bait):
    """(Golden, Rainbow) chances averaged over Golden Hour and normal time, with caps."""
    g, r = p["golden"], p["rainbow"]
    if golden_bait:
        g, r = g * 5, r * 5
    gh = p["golden_hour"]
    normal = (min(g, 0.25), min(r, 0.02))
    golden_hour = (min(g * 5, 0.25), min(r * 3, 0.02))
    return tuple((1 - gh) * a + gh * b for a, b in zip(normal, golden_hour))
 
 
def conga(p, n):
    m = 1.0
    for length, mult in p["conga"]:
        if n >= length:
            m = mult
    return m
 
 
def rebirth_needs(p, r):
    """(LP, coins) needed for the next rebirth after r earlier ones (economy.md 5.7)."""
    lp_t, coin_t = p["rebirth_lp"], p["rebirth_coins"]
    if r < len(lp_t):
        return lp_t[r], coin_t[r]
    k = r - len(lp_t) + 1
    return lp_t[-1] * p["rebirth_growth_lp"] ** k, coin_t[-1] * p["rebirth_growth_coins"] ** k
 
 
def run_time(p, cap, dist, speed, rebirths=0):
    slow = max(0.6, 1 - 0.0015 * cap)
    deliver = cap / max(8, cap / 4)
    return (dist / speed + cap * throw_every(p, rebirths) + p["join_delay"]
            + dist / (speed * slow) + deliver + p["overhead"])
 
 
def simulate(p, rng, hours, coins_pass=False, leash_pass=False, favourites=3):
    """One player. Returns milestones (seconds of play) and one record per run."""
    coin_m = np.array([t[1] for t in p["tiers"]], float)
    lp_m = [t[2] for t in p["tiers"]]
    gates = [t[3] for t in p["tiers"]]
    value, lpv = np.array(p["value"], float), np.array(p["lp"], float)
    g_n, r_n = variant_chances(p, False)
    g_g, r_g = variant_chances(p, True)
    ev_cache = {}
 
    t = coins = lp = 0.0
    tier = rebirths = 0
    tmax = track_max(p)
    lv = {k: 1 for k in tmax}
    pen_base, pen_tier = np.empty(0), np.empty(0, int)
    index = [set() for _ in p["tiers"]]
    index_done = []
    golden_bait = 0.0
    ms, runs = {}, []
    first = True
 
    while t < hours * 3600:
        cap = p["leash"][lv["Leash"] - 1] + p["rebirth_leash"] * rebirths
        cap = int(min(cap * (p["leash_pass_x"] if leash_pass else 1), p["line_cap"]))
        speed = p["base_speed"] + lv["Speed"] - 1 + min(p["rebirth_speed"] * rebirths, p["rebirth_speed_max"])
        bait_luck = 1 + p["bait_step"] * (lv["Bait"] - 1) + p["rebirth_luck"] * rebirths
        if first:
            band, dist = 0, p["first_pen_to_gate"] + p["bands"][0][1]
        else:  # the band with the best expected coins per second
            best = None
            for b, (_, d, luck) in enumerate(p["bands"]):
                lam = min(p["luck_cap"], bait_luck * luck)
                if lam not in ev_cache:
                    ev_cache[lam] = float(rarity_probs(p["weights"], lam) @ value)
                rate = ev_cache[lam] / run_time(p, cap, p["pen_to_gate"] + d, speed, rebirths)
                if best is None or rate > best[0]:
                    best = (rate, b, p["pen_to_gate"] + d)
            _, band, dist = best
        lam = min(p["luck_cap"], bait_luck * p["bands"][band][2])
        T = run_time(p, cap, dist, speed, rebirths)
 
        n_gold = int(min(golden_bait, cap))
        n_norm = cap - n_gold
        r_norm = rng.choice(6, n_norm, p=rarity_probs(p["weights"], lam))
        if first and n_norm >= 6:
            r_norm[2], r_norm[5] = 1, 2            # tutorial: throw 3 Uncommon, throw 6 Rare
        r_gold = rng.choice(6, n_gold, p=rarity_probs(p["golden_table"], lam))
        u = rng.random(n_norm)
        x_norm = np.where(u < r_n, p["rainbow_x"], np.where(u < r_n + g_n, p["golden_x"], 1))
        u = rng.random(n_gold)
        x_gold = np.where(u < r_g, p["rainbow_x"], np.where(u < r_g + g_g, p["golden_x"], 1))
 
        if t > p["beginner_shield"] and cap >= 10 and rng.random() < p["cut_chance"]:
            lost = min(int(round(cap * rng.random() * p["cut_max_share"])), n_norm)
            r_norm, x_norm = r_norm[: n_norm - lost], x_norm[: n_norm - lost]  # bound critters stay
 
        r_all = np.concatenate([r_norm, r_gold])
        x_all = np.concatenate([x_norm, x_gold])
        n = len(r_all)
        mult = conga(p, n)
        coin_boost = ((1 + p["rebirth_bonus"] * rebirths)
                      * (1 + p["index_bonus"] * len(index_done))
                      * (2 if coins_pass else 1) * p["extra_coin"])
        lp_boost = 1 + p["rebirth_bonus"] * rebirths
 
        base = value[r_all] * x_all
        delivery = base.sum() * coin_m[tier] * mult * coin_boost
        lp_gain = lpv[r_all].sum() * lp_m[tier] * mult * lp_boost
        pen_now = pen_base * coin_m[np.minimum(pen_tier, tier)]      # biome cap
        pen_income = pen_now.sum() * p["pen_rate"] * T * coin_boost
 
        t += T
        coins += delivery + pen_income
        lp += lp_gain
        golden_bait += p["golden_bait_per_hour"] * T / 3600 - n_gold
        runs.append((t, pen_income, delivery, tier, rebirths, band, cap, T))
 
        # auto-place: the pen keeps its most valuable critters
        cand_base = np.concatenate([pen_base, base])
        cand_tier = np.concatenate([pen_tier, np.full(n, tier)])
        slots = 6 + 2 * (lv["Pen"] - 1) + p["rebirth_pen"] * rebirths
        keep = np.argsort(-(cand_base * coin_m[np.minimum(cand_tier, tier)]))[:slots]
        pen_base, pen_tier = cand_base[keep], cand_tier[keep]
 
        # Index: Normal-variant species per biome
        for r in r_all[x_all == 1]:
            index[tier].add((int(r), int(rng.integers(p["species"][r]))))
        if tier not in index_done and len(index[tier]) == sum(p["species"]):
            index_done.append(tier)
            ms.setdefault(f"index_{tier}", t)
 
        ms.setdefault("first_delivery", t)
        if (r_all >= 3).any():
            ms.setdefault("first_epic", t)
        if n >= 100:
            ms.setdefault("line_100", t)
            ms.setdefault(f"line_100_r{rebirths}", t)
        first = False
 
        while tier + 1 < len(gates) and lp >= gates[tier + 1]:
            tier += 1
            ms.setdefault(f"tier_{tier}_r{rebirths}", t)
            ms.setdefault(f"tier_{tier}_any", t)
 
        while True:  # upgrades: the cheapest affordable one first
            options = [(p["cost"][k][lv[k] - 1], k) for k in tmax if lv[k] < tmax[k]]
            options = [o for o in options if o[0] <= coins]
            if not options:
                break
            cost, k = min(options)
            coins -= cost
            lv[k] += 1
            ms.setdefault("first_upgrade", t)
            ms.setdefault(f"{k}_{lv[k]}_r{rebirths}", t)
        if all(lv[k] == tmax[k] for k in tmax):
            ms.setdefault(f"all_max_r{rebirths}", t)
 
        need_lp, need_coins = rebirth_needs(p, rebirths)
        if tier >= p["rebirth_tier"] and lp >= need_lp and coins >= need_coins:
            ms[f"income_min_{rebirths + 1}"] = (delivery + pen_income) / T * 60
            ms[f"coins_at_rebirth_{rebirths + 1}"] = coins
            full = pen_base * coin_m[pen_tier]
            keep = np.argsort(-full)[:favourites]          # favourites survive
            pen_base, pen_tier = pen_base[keep], pen_tier[keep]
            coins = lp = 0.0
            tier = 0
            lv = {k: 1 for k in tmax}
            rebirths += 1
            ms[f"rebirth_{rebirths}"] = t
 
    return ms, runs
 
 
def pen_share(runs, start, end):
    pen = sum(r[1] for r in runs if start <= r[0] < end)
    dlv = sum(r[2] for r in runs if start <= r[0] < end)
    return pen / (pen + dlv) if pen + dlv else None
 
 
def income_per_min(runs, start, end):
    inc = sum(r[1] + r[2] for r in runs if start <= r[0] < end)
    return inc / ((end - start) / 60)
 
 
MILESTONES = [
    ("first_delivery", "First delivery"), ("first_upgrade", "First upgrade"),
    ("first_epic", "First Epic"), ("tier_1_r0", "Jungle unlocked"),
    ("line_100", "First 100-critter line"), ("tier_2_r0", "Snowy Peaks unlocked"),
    ("all_max_r0", "All upgrades maxed"), ("rebirth_1", "Rebirth 1"),
    ("tier_2_r1", "Snowy Peaks again"), ("rebirth_2", "Rebirth 2"), ("rebirth_3", "Rebirth 3"),
    ("index_2", "Index: Snowy Peaks Normal set"), ("index_1", "Index: Jungle Normal set"),
    ("index_0", "Index: Meadow Normal set"),
]
WINDOWS = [(0, 900), (900, 1800), (1800, 3600), (3600, 7200), (7200, 14400), (14400, 36000)]
 
 
def report(p, players, hours, seed, label, detail=False, **kw):
    rng = np.random.default_rng(seed)
    results = [simulate(p, rng, hours, **kw) for _ in range(players)]
    print(f"\n=== {label}: {players} players, {hours:g} h of play each, seed {seed}")
    print(f"{'milestone':32s} {'p10':>8s} {'p50':>8s} {'p90':>8s}   reached   (minutes of play)")
    extra = [(f"tier_{i}_any", f"{t[0]} first unlocked") for i, t in enumerate(p["tiers"]) if i > 2]
    for key, name in MILESTONES + extra:
        vals = [ms[key] / 60 for ms, _ in results if key in ms]
        if vals:
            q = np.percentile(vals, [10, 50, 90])
            print(f"{name:32s} {q[0]:8.1f} {q[1]:8.1f} {q[2]:8.1f}   {len(vals) / players:6.0%}")
        else:
            print(f"{name:32s} {'not reached':>26s}")
    shares, incomes = [], []
    for a, b in WINDOWS:
        s = [x for x in (pen_share(r, a, b) for _, r in results) if x is not None]
        shares.append(f"{a // 60}-{b // 60} min {np.median(s):.0%}")
        incomes.append(f"{a // 60}-{b // 60} min {np.median([income_per_min(r, a, b) for _, r in results]):.3g}")
    print("pen share of income (median): " + ", ".join(shares))
    print("coins per minute (median):    " + ", ".join(incomes))
    if detail:
        print("upgrade timeline, first cycle (median minute each level is bought):")
        for k, top in track_max(p).items():
            cells = []
            for lvl in range(2, top + 1):
                v = [ms[f"{k}_{lvl}_r0"] / 60 for ms, _ in results if f"{k}_{lvl}_r0" in ms]
                cells.append(f"L{lvl} {np.median(v):.0f}" if v else f"L{lvl} -")
            print(f"  {k:8s} " + ", ".join(cells))
        counts = {}
        for _, runs in results:
            for r in runs:
                counts.setdefault(r[3], np.zeros(len(p["bands"])))[r[5]] += 1
        print("band choice by biome (share of runs): " + "; ".join(
            f"{p['tiers'][tr][0]}: " + ", ".join(f"{p['bands'][b][0]} {c / cs.sum():.0%}" for b, c in enumerate(cs))
            for tr, cs in sorted(counts.items())))
        for k in (1, 2, 3):
            v = [ms[f"coins_at_rebirth_{k}"] for ms, _ in results if f"coins_at_rebirth_{k}" in ms]
            inc = [ms[f"income_min_{k}"] for ms, _ in results if f"income_min_{k}" in ms]
            if v:
                print(f"rebirth {k}: median coins held {np.median(v):.3g} (needs {rebirth_needs(p, k - 1)[1]:.3g}); "
                      f"income just before {np.median(inc):.3g} coins/min")
    return results
 
 
def favourites_test(p, players, seed):
    """Re-climb and pen share just after rebirth 1, with 0, 3 and 8 favourites."""
    print(f"\n=== Favourites after rebirth 1: {players} players, seed {seed}")
    for fav in (0, 3, 8):
        rng = np.random.default_rng(seed)
        res = [simulate(p, rng, 9, favourites=fav) for _ in range(players)]
        climb, share10, r2 = [], [], []
        for ms, runs in res:
            if "rebirth_1" not in ms or "tier_2_r1" not in ms:
                continue
            r1 = ms["rebirth_1"]
            climb.append((ms["tier_2_r1"] - r1) / 60)
            early = [r for r in runs if r[4] == 1 and r1 < r[0] <= r1 + 600]
            pen, dlv = sum(r[1] for r in early), sum(r[2] for r in early)
            if pen + dlv:
                share10.append(pen / (pen + dlv))
            if "rebirth_2" in ms:
                r2.append(ms["rebirth_2"] / 60)
        print(f"{fav} favourites: back to Snowy Peaks {np.median(climb):.1f} min after rebirth 1; "
              f"pen share in the first 10 min after it {np.median(share10):.0%}; "
              f"rebirth 2 at {np.median(r2):.0f} min ({len(r2)}/{players} reached it in 9 h)")
 
 
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--players", type=int, default=400)
    ap.add_argument("--hours", type=float, default=22)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--set", action="append", default=[], metavar="KEY=JSON",
                    help="override a DEFAULTS entry with a JSON value; repeatable")
    ap.add_argument("--free-only", action="store_true", help="only the free-player scenario")
    ap.add_argument("--favourites", action="store_true", help="also run the favourites test")
    args = ap.parse_args()
    p = copy.deepcopy(DEFAULTS)
    for item in args.set:
        key, _, raw = item.partition("=")
        if key not in p:
            ap.error(f"unknown key {key!r}")
        p[key] = json.loads(raw)
    common = (p, args.players, args.hours, args.seed)
    report(*common, "Free player (3 favourites)", detail=True)
    if not args.free_only:
        report(*common, "2x Coins only", coins_pass=True)
        report(*common, "Longer Leash only", leash_pass=True)
        report(*common, "All passes (2x Coins, Longer Leash, 8 favourites)",
               coins_pass=True, leash_pass=True, favourites=8)
    if args.favourites:
        favourites_test(p, min(args.players, 300), args.seed)
 
 
if __name__ == "__main__":
    main()
 