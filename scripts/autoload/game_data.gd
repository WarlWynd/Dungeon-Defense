extends Node

## All balance numbers in one place. Later these become .tres Resources.

var heroes: Dictionary = {}
var traps: Dictionary = {}
var minions: Dictionary = {}

const STARTING_HOARD := 1000
const BUILD_SECONDS := 12.0

## Boards are DATA. smoothing: 0 = straight/angular, ~0.4 = flowing. type "maze"
## uses junctions+edges instead of points.
const BOARDS: Array = [
	{
		"name": "The River",
		"smoothing": 0.42,
		"points": [
			Vector2(370, -50), Vector2(400, 110), Vector2(300, 220),
			Vector2(160, 300), Vector2(130, 430), Vector2(250, 510),
			Vector2(430, 545), Vector2(570, 630), Vector2(560, 770),
			Vector2(400, 830), Vector2(230, 880), Vector2(160, 1000),
			Vector2(250, 1090), Vector2(360, 1120),
		],
	},
	{
		"name": "The Fortress",
		"smoothing": 0.0,
		"points": [
			Vector2(360, -50), Vector2(360, 180), Vector2(620, 180),
			Vector2(620, 400), Vector2(120, 400), Vector2(120, 620),
			Vector2(620, 620), Vector2(620, 840), Vector2(120, 840),
			Vector2(120, 1040), Vector2(360, 1040), Vector2(360, 1120),
		],
	},
	{
		"name": "The Warren",
		"type": "maze",
		"junctions": [
			Vector2(300, 120), Vector2(300, 300), Vector2(140, 300),
			Vector2(460, 300), Vector2(140, 480), Vector2(460, 480),
			Vector2(600, 480), Vector2(300, 480), Vector2(300, 660),
			Vector2(140, 660), Vector2(460, 660), Vector2(460, 840),
			Vector2(300, 840), Vector2(300, 1010), Vector2(460, 1010),
			Vector2(300, 1120),
		],
		"edges": [
			[0, 1], [1, 2], [1, 3], [2, 4], [3, 5], [5, 6], [5, 7],
			[7, 1], [7, 8], [8, 9], [8, 10], [10, 11], [11, 12],
			[12, 13], [13, 14], [13, 15],
		],
		"entrance": 0,
		"vault": 15,
	},
]

var active_board: int = 0


func board() -> Dictionary:
	return BOARDS[active_board % BOARDS.size()]


func is_maze() -> bool:
	return board().get("type", "path") == "maze"


func path_points() -> Array:
	return board()["points"]


func path_smoothing() -> float:
	return board().get("smoothing", 0.0)


func vault_pos() -> Vector2:
	var b := board()
	if is_maze():
		return b["junctions"][b["vault"]]
	var pts: Array = b["points"]
	return pts[pts.size() - 1]


func entrance_pos() -> Vector2:
	var b := board()
	if is_maze():
		return b["junctions"][b["entrance"]]
	var pts: Array = b["points"]
	return pts[1] if pts.size() > 1 else pts[0]


func next_board() -> void:
	active_board = (active_board + 1) % BOARDS.size()


const WAVES: Array = [
	{"squire": 6},
	{"squire": 5, "treasure_hunter": 1},
	{"squire": 6, "knight": 1, "acolyte": 1, "treasure_hunter": 1},
	{"squire": 6, "knight": 1, "priestess": 1, "treasure_hunter": 3},
	{"squire": 8, "knight": 2, "high_priestess": 1, "paladin": 1,
		"treasure_hunter": 3},
]


func _ready() -> void:
	_build_heroes()
	_build_traps()
	_build_minions()


func _hero(id: String, dname: String, hp: float, spd: float, flee: float, greed: int,
		bounty: int, dmg: float, arate: float, arange: float, armor: float,
		mdef: float, purity: float, col: Color, radius: float, desc: String) -> HeroData:
	var h := HeroData.new()
	h.id = id
	h.display_name = dname
	h.max_hp = hp
	h.speed = spd
	h.flee_speed_mult = flee
	h.greed = greed
	h.bounty = bounty
	h.damage = dmg
	h.attack_rate = arate
	h.attack_range = arange
	h.armor = armor
	h.magic_defense = mdef
	h.purity = purity
	h.color = col
	h.radius = radius
	h.description = desc
	heroes[id] = h
	return h


func _build_heroes() -> void:
	_hero("squire", "Squire", 42.0, 88.0, 1.15, 25, 7, 6.0, 0.9, 30.0, 0.10, 0.0, 0.2,
		Color(0.79, 0.72, 0.55), 11.0,
		"Cannon fodder. Weak, fast, never alone. A dozen squires is still 300 gold out the door.")

	_hero("treasure_hunter", "Treasure Hunter", 30.0, 135.0, 1.6, 160, 14, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0,
		Color(0.95, 0.55, 0.15), 10.0,
		"A professional. Ignores your minions, grabs a fortune, sprints for the exit. It'll be BEHIND your traps. Cover the way OUT.")

	_hero("knight", "Knight", 130.0, 58.0, 1.0, 90, 30, 14.0, 1.1, 32.0, 0.75, 0.0, 0.50,
		Color(0.62, 0.66, 0.74), 13.0,
		"A wall of steel. 75% armour — physical clatters off. 0% magic def — poison is the answer. 50% purity — the Succubus is a coin flip. Slow. Use that.")

	_hero("priestess", "Priestess", 45.0, 78.0, 1.3, 30, 18, 0.0, 1.0, 0.0, 0.0, 0.15, 0.30,
		Color(0.72, 0.95, 0.82), 11.0,
		"Mends 14 HP every 2.5s (5.6/sec). Your crossbow does 5.9 to a Knight — while she lives he is effectively immortal. She doesn't out-fight you, she makes your dungeon pointless. 45 HP, easily charmed. REACH HER.").heal_amount = 14.0

	_hero("acolyte", "Acolyte", 35.0, 84.0, 1.3, 20, 10, 0.0, 1.0, 0.0, 0.0, 0.0, 0.15,
		Color(0.80, 0.95, 0.86), 10.0,
		"A novice healer, 8 HP every 3s — barely enough to matter. The warning shot: learn to kill the healer now, while it's cheap.").heal_amount = 8.0

	_hero("high_priestess", "High Priestess", 70.0, 70.0, 1.25, 45, 35, 0.0, 1.0, 0.0, 0.10, 0.30, 0.55,
		Color(0.55, 0.98, 0.75), 12.0,
		"22 HP every 2.2s — 10 healing/sec across a huge reach. No physical out-damages that through armour. Poison barely works. Every answer is worse against her. Still only 70 HP.").heal_amount = 22.0

	var paladin := _hero("paladin", "Paladin", 170.0, 50.0, 1.0, 0, 55, 8.0, 1.4, 32.0, 0.50, 0.60, 1.00,
		Color(0.98, 0.92, 0.62), 14.0,
		"Not a bigger Knight — the SHIELD. Hits soft, wears less armour. 100% purity, and BLESSES its escort to 85%: while it lives your Succubus is useless. 60% magic def, so poison is the wrong key. Takes no gold. Kill it FIRST.")

	# Healer tuning (heal_amount set inline above via .heal_amount).
	heroes["priestess"].heal_rate = 2.5
	heroes["priestess"].heal_range = 165.0
	heroes["acolyte"].heal_rate = 3.0
	heroes["acolyte"].heal_range = 130.0
	heroes["high_priestess"].heal_rate = 2.2
	heroes["high_priestess"].heal_range = 200.0
	heroes["high_priestess"].heal_amount = 22.0

	paladin.purity_aura = 0.85
	paladin.purity_aura_range = 150.0


func _trap(id: String, tname: String, kind: TrapData.Kind, cost: int, dmg: float, dtype: String,
		arange: float, frate: float, col: Color, flavor: String) -> TrapData:
	var t := TrapData.new()
	t.id = id
	t.display_name = tname
	t.kind = kind
	t.cost = cost
	t.damage = dmg
	t.damage_type = dtype
	t.attack_range = arange
	t.fire_rate = frate
	t.color = col
	t.flavor = flavor
	traps[id] = t
	return t


func _build_traps() -> void:
	_trap("spike_pit", "Spike Pit", TrapData.Kind.AREA_DAMAGE, 60, 7.0, "physical",
		46.0, 0.45, Color(0.62, 0.62, 0.68), "Simple. Honest. Pointy.")
	_trap("crossbow", "Crossbow Turret", TrapData.Kind.TURRET, 110, 13.0, "physical",
		160.0, 0.55, Color(0.55, 0.35, 0.22), "Points at whoever is nearest.")
	var frost := _trap("frost_totem", "Frost Totem", TrapData.Kind.SLOW_AURA, 85, 0.0, "physical",
		130.0, 1.0, Color(0.45, 0.78, 0.95), "Does no damage. Wins the level.")
	frost.slow_amount = 0.45
	_trap("poison_fungus", "Poison Fungus", TrapData.Kind.AREA_DAMAGE, 90, 5.0, "magic",
		52.0, 0.35, Color(0.45, 0.75, 0.35), "Armour is no help against a smell.")
	var brazier := _trap("cursed_brazier", "Cursed Brazier", TrapData.Kind.WEAKEN_AURA, 120, 0.0, "physical",
		140.0, 1.0, Color(0.55, 0.15, 0.35), "Let them mend it. It won't hold.")
	brazier.weaken_damage_bonus = 0.30
	brazier.weaken_heal_cut = 0.60


func _build_minions() -> void:
	var goblins := MinionData.new()
	goblins.id = "goblin_pack"
	goblins.display_name = "Goblin Pack"
	goblins.unit_name = "Goblin"
	goblins.max_hp = 40.0
	goblins.speed = 105.0
	goblins.damage = 7.0
	goblins.attack_rate = 0.7
	goblins.attack_range = 26.0
	goblins.count = 3
	goblins.pursue_thieves_first = true
	goblins.acquire_mode = "earn"       ## EARNED by surviving your first wave
	goblins.unlock_wave = 1
	goblins.color = Color(0.45, 0.72, 0.35)
	goblins.radius = 10.0
	goblins.description = "Three separate goblins, 40 HP each. They chase whoever carries your gold. A Knight cuts one down in 3s. Earned by clearing wave 1 — loyal for good once earned."
	minions["goblin_pack"] = goblins

	var succubus := MinionData.new()
	succubus.id = "succubus"
	succubus.display_name = "Succubus"
	succubus.unit_name = "Succubus"
	succubus.max_hp = 55.0
	succubus.speed = 95.0
	succubus.damage = 4.0
	succubus.attack_rate = 1.2
	succubus.attack_range = 24.0
	succubus.count = 1
	succubus.allure_arrive = 0.75
	succubus.allure_desert = 0.65
	succubus.pursue_thieves_first = true
	succubus.acquire_mode = "auto"      ## the ONLY automatic one — drawn by a rich hoard
	succubus.can_charm = true
	succubus.charm_range = 170.0
	succubus.charm_cooldown = 6.0
	succubus.charm_duration = 5.0
	succubus.charm_power = 0.5
	succubus.color = Color(0.85, 0.25, 0.55)
	succubus.radius = 11.0
	succubus.description = "Drawn only by a rich hoard. She CHARMS a thief into carrying your gold back for you. Beaten only by purity. Fragile. Protect her."
	minions["succubus"] = succubus

	## BOUGHT with souls (or gems). A vengeful shade — fast, hard-hitting, and it
	## hunts whoever holds your gold. Unlock is permanent once recruited.
	var wraith := MinionData.new()
	wraith.id = "wraith"
	wraith.display_name = "Wraith"
	wraith.unit_name = "Wraith"
	wraith.max_hp = 90.0
	wraith.speed = 120.0
	wraith.damage = 16.0
	wraith.attack_rate = 0.9
	wraith.attack_range = 28.0
	wraith.count = 1
	wraith.pursue_thieves_first = true
	wraith.acquire_mode = "buy"
	wraith.recruit_souls = 25
	wraith.recruit_gems = 30
	wraith.color = Color(0.55, 0.35, 0.75)
	wraith.radius = 12.0
	wraith.description = "A vengeful shade bought with souls. Hits hard, moves fast, and hunts whoever carries your gold. Yours for good once recruited."
	minions["wraith"] = wraith


func wave_count() -> int:
	return WAVES.size()
