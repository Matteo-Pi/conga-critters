--!strict
-- Shared types: the service/controller lifecycle, every Config module's shape, and saved data (spec 9.6).
-- Ids that content can add to (biomes, critters, events, products) are plain strings, so new content needs only data.

-- Lifecycle -------------------------------------------------------------------

export type Lifecycle = {
	Init: () -> (),
	Start: () -> (),
}

-- Config: content ----------------------------------------------------------------

export type SizeClass = "S" | "M" | "L"

export type RarityDef = {
	Id: string,
	Rank: number, -- 1 Common … 6 Mythic; filters such as auto-release `UpTo` compare ranks
	Weight: number, -- Normal bait table
	GoldenBaitWeight: number?, -- Golden Bait table; nil = not in it
	Value: number, -- coins, before biome, variant and Conga multipliers
	LP: number,
	Color: Color3, -- always paired with an icon or label in UI
}

export type RaritiesConfig = {
	List: { RarityDef }, -- ordered by Rank
	ById: { [string]: RarityDef },
	LuckCap: number,
}

export type VariantDef = {
	Id: string,
	Wire: number, -- 0 Normal, 1 Golden, 2 Rainbow (spec 9.4 packing)
	Chance: number, -- 0 for Normal: it takes the rest
	ValueMultiplier: number,
	GoldenBaitMultiplier: number,
	GoldenHourMultiplier: number,
	Cap: number,
}

export type VariantsConfig = {
	List: { VariantDef }, -- ordered by Wire
	ById: { [string]: VariantDef },
}

export type BiomeDef = {
	Id: string,
	Name: string,
	Tier: number?, -- nil when TierMatched
	TierMatched: boolean, -- event biomes: critters count as the owner's top tier
	GateLP: number,
	CoinMultiplier: number,
	LPMultiplier: number,
}

export type DepthBand = {
	Id: string,
	From: number, -- studs past the gate
	To: number,
	Luck: number,
}

export type BiomesConfig = {
	List: { BiomeDef },
	ById: { [string]: BiomeDef },
	DepthBands: { DepthBand },
}

export type CritterDef = {
	Id: string,
	Name: string,
	Biome: string,
	Rarity: string,
	Size: SizeClass,
	Retired: boolean?,
}

export type CrittersConfig = {
	List: { CritterDef }, -- append-only: list position is the wire index (spec 5.4, 9.4)
	ById: { [string]: CritterDef },
	IndexById: { [string]: number },
}

-- Config: line, throwing, delivery ------------------------------------------------

export type CongaStep = {
	MinLength: number,
	Multiplier: number,
}

export type LineConfig = {
	Conga: { CongaStep }, -- ascending MinLength
	MaxCapacity: number,
	RebirthLeashBonus: number,
	LongerLeashMultiplier: number,
	BaseWalkSpeed: number,
	SlowPerCritter: number,
	MinSpeedFactor: number,
	Spacing: { [SizeClass]: number },
	Path: LinePathConfig,
	Render: LineRenderConfig,
	Banners: { number }, -- own line lengths that fire a banner (spec 4.3, 7.4)
}

export type LinePathConfig = {
	MinStep: number, -- studs the leader moves before a new breadcrumb
	KeepPerCapacity: number, -- keep capacity × this + KeepExtra studs of path
	KeepExtra: number,
	ResetJump: number, -- a jump longer than this between samples resets the path
	ServerSampleHz: number,
	AirborneGap: number, -- studs: feet higher than this above the floor below = airborne
	FloorProbe: number, -- studs below the feet to look for a floor
	HopMinGap: number, -- studs: a take-off this close to the last hop marker adds none
	LagCatchUp: number, -- studs a second: how fast followers catch up path length added by height
	LagMax: number, -- studs: most such length caught up gradually
}

export type LineRenderConfig = {
	HopHeight: number, -- studs
	HopSpeed: number, -- ω, radians per second
	HopPhase: number, -- φ, radians between neighbours
	IdleHop: number, -- share of the hop kept while the leader stands still
	WaddleDegrees: number,
	Smoothing: number, -- per second: how fast a sudden jump in a follower's target is taken out
	SnapDistance: number, -- a jump longer than this snaps instead of gliding
	FullDetailDistance: number, -- studs: hop, waddle, particles and colour cycling within this
	FarUpdateEvery: number, -- beyond FullDetailDistance, followers move every this many frames
	HideDistance: number,
	HideDistancePhone: number,
	MaxDrawn: number,
	MaxDrawnPhone: number,
	ClaimSeconds: number, -- a critter that has eaten waits this long (plus ping) for its line to claim it
	JoinHopHeight: number, -- studs: the arc of a joining critter's hop from its bait into the line
	JumpHopAtSpot: boolean, -- followers also hop as they pass a hop marker (the leader's take-off point)
	JumpHopHeight: number, -- studs: a follower's hop as it passes a hop marker
	JumpHopSeconds: number,
	JumpWave: boolean, -- every jump sends a hop wave down the line
	JumpWaveHeight: number,
	JumpWaveDelay: number, -- seconds between neighbours in the wave
	JumpWaveMax: number, -- most waves running down one line at once; a new one past this drops the oldest
}

export type ThrowConfig = {
	Range: number,
	Cooldown: number,
	CrittersPerThrow: number,
	RateLimitSlack: number,
	RateLimitBurst: number,
	TargetRangeSlack: number,
	JoinDelay: number,
	RunInSeconds: number,
	EatSeconds: number,
	HopSeconds: number,
	BurrowSearchRadius: number,
	FallbackSpawnMin: number,
	FallbackSpawnMax: number,
	FlightSeconds: number,
	ArcHeight: number,
	RejectGraceSeconds: number,
	ZonePollHz: number,
}

export type DeliveryConfig = {
	MinRate: number,
	RateDivisor: number,
	BankOnLeave: {
		UseConga: boolean,
		GiveLP: boolean,
	},
}

export type CuttingConfig = {
	CutTierGap: number?, -- nil = off
	CheckHz: number,
	MinVictimLength: number,
	CapsuleRadius: number,
	MaxVerticalGap: number,
	MinCutterSpeed: number,
	MinFreeSlots: number,
	CutterCooldown: number,
	VictimCooldown: number,
	PairCooldown: number,
	CleanSeconds: number,
	FriendCuts: boolean,
	LooseSeconds: number,
	GrabRadius: number,
	BigStealAt: number,
	ServerToastAt: number,
}

-- Config: progression ----------------------------------------------------------------

export type UpgradeLevel = {
	Value: number, -- the track's effect at this level
	Cost: number, -- 0 for level 1
}

export type UpgradeTrack = {
	Id: string,
	Levels: { UpgradeLevel },
}

export type UpgradesConfig = {
	Order: { string },
	Tracks: { [string]: UpgradeTrack },
}

export type AutoReleaseSettings = {
	Enabled: boolean,
	UpTo: number, -- rarity rank
	IncludeGolden: boolean,
}

export type PenConfig = {
	BigStorageBonus: number,
	NeverReleaseMinRank: number, -- rarity rank; plus bound critters, always (hard rule, in code)
	NeverReleaseVariants: { string },
	OverflowLimit: number,
	AutoPlace: boolean,
	AutoRelease: AutoReleaseSettings,
	MaxReleaseUpTo: number,
	WarningFraction: number,
	FreeFavorites: number,
	MaxFavorites: number,
}

export type IncomeConfig = {
	PenRate: number,
	TwoXCoinsMultiplier: number,
	VIPMultiplier: number,
	FriendBoostPerFriend: number,
	FriendBoostMax: number,
}

export type RebirthNeed = {
	LP: number,
	Coins: number,
}

export type RebirthConfig = {
	Needs: { RebirthNeed },
	LPGrowth: number,
	CoinGrowth: number,
	CoinBonus: number,
	LPBonus: number,
	RequiredBiome: string,
}

export type IndexConfig = {
	NormalSetCoinBonus: number,
	NormalSetBadgeId: number,
	GoldenSetReward: string,
	RainbowSetReward: string,
	RainbowSetMaxRank: number,
}

export type DailyRewardKind = "Coins" | "GoldenBait" | "Shield"

export type DailyReward = {
	Kind: DailyRewardKind,
	Minutes: number?, -- Coins: minutes of best pen income
	Floor: number?, -- Coins: at least this many
	Amount: number?, -- GoldenBait
	Seconds: number?, -- Shield
	FirstTimeBadgeId: number?,
}

export type DailyConfig = {
	Ladder: { DailyReward },
	Stand: {
		Stock: number,
		FreeCount: number,
		PriceMinutes: number,
		PriceFloor: number,
		RestockHourUTC: number,
	},
}

export type ShieldsConfig = {
	BeginnerSeconds: number,
	BeginnerEndsAtBiome: string,
	DailySeconds: number,
	LineShieldSeconds: number,
	DailyStoredMax: number,
	ActivateSeconds: number,
	MaxActiveSeconds: number,
}

-- Config: events -------------------------------------------------------------------

export type EventEffects = {
	LuckMultiplier: number?,
	GoldenMultiplier: number?,
	RainbowMultiplier: number?,
	CrittersPerThrow: number?,
	CoinMultiplier: number?,
}

export type EventSchedule = {
	Kind: "Hourly" | "Admin",
	StartMinute: number?, -- Hourly: minute past each UTC hour
	DurationMinutes: number?, -- Hourly: length each hour; Admin: default length when the command gives none
}

export type EventDef = {
	Id: string,
	Name: string,
	Schedule: EventSchedule,
	Effects: EventEffects,
}

export type EventsConfig = {
	List: { EventDef },
	ById: { [string]: EventDef },
	EventLuckCap: number,
	AdminLuck: {
		MaxMultiplier: number,
		MaxMinutes: number,
	},
	Stampede: {
		MaxCount: number,
		MinRarity: string,
	},
	WeeklyAdmin: {
		WeekdayUTC: number, -- os.date("!*t").wday: 1 Sunday … 7 Saturday
		HourUTC: number,
	},
}

-- Config: monetisation ---------------------------------------------------------------

export type PassDef = {
	Key: string,
	Name: string,
	Id: number, -- 0 until created on the Creator Hub
	Price: number, -- display only; Roblox charges the real price
	Priority: string,
	FavoriteSlots: number?,
}

export type ProductDef = {
	Key: string,
	Name: string,
	Id: number,
	Price: number,
	Priority: string,
	PaidRandom: boolean, -- spec 6.4: odds panel + PolicyService gating
	GoldenBait: number?,
	ShieldSeconds: number?,
	LuckMultiplier: number?,
	LuckMinutes: number?,
}

export type MonetisationConfig = {
	Passes: { [string]: PassDef },
	Products: { [string]: ProductDef },
	ServerLuck: {
		MaxQueueMinutes: number,
		BuyableBelowMinutes: number,
	},
}

-- Config: other ------------------------------------------------------------------------

export type FixedRoll = {
	Throw: number,
	Rarity: string,
}

export type TutorialConfig = {
	FixedRolls: { FixedRoll },
	ManagePenIntroMinPlaySeconds: number,
}

export type AdminConfig = {
	Whitelist: { number },
}

export type DebugConfig = {
	LogBoot: boolean,
	LogThrows: boolean,
	ChatCommand: string,
	ChatCommandShort: string,
	StudioBridgeName: string,
	RollMaxSamples: number,
	MaxLeaders: number,
	LeadersFolderName: string,
	LeaderNamePrefix: string,
	LeaderIdBase: number,
	RendererBridgeName: string,
}

export type CameraConfig = {
	CameraMaxZoomDistance: number,
}

-- Saved data (spec 9.6) ------------------------------------------------------------

export type Critter = {
	u: number, -- uid, unique per player
	id: string, -- species id
	v: number, -- variant: 0 Normal, 1 Golden, 2 Rainbow
	b: boolean?, -- bound (from Golden Bait)
	p: boolean?, -- paid (Golden Bait or Server Luck)
	pin: boolean?, -- pinned (pen only)
	fav: boolean?, -- favourite
}

export type SaveData = {
	Version: number,
	Coins: number,
	LP: number,
	Rebirths: number,
	Upgrades: { Leash: number, Bait: number, Pen: number, Speed: number, Storage: number },
	Pen: { [string]: Critter }, -- slot number ("1" to "30") -> critter; empty slots are absent
	Storage: { Critter },
	NextUid: number,
	Index: { [string]: number }, -- species id -> bitmask: 1 Normal, 2 Golden, 4 Rainbow
	IndexRewards: { [string]: number }, -- biome id -> bitmask of rewards granted
	Inventory: { GoldenBait: number, ShieldSeconds: number },
	Daily: { LastClaimDay: number, LadderDay: number, Streak: number, StandDay: number, StandTaken: number },
	Tutorial: { Done: boolean, Step: number, ReleaseCueShown: boolean, PenIntroShown: boolean },
	BeginnerShieldUsed: number,
	Stats: {
		Delivered: number,
		BestLine: number,
		BiggestSteal: number,
		Cuts: number,
		TimesCut: number,
		PlaySeconds: number,
		FirstJoin: number,
		LastJoin: number,
	},
	Purchases: { Processed: { string }, RobuxSpent: number },
	Settings: {
		Music: boolean,
		Sfx: boolean,
		LowDetail: boolean,
		AutoPlace: boolean,
		AutoRelease: AutoReleaseSettings,
	},
}

return {}
