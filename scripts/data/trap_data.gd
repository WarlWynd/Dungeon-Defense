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

## "Simple" traps: their targeting is locked and the inspector offers no "tap to
## change" button. The Dart Launcher is one — it just shoots whoever's in front.
@export var fixed_targeting: bool = false

## The level at which this trap earns the right to CHOOSE. Below it the turret
## shoots its default priority and the inspector offers no button; 1 means it can
## choose from the moment it's built. Ignored entirely when fixed_targeting is on,
## which is a permanent "never".
##
## This is a reason to upgrade that isn't a bigger number — the Crossbow starts
## dumb and becomes able to answer "the healer is at the back" only once you've
## paid to level it.
@export var targeting_level: int = 1

## Explosive turrets damage every OTHER hero within this radius of the one they
## shot, at SPLASH_FALLOFF strength. 0 = single target, like the crossbow.
@export var splash_radius: float = 0.0

## Which drawn shape to use when `icon` is null. Without this every TURRET draws
## the same box-and-barrel, so four different turrets would be unreadable in the
## tray. Ignored when real art is assigned.
@export var glyph: String = ""

## Weaken / Rot: +damage taken, -healing received. No targeting needed.
@export var weaken_damage_bonus: float = 0.0
@export var weaken_heal_cut: float = 0.0

@export var color: Color = Color.WHITE
@export var flavor: String = ""

## Optional real artwork. When set, it REPLACES the procedural glyph both in the
## trap tray and on the board — drop a texture here (e.g. a 64x64 sprite) with no
## other code changes needed. Leave null to use the drawn placeholder glyph.
@export var icon: Texture2D = null
