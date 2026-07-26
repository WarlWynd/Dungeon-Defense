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

## Allure thresholds in GOLD: arrive (higher) and desert (lower). The gap is
## hysteresis, so a hoard hovering on the line doesn't flicker a minion in and
## out. Only AUTO units are actually gated by these — for BUY/EARN units the
## arrive figure is just where their marker sits on the hoard bar.
##
## These are absolute amounts, NOT fractions of the starting hoard: "a Succubus
## comes when you have 2000 Gold" is a goal the player can see on the bar and
## work toward, where "at 75% of what you started with" moves under them every
## time the starting number is retuned.
@export var allure_arrive: float = 1000.0
@export var allure_desert: float = 800.0

## How this Anti-Hero is acquired:
##   "auto" — drawn out by a rich hoard (Troll, Ogre, Succubus). Uses allure.
##   "buy"  — recruited with souls or gems; unlock is permanent.
##   "earn" — unlocked by reaching unlock_wave; unlock is permanent.
## BUY/EARN units, once unlocked, are always present and never desert.
@export var acquire_mode: String = "auto"
@export var recruit_souls: int = 0       ## souls cost for a "buy" unit
@export var recruit_gems: int = 0        ## gems cost for a "buy" unit
@export var unlock_wave: int = 0         ## wave index that unlocks an "earn" unit

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

## Bestiary copy. Kept as separate bullet lists rather than prose so the panel
## can colour them and the player can compare two Anti-Heroes line by line.
## Every entry should cite a NUMBER — "cannot kill armour" is a vibe, "17.8 DPS
## becomes 4.4 against 75% armour" is a decision.
@export var strengths: PackedStringArray = PackedStringArray()
@export var weaknesses: PackedStringArray = PackedStringArray()


## The name of the creature you actually tapped.
func unit_display() -> String:
	return unit_name if unit_name != "" else display_name
