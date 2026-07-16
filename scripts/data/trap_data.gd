extends Resource
class_name TrapData

## Data-driven definition of a trap.

enum Kind {
	AREA_DAMAGE,   ## Spike Pit — hits anything standing on it
	TURRET,        ## Crossbow — shoots one hero, by priority
	SLOW_AURA,     ## Frost Totem — no damage, slows in radius
	WEAKEN_AURA,   ## Cursed Brazier — no damage; ROTS what it touches
}

## Targeting priority — the player's answer to "I can't reach the healer".
enum Targeting {
	FIRST,      ## deepest into the dungeon (default)
	LAST,       ## furthest back — reaches the support line
	NEAREST,    ## closest to the trap
	TOUGHEST,   ## highest max HP
	HEALER,     ## priests first, always
	CARRIER,    ## whoever is carrying your gold
}

@export var id: String = ""
@export var display_name: String = "Trap"
@export var kind: Kind = Kind.TURRET

@export var cost: int = 100
@export var damage: float = 10.0
@export var damage_type: String = "physical"
## Named attack_range, not `range` — range() is a GDScript builtin.
@export var attack_range: float = 140.0
@export var fire_rate: float = 1.0
@export var slow_amount: float = 0.0

@export var targeting: Targeting = Targeting.FIRST

## Weaken / Rot: +damage taken, -healing received. No targeting needed.
@export var weaken_damage_bonus: float = 0.0
@export var weaken_heal_cut: float = 0.0

@export var color: Color = Color.WHITE
@export var flavor: String = ""
