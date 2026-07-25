extends Resource
class_name HeroData

## Data-driven definition of a hero (the raiders).

@export var id: String = ""
@export var display_name: String = "Hero"

@export var max_hp: float = 40.0
@export var speed: float = 90.0
@export var flee_speed_mult: float = 1.0

## Three separate defences -> three ways to attack. Fractions, capped so nothing
## is ever fully immune to damage.
@export_range(0.0, 0.9) var armor: float = 0.0
@export_range(0.0, 0.9) var magic_defense: float = 0.0
@export_range(0.0, 1.0) var purity: float = 0.0

## The Paladin's aura: projects a purity floor onto nearby heroes.
@export_range(0.0, 1.0) var purity_aura: float = 0.0
@export var purity_aura_range: float = 0.0

## Offence. damage == 0 means pacifist (ignores minions, just runs).
@export var damage: float = 0.0
@export var attack_rate: float = 1.0
@export var attack_range: float = 30.0

## Healing. amount == 0 means not a healer.
@export var heal_amount: float = 0.0
@export var heal_rate: float = 2.5
@export var heal_range: float = 0.0

## Greed = what it steals. Bounty = what you loot from its corpse (< greed).
@export var greed: int = 20
@export var bounty: int = 8

@export var color: Color = Color.WHITE
@export var radius: float = 12.0
@export_multiline var description: String = ""

## --- Art ---
## Optional. Leave null and the hero draws its procedural glyph instead, so art
## can land one class at a time. Build this from a PNG sprite SHEET (one texture
## per hero, sliced in the SpriteFrames editor) — Godot has no GIF importer, and
## GIF's 1-bit alpha would hard-edge against the glow rings Hero._draw() puts
## behind the body.
##
## Animations must be named "walk_n" / "walk_e" / "walk_s" / "walk_w", pointing
## the way the hero moves ON SCREEN. "walk_w" is optional: leave it out and
## "walk_e" is mirrored for it, so three direction sets cover all four.
@export var frames: SpriteFrames
@export var sprite_scale: float = 1.0

## Bestiary copy. Bullet lists rather than prose so the panel can colour them.
## Every entry should cite a NUMBER — "tough" is a vibe, "75% armour makes a
## crossbow take 22 seconds" is a decision.
@export var strengths: PackedStringArray = PackedStringArray()
@export var weaknesses: PackedStringArray = PackedStringArray()


const RESIST_CAP := 0.8
const BASE_POWER := 0.5


func resist_to(damage_type: String) -> float:
	match damage_type:
		"physical":
			return minf(armor, RESIST_CAP)
		"magic":
			return minf(magic_defense, RESIST_CAP)
		"siege":
			return minf(armor * 0.5, RESIST_CAP)
		_:
			return 0.0


## Purity is a resistance CHANCE: P(charm) = (1 - effective_purity) + (power - 0.5).
func charm_chance(power: float, blessing: float = 0.0) -> float:
	var effective := maxf(purity, blessing)
	return clampf((1.0 - effective) + (power - BASE_POWER), 0.0, 1.0)
