extends Resource
class_name MinionData

## A monster attracted by the HOARD. You don't buy these; they come for the gold
## and leave when you're poor. Even minions have standards.

@export var id: String = ""

## Two names: display_name is the arrival GROUP ("Goblin Pack"); unit_name is
## the single CREATURE you tap ("Goblin").
@export var display_name: String = "Minion"
@export var unit_name: String = ""

@export var max_hp: float = 60.0
@export var speed: float = 110.0
@export var damage: float = 9.0
@export var attack_rate: float = 0.8
@export var attack_range: float = 26.0

@export var count: int = 3

## Allure thresholds: arrive (higher) and desert (lower). The gap is hysteresis.
@export var allure_arrive: float = 0.5
@export var allure_desert: float = 0.4

@export var pursue_thieves_first: bool = true

## Charm (the Succubus). Gated by the target's purity.
@export var can_charm: bool = false
@export var charm_range: float = 0.0
@export var charm_cooldown: float = 6.0
@export var charm_duration: float = 5.0
@export_range(0.0, 1.0) var charm_power: float = 0.5

@export var color: Color = Color.WHITE
@export var radius: float = 11.0
@export_multiline var description: String = ""


## The name of the creature you actually tapped.
func unit_display() -> String:
	return unit_name if unit_name != "" else display_name
