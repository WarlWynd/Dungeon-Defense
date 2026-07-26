extends Node

## All balance numbers in one place. Later these become .tres Resources.

var heroes: Dictionary = {}
var traps: Dictionary = {}
var minions: Dictionary = {}

const STARTING_HOARD := 1000
## How much the vault can hold. You start with a tenth of it — the empty nine
## tenths are the room plunder has to grow into, and the reason the bar is worth
## watching climb.
const HOARD_CAPACITY := 10000
const BUILD_SECONDS := 12.0

## Boards are DATA. smoothing: 0 = straight/angular, ~0.4 = flowing. type "maze"
## uses junctions+edges instead of points. The first six are hand-authored; boards
## 7-20 are appended by _build_generated_boards() at startup (a `var`, not `const`,
## so it can grow — and const Arrays are read-only in Godot 4 anyway).
var BOARDS: Array = [
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
	## Grid-aligned mazes, same schema as The Warren: every edge is horizontal or
	## vertical (right angles), the main corridor runs entrance (top) -> vault
	## (bottom), and degree-1 junctions are the dead-end side-hallways a hero can
	## wander into. Main path is called out per board so the branches are clear.
	{
		"name": "The Catacombs",
		"type": "maze",
		"junctions": [
			Vector2(300, 130), Vector2(300, 300), Vector2(130, 300),
			Vector2(470, 300), Vector2(470, 470), Vector2(600, 470),
			Vector2(300, 470), Vector2(300, 640), Vector2(130, 640),
			Vector2(470, 640), Vector2(470, 810), Vector2(300, 810),
			Vector2(300, 980), Vector2(470, 980), Vector2(300, 1130),
		],
		## Main: 0-1-3-4-6-7-9-10-11-12-14.  Dead ends: 2, 5, 8, 13.
		"edges": [
			[0, 1], [1, 2], [1, 3], [3, 4], [4, 5], [4, 6], [6, 7],
			[7, 8], [7, 9], [9, 10], [10, 11], [11, 12], [12, 13], [12, 14],
		],
		"entrance": 0,
		"vault": 14,
	},
	{
		"name": "The Oubliette",
		"type": "maze",
		"junctions": [
			Vector2(300, 140), Vector2(300, 300), Vector2(440, 300),
			Vector2(440, 460), Vector2(580, 460), Vector2(300, 460),
			Vector2(160, 460), Vector2(300, 620), Vector2(440, 620),
			Vector2(440, 780), Vector2(580, 780), Vector2(300, 780),
			Vector2(160, 780), Vector2(300, 940), Vector2(440, 940),
			Vector2(300, 1120),
		],
		## Main: 0-1-2-3-5-7-8-9-11-13-15.  Dead ends: 4, 6, 10, 12, 14.
		"edges": [
			[0, 1], [1, 2], [2, 3], [3, 4], [3, 5], [5, 6], [5, 7],
			[7, 8], [8, 9], [9, 10], [9, 11], [11, 12], [11, 13],
			[13, 14], [13, 15],
		],
		"entrance": 0,
		"vault": 15,
	},
	{
		"name": "The Undercroft",
		"type": "maze",
		"junctions": [
			Vector2(290, 130), Vector2(290, 290), Vector2(140, 290),
			Vector2(440, 290), Vector2(440, 450), Vector2(590, 450),
			Vector2(290, 450), Vector2(290, 610), Vector2(440, 610),
			Vector2(440, 770), Vector2(290, 770), Vector2(140, 770),
			Vector2(140, 930), Vector2(290, 930), Vector2(440, 930),
			Vector2(290, 1120),
		],
		## Main: 0-1-3-4-6-7-10-13-15.  Dead ends: 2, 5, 14, plus two L-shaped
		## hallways with a corner: 8->9 and 11->12.
		"edges": [
			[0, 1], [1, 2], [1, 3], [3, 4], [4, 5], [4, 6], [6, 7],
			[7, 8], [8, 9], [7, 10], [10, 11], [11, 12], [10, 13],
			[13, 14], [13, 15],
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
	## The very first path point — the true start of the path (enemies spawn here
	## and walk in). It may sit just above the stone on boards that enter from off
	## the top edge; that's where the path itself begins.
	return b["points"][0]


## Steps the board by `delta`, wrapping at both ends. posmod keeps -1 from
## landing on a negative index.
func step_board(delta: int) -> void:
	active_board = posmod(active_board + delta, BOARDS.size())


func board_count() -> int:
	return BOARDS.size()


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
	_build_generated_boards()


## --- Procedural boards (7-20) ---------------------------------------------
##
## Deterministic grid mazes in the same shape as the hand-authored ones: every
## edge is horizontal or vertical (right angles), a main corridor snakes from a
## top entrance to a bottom vault, and random dead-end hallways branch off it.
## Each board is seeded by its index, so a given board's layout is FIXED across
## runs — the player can still learn board 14 the way they learn The Warren.

const GEN_COLS: Array = [130.0, 290.0, 450.0, 600.0]
const GEN_ROWS: Array = [130.0, 290.0, 450.0, 610.0, 770.0, 930.0, 1120.0]
const GEN_NAMES: Array = [
	"The Sunless Coil", "The Gnawed Halls", "The Ossuary", "The Black Sump",
	"The Wormways", "The Hollow March", "The Rusted Vaults", "The Gibbet Maze",
	"The Drowned Tiers", "The Ashen Burrows", "The Splintered Deep",
	"The Cinder Warren", "The Lightless Knot", "The Final Descent",
]


func _build_generated_boards() -> void:
	for i in GEN_NAMES.size():
		## +1 on the seed keeps board 7 from ever generating an empty-looking layout
		## at seed 0; the exact value only has to be stable, not meaningful.
		BOARDS.append(_generate_maze_board(GEN_NAMES[i], 1481 + i * 97))


func _generate_maze_board(nm: String, seed_val: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var n_cols: int = GEN_COLS.size()
	var n_rows: int = GEN_ROWS.size()

	var cells := {}          ## Vector2i(col,row) -> junction index
	var junctions: Array = []
	var edges: Array = []
	var edge_set := {}
	var main_cells: Array = []   ## grid cells on the main corridor, for branching

	## Main corridor: start near the middle of the top row, then descend row by
	## row, sometimes jogging one column sideways first so it snakes.
	var c: int = rng.randi_range(1, n_cols - 2)
	var entrance_idx: int = _gen_node(cells, junctions, c, 0)
	main_cells.append(Vector2i(c, 0))
	var prev: int = entrance_idx
	for r in range(1, n_rows):
		if rng.randf() < 0.6:
			var dir: int = 1 if rng.randf() < 0.5 else -1
			var nc: int = clampi(c + dir, 0, n_cols - 1)
			if nc != c:
				var jog: int = _gen_node(cells, junctions, nc, r - 1)
				_gen_edge(edges, edge_set, prev, jog)
				main_cells.append(Vector2i(nc, r - 1))
				prev = jog
				c = nc
		var down: int = _gen_node(cells, junctions, c, r)
		_gen_edge(edges, edge_set, prev, down)
		main_cells.append(Vector2i(c, r))
		prev = down
	var vault_idx: int = prev

	## Dead-end hallways: hang a short spur (sometimes an L of two segments) off a
	## random corridor junction into a free, in-bounds neighbouring cell.
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var branches: int = rng.randi_range(5, 8)
	for _b in range(branches):
		var base: Vector2i = main_cells[rng.randi_range(0, main_cells.size() - 1)]
		_gen_shuffle(dirs, rng)
		for d in dirs:
			var tc: int = base.x + d.x
			var tr: int = base.y + d.y
			if tc < 0 or tc >= n_cols or tr < 0 or tr >= n_rows:
				continue
			if cells.has(Vector2i(tc, tr)):
				continue
			var from_idx: int = cells[base]
			var spur: int = _gen_node(cells, junctions, tc, tr)
			_gen_edge(edges, edge_set, from_idx, spur)
			## 40% of the time, bend one more step (perpendicular) into a free cell
			## so some hallways turn a corner instead of stopping dead.
			if rng.randf() < 0.4:
				_gen_shuffle(dirs, rng)
				for d2 in dirs:
					if d2 == d or d2 == -d:
						continue
					var ec: int = tc + d2.x
					var er: int = tr + d2.y
					if ec < 0 or ec >= n_cols or er < 0 or er >= n_rows:
						continue
					if cells.has(Vector2i(ec, er)):
						continue
					var elbow: int = _gen_node(cells, junctions, ec, er)
					_gen_edge(edges, edge_set, spur, elbow)
					break
			break

	return {
		"name": nm,
		"type": "maze",
		"junctions": junctions,
		"edges": edges,
		"entrance": entrance_idx,
		"vault": vault_idx,
	}


## Get-or-create the junction at grid cell (c, r). Dictionaries and Arrays pass by
## reference, so the caller's `cells`/`junctions` grow in place.
func _gen_node(cells: Dictionary, junctions: Array, c: int, r: int) -> int:
	var key := Vector2i(c, r)
	if cells.has(key):
		return cells[key]
	var idx: int = junctions.size()
	junctions.append(Vector2(GEN_COLS[c], GEN_ROWS[r]))
	cells[key] = idx
	return idx


func _gen_edge(edges: Array, edge_set: Dictionary, a: int, b: int) -> void:
	if a == b:
		return
	var key := Vector2i(mini(a, b), maxi(a, b))
	if edge_set.has(key):
		return
	edge_set[key] = true
	edges.append([a, b])


## Seeded Fisher-Yates, so branch directions stay deterministic per board rather
## than depending on the engine's global RNG.
func _gen_shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


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
		"Cannon fodder. Weak, fast, never alone. A dozen squires is still 300 Gold out the door.")

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
		"Not a bigger Knight — the SHIELD. Hits soft, wears less armour. 100% purity, and BLESSES its escort to 85%: while it lives your Succubus is useless. 60% magic def, so poison is the wrong key. Takes no Gold. Kill it FIRST.")

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

	_hero_lore()


## Bestiary strengths/weaknesses. Kept together so the whole roster reads as one
## voice, and so the counter-matrix numbers stay consistent between entries.
func _hero_lore() -> void:
	heroes["squire"].strengths = PackedStringArray([
		"Never alone. Six or more per wave, and a dozen still walk out with 300 Gold.",
		"Flees 15% faster than it advances (101 vs 88) — it's already moving when you react.",
		"Cheap enough that the kingdom never stops sending them.",
	])
	heroes["squire"].weaknesses = PackedStringArray([
		"42 HP and only 10% armour. A Crossbow Turret kills one in 2.0s.",
		"20% purity — the Succubus turns it 80% of the time.",
		"Steals only 25. One leak is survivable; it's the tenth that kills you.",
	])

	heroes["treasure_hunter"].strengths = PackedStringArray([
		"Steals 160 in one grab — over 6x a Squire, from a single body.",
		"The fastest thing in the game: 135 in, 216 fleeing.",
		"Ignores your minions completely. They cannot block or bait it.",
	])
	heroes["treasure_hunter"].weaknesses = PackedStringArray([
		"30 HP, no armour, no magic defence. A Crossbow kills it in 1.3s.",
		"0% purity — the Succubus charms it EVERY time, without fail.",
		"Deals no damage whatsoever. It cannot harm a trap or a minion.",
		"It dies easily; the trick is that it'll be BEHIND your traps. Cover the way out.",
	])

	heroes["knight"].strengths = PackedStringArray([
		"75% armour. A Crossbow Turret needs 22 seconds to get through it.",
		"12.7 DPS butchers your minions — a goblin dies in 3s, the whole pack in under 10.",
		"130 HP, the second-deepest pool in the game.",
	])
	heroes["knight"].weaknesses = PackedStringArray([
		"0% magic defence. Poison kills it in 9s instead of 22s — that gap IS the lesson.",
		"58 speed and no flee bonus: the slowest raider, so it spends the longest in your traps.",
		"50% purity is a coin flip, and the Succubus re-rolls every 6 seconds.",
	])

	heroes["acolyte"].strengths = PackedStringArray([
		"Heals 2.7 HP/sec — almost exactly enough to undo one Dart Launcher.",
		"Arrives beside real threats and quietly cancels your chip damage.",
	])
	heroes["acolyte"].weaknesses = PackedStringArray([
		"35 HP, no armour, no magic defence. Everything kills it quickly.",
		"85% charmable — the easiest hero in the game to turn.",
		"Its heal is small enough that any burst damage simply outruns it.",
	])

	heroes["priestess"].strengths = PackedStringArray([
		"5.6 HP/sec — more than a Crossbow Turret does to an armoured Knight.",
		"165 heal range lets her mend from outside most of your trap coverage.",
		"Always mends whoever is worst hurt, so spreading damage achieves nothing.",
	])
	heroes["priestess"].weaknesses = PackedStringArray([
		"45 HP and 0% armour — she folds to any physical trap in about 3 seconds.",
		"70% charmable.",
		"Deals no damage at all. She is only ever as dangerous as what she keeps alive.",
	])

	heroes["high_priestess"].strengths = PackedStringArray([
		"10 HP/sec across a 200 range. No single physical trap out-damages that through armour.",
		"30% magic defence, so poison is a poor answer to her as well.",
		"55% purity — she resists the Succubus more often than she falls to her.",
	])
	heroes["high_priestess"].weaknesses = PackedStringArray([
		"Only 70 HP. Every answer to her is worse than usual, but the body is still soft.",
		"Reach her and she dies fast — the whole problem is getting to her.",
		"Kill her and the wave collapses at once.",
	])

	heroes["paladin"].strengths = PackedStringArray([
		"100% purity. Cannot ever be charmed — not once, not with any upgrade.",
		"Blesses every hero within 150 to 85% purity, switching your Succubus off entirely.",
		"170 HP with 50% armour AND 60% magic defence — the deepest pool in the game.",
	])
	heroes["paladin"].weaknesses = PackedStringArray([
		"Poison is the WRONG key: 60% magic defence makes it worse than physical (30s vs 14s).",
		"Only 5.7 DPS. It barely fights — it's a shield, not a sword.",
		"Takes no Gold at all, so letting it walk out costs you nothing directly.",
		"Kill it and the blessing lapses instantly — its escort becomes charmable mid-wave.",
	])


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
	## FOUR turrets to THREE passives, on purpose: the active ones are what make a
	## wave fun to watch, so they outnumber the set-and-forget auras.
	var dart := _trap("dart_launcher", "Dart Launcher", TrapData.Kind.TURRET, 55, 5.0, "physical",
		120.0, 0.35, Color(0.72, 0.68, 0.46),
		"Cheap, twitchy, and always shooting. It never wins a fight alone — it just never stops.")
	dart.glyph = "dart"
	## The Dart Launcher is 'simple': always shoots the FIRST hero, locked.
	dart.targeting = TrapData.Targeting.FIRST
	dart.fixed_targeting = true
	dart.icon = _load_png_raw("res://assets/textures/DartTrap.png")

	var crossbow := _trap("crossbow", "Crossbow Turret", TrapData.Kind.TURRET, 110, 13.0, "physical",
		160.0, 0.55, Color(0.55, 0.35, 0.22),
		"Shoots whatever is deepest in. Level it and it starts picking.")
	crossbow.glyph = "crossbow"
	## Starts dumb: it shoots the lead raider and can't be told otherwise until
	## Lv 2. The first upgrade buys judgement, not just damage.
	crossbow.targeting_level = 2

	## The armour answer. A Knight shrugs off 75% of physical; this ignores that
	## axis entirely and goes at his 0% magic defence instead.
	var arcane := _trap("magic_turret", "Magic Turret", TrapData.Kind.TURRET, 135, 11.0, "magic",
		150.0, 0.60, Color(0.58, 0.45, 0.92),
		"Armour is a suit of metal. This was never going to care about a suit of metal.")
	arcane.glyph = "arcane"

	## The crowd answer. Siege damage halves armour, and the shell catches whoever
	## is standing near the target — the counter to a packed squire wave.
	var mortar := _trap("explosive_turret", "Explosive Turret", TrapData.Kind.TURRET, 165, 26.0, "siege",
		190.0, 1.50, Color(0.92, 0.48, 0.20),
		"Slow, expensive, and it does not care how tightly they were standing together.")
	mortar.glyph = "mortar"
	mortar.splash_radius = 62.0
	mortar.targeting = TrapData.Targeting.TOUGHEST

	crossbow.icon = _load_keyed("res://assets/textures/CrossBowTrap.png")

	var frost := _trap("frost_totem", "Frost Totem", TrapData.Kind.SLOW_AURA, 85, 0.0, "physical",
		130.0, 1.0, Color(0.45, 0.78, 0.95), "Does no damage. Wins the level.")
	frost.slow_amount = 0.45
	var poison := _trap("poison_fungus", "Poison Fungus", TrapData.Kind.AREA_DAMAGE, 90, 5.0, "magic",
		52.0, 0.35, Color(0.45, 0.75, 0.35), "Armour is no help against a smell.")
	poison.glyph = "fungus"
	var brazier := _trap("cursed_brazier", "Cursed Brazier", TrapData.Kind.WEAKEN_AURA, 120, 0.0, "physical",
		140.0, 1.0, Color(0.55, 0.15, 0.35), "Let them mend it. It won't hold.")
	brazier.weaken_damage_bonus = 0.30
	brazier.weaken_heal_cut = 0.60


## THE DUNGEON STONE, shrunk to its tiling size. Loaded once and handed to both
## the board and the screen backdrop behind it, so the two are the same masonry at
## the same scale rather than two textures that drift apart when either is retuned.
const STONE_PATH := "res://assets/textures/dungeon_stone.png"
## The sheet is authored at roughly the size of the whole board, so tiled at its
## native size a single block comes out as big as a hero. Raise toward 1.0 for
## bigger blocks, lower for finer cobbles.
const STONE_TILE_SCALE := 0.25

var _stone_tile: Texture2D = null


func stone_tile() -> Texture2D:
	if _stone_tile == null:
		_stone_tile = _shrink(load_texture(STONE_PATH), STONE_TILE_SCALE)
	return _stone_tile


## A smaller copy of a texture, for tiling more often. Returns the original
## unchanged if there's nothing sensible to do — big stone beats no stone.
func _shrink(tex: Texture2D, factor: float) -> Texture2D:
	if tex == null or factor <= 0.0 or factor >= 1.0:
		return tex
	var img := tex.get_image()
	if img == null:
		return tex
	img.decompress()   ## imported textures can come back VRAM-compressed
	var w := maxi(int(round(float(img.get_width()) * factor)), 1)
	var h := maxi(int(round(float(img.get_height()) * factor)), 1)
	img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


## Load a texture whether or not Godot has imported it yet. Prefers the imported
## resource (mipmaps, compression); falls back to reading the PNG straight off
## disk, which is what a CLI run on freshly-dropped art needs.
func load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var t := load(path) as Texture2D
		if t != null:
			return t
	return _load_png_raw(path)


## Load a PNG straight off disk into an ImageTexture, bypassing Godot's import
## pipeline — needed for art that a headless CLI run hasn't imported yet (no
## .import/.ctex). The file already has a transparent background, so no keying.
func _load_png_raw(path: String) -> Texture2D:
	var img := Image.new()
	if img.load(path) != OK:
		return null
	return ImageTexture.create_from_image(img)


## Load a PNG and knock its (near-)white background out to transparent, so art
## authored on a white sheet drops cleanly onto the board. Threshold is generous
## enough to catch off-white; if it ever eats a light highlight in the art, raise
## it toward 1.0. Runs once at startup.
func _load_keyed(path: String, threshold: float = 0.90) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return tex
	img.decompress()   ## imported textures can come back VRAM-compressed
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()

	## 1) White (background) -> transparent.
	for y in h:
		for x in w:
			var col := img.get_pixel(x, y)
			if col.a > 0.0 and col.r >= threshold and col.g >= threshold and col.b >= threshold:
				img.set_pixel(x, y, Color(col.r, col.g, col.b, 0.0))

	## 2) Knock out a dark BORDER FRAME by flood-filling dark pixels inward from the
	## edges. It stops at the transparent moat the white key just made, so the
	## sprite's own dark outlines (separated from the frame by that moat) survive.
	var stack: Array[Vector2i] = []
	for x in w:
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, h - 1))
	for y in h:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.x >= w or p.y < 0 or p.y >= h:
			continue
		var col := img.get_pixel(p.x, p.y)
		if col.a <= 0.0:
			continue   ## transparent — the moat; stop here
		if maxf(col.r, maxf(col.g, col.b)) > 0.30:
			continue   ## not frame-dark; leave the art alone
		img.set_pixel(p.x, p.y, Color(col.r, col.g, col.b, 0.0))
		stack.append(Vector2i(p.x + 1, p.y))
		stack.append(Vector2i(p.x - 1, p.y))
		stack.append(Vector2i(p.x, p.y + 1))
		stack.append(Vector2i(p.x, p.y - 1))

	return ImageTexture.create_from_image(img)


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
	goblins.allure_arrive = 2000.0      ## bar-marker position (earned, not hoard-summoned)
	goblins.allure_desert = 1600.0
	goblins.acquire_mode = "earn"       ## EARNED by surviving your first wave
	goblins.unlock_wave = 1
	## Gems are a SHORTCUT, never an exclusive: everything with a gem price here can
	## still be had for free by waiting — clearing the wave, or growing the hoard.
	## What the gems buy is skipping that, and permanence (see AllureSystem).
	goblins.recruit_gems = 12
	goblins.color = Color(0.45, 0.72, 0.35)
	goblins.radius = 10.0
	goblins.description = "Three separate goblins, 40 HP each. They chase whoever carries your Gold. A Knight cuts one down in 3s. Earned by clearing wave 1 — loyal for good once earned."
	goblins.strengths = PackedStringArray([
		"Three bodies, not one. A single big hit only removes a third of the pack.",
		"Hunts whoever is CARRYING your Gold, not whoever is nearest — one catch pays for the whole pack.",
		"30 DPS as a pack against unarmoured targets: it kills a 42 HP Squire in under 2s.",
		"Costs nothing. No Gold, no souls, and it never deserts however poor you get.",
	])
	goblins.weaknesses = PackedStringArray([
		"Physical damage, so armour guts it: 30 DPS becomes 7.5 against a 75%-armour Knight (~17s to kill).",
		"40 HP and no armour. A Knight kills one goblin every 3 seconds.",
		"Melee only — it has to close, so a fleeing Treasure Hunter (135 speed vs its 105) simply outruns it.",
	])
	minions["goblin_pack"] = goblins

	## The two middle rungs of the ladder. Both are AUTO — pulled out of the dark by
	## the size of the pile, like the Succubus — because that is what makes the
	## markers on the hoard bar mean something: cross the number, something arrives.
	## They also both HOLD GROUND (pursue_thieves_first = false), which is the role
	## nothing else on the roster fills: the Goblins, Succubus and Wraith all chase
	## whoever is carrying, and a chaser leaves the corridor it was standing in.
	var troll := MinionData.new()
	troll.id = "troll"
	troll.display_name = "Troll"
	troll.unit_name = "Troll"
	troll.max_hp = 150.0
	troll.speed = 82.0
	troll.damage = 13.0
	troll.attack_rate = 1.1
	troll.attack_range = 30.0
	troll.count = 1
	troll.pursue_thieves_first = false
	troll.allure_arrive = 4000.0
	troll.allure_desert = 3200.0
	troll.acquire_mode = "auto"
	troll.recruit_gems = 30
	troll.color = Color(0.42, 0.55, 0.34)
	troll.radius = 14.0
	troll.description = "150 HP of wall. It doesn't chase anyone — it stands where you put it and makes them come through. Drawn out by a hoard of 4000."
	troll.strengths = PackedStringArray([
		"150 HP with no armour to spare — nearly four times a Goblin, and a Knight needs 11s to chew through it.",
		"Holds its ground instead of chasing, so the corridor you posted it in stays blocked.",
		"11.8 DPS against unarmoured raiders: it kills a 42 HP Squire in under 4s while soaking their hits.",
		"Costs nothing but a rich hoard. No souls, no Gold, no wave to clear.",
	])
	troll.weaknesses = PackedStringArray([
		"Physical, so armour guts it: 11.8 DPS becomes 3.0 against a 75%-armour Knight (~44s to kill one).",
		"82 speed. A fleeing Treasure Hunter moves at 216 — it will never catch anything.",
		"Deserts below 3200 Gold, and a bad wave takes you there fast.",
		"One body. Focus it down and the corridor is open again.",
	])
	minions["troll"] = troll

	var ogre := MinionData.new()
	ogre.id = "ogre"
	ogre.display_name = "Ogre"
	ogre.unit_name = "Ogre"
	ogre.max_hp = 200.0
	ogre.speed = 70.0
	ogre.damage = 30.0
	ogre.attack_rate = 2.0
	ogre.attack_range = 34.0
	ogre.count = 1
	ogre.pursue_thieves_first = false
	ogre.allure_arrive = 7000.0
	ogre.allure_desert = 5600.0
	ogre.acquire_mode = "auto"
	ogre.recruit_gems = 45
	ogre.color = Color(0.62, 0.45, 0.30)
	ogre.radius = 16.0
	ogre.description = "One swing every 2 seconds, and the swing is 30. The deepest body you can field and the slowest thing on the board. Drawn out by a hoard of 7000."
	ogre.strengths = PackedStringArray([
		"30 damage in a single blow — it one-shots nothing the Goblins could kill, then kills it anyway.",
		"200 HP, the deepest pool of any Anti-Hero. A Knight takes 15s to bring it down.",
		"34 reach, the longest melee on the roster: it starts hitting before anything else would.",
		"Holds the corridor rather than chasing, so it never wanders off the ground you gave it.",
	])
	ogre.weaknesses = PackedStringArray([
		"Physical, so armour answers it: 15 DPS drops to 3.8 against a 75%-armour Knight.",
		"A 2s swing is a 2s WINDOW — a Squire that walks past between blows takes nothing at all.",
		"70 speed, the slowest unit in the game. It cannot chase, catch, or reposition.",
		"Deserts below 5600 Gold.",
	])
	minions["ogre"] = ogre

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
	## The only threshold the game actually enforces — she's the sole AUTO unit.
	succubus.allure_arrive = 8000.0
	succubus.allure_desert = 6400.0
	succubus.pursue_thieves_first = true
	succubus.acquire_mode = "auto"      ## the ONLY automatic one — drawn by a rich hoard
	succubus.can_charm = true
	succubus.charm_range = 170.0
	succubus.charm_cooldown = 6.0
	succubus.charm_duration = 5.0
	succubus.charm_power = 0.5
	succubus.color = Color(0.85, 0.25, 0.55)
	succubus.radius = 11.0
	succubus.description = "Drawn only by a rich hoard — 8000 Gold brings her out. She CHARMS a thief into carrying your Gold back for you. Beaten only by purity. Fragile. Protect her."
	succubus.strengths = PackedStringArray([
		"Turns a loss into a gain — a charmed thief walks your Gold BACK to the vault instead of out the door.",
		"Charm ignores HP, armour and magic defence entirely. She beats things she could never kill.",
		"170 range and a re-roll every 6s, so across a long corridor a coin-flip target falls roughly 78% of the time.",
		"Arrives free the moment the hoard reaches 8000. No souls, no Gold.",
	])
	succubus.weaknesses = PackedStringArray([
		"Barely fights: 4 damage every 1.2s is 3.3 DPS. She cannot kill anything on her own.",
		"55 HP and no armour — a Knight cuts her down in about 4 seconds. She needs a bodyguard.",
		"Beaten flat by purity. A Paladin is 100% pure AND blesses its escort to 85%, which switches her off completely.",
		"She DESERTS below 6400 Gold — and being the dearest of the hoard-drawn monsters, she is the first one out the door when things go badly.",
	])
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
	wraith.allure_arrive = 9000.0       ## bar-marker position (bought, not hoard-summoned)
	wraith.allure_desert = 7200.0
	wraith.acquire_mode = "buy"
	wraith.recruit_souls = 25
	wraith.recruit_gems = 30
	wraith.color = Color(0.55, 0.35, 0.75)
	wraith.radius = 12.0
	wraith.description = "A vengeful shade bought with souls. Hits hard, moves fast, and hunts whoever carries your Gold. Yours for good once recruited."
	wraith.strengths = PackedStringArray([
		"The hardest hitter you can field: 16 damage every 0.9s = 17.8 DPS from a single unit.",
		"120 speed — faster than every hero except the Treasure Hunter, so it can actually run thieves down.",
		"Hunts Gold-carriers first, and kills a 30 HP Treasure Hunter in under 2 seconds.",
		"Bought once with souls and yours permanently. It never deserts, however poor the hoard gets.",
	])
	wraith.weaknesses = PackedStringArray([
		"Costs 25 souls (or 30 gems) up front — the only Anti-Hero you must pay for.",
		"Physical damage, so armour still answers it: 17.8 DPS drops to 4.4 against a 75%-armour Knight (~30s).",
		"90 HP and no armour. A Knight kills it in about 7 seconds.",
		"Only one of it. Focus it down and your whole offence is gone until the next level.",
	])
	minions["wraith"] = wraith


func wave_count() -> int:
	return WAVES.size()
