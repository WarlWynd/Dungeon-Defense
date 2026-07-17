extends Node

## THE HOARD IS ONE NUMBER OWNED BY ONE SYSTEM. Nothing else mutates `hoard`
## directly — heroes request a steal and this decides. It does four jobs:
## build currency, health bar, Allure rating, and score.

var hoard: int = 0
var starting_hoard: int = 0
var gold_lost: int = 0          ## carried out the front door — gone
var total_plundered: int = 0    ## looted from corpses — the only growth


func reset(start_amount: int) -> void:
	starting_hoard = start_amount
	hoard = start_amount
	gold_lost = 0
	total_plundered = 0
	EventBus.hoard_changed.emit(hoard)


## Fraction of the STARTING hoard still in the vault — the Allure rating.
func hoard_fraction() -> float:
	if starting_hoard <= 0:
		return 0.0
	return float(hoard) / float(starting_hoard)


func can_afford(amount: int) -> bool:
	return hoard >= amount


func spend(amount: int) -> bool:
	if not can_afford(amount):
		return false
	hoard -= amount
	EventBus.gold_spent.emit(amount, hoard)
	EventBus.hoard_changed.emit(hoard)
	_check_empty()
	return true


## A hero reached the vault; takes what it can carry (never more than the pile).
func steal(requested: int, thief: Node) -> int:
	var taken := mini(requested, hoard)
	if taken <= 0:
		return 0
	hoard -= taken
	EventBus.gold_stolen.emit(taken, hoard, thief)
	EventBus.hoard_changed.emit(hoard)
	_check_empty()
	return taken


## Thief killed on the way out — its loot comes home.
func recover(amount: int) -> void:
	if amount <= 0:
		return
	hoard += amount
	EventBus.gold_recovered.emit(amount, hoard)
	EventBus.hoard_changed.emit(hoard)


## Store purchase: Gems bought a Gold refill. Adds straight to the hoard.
func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	hoard += amount
	EventBus.hoard_changed.emit(hoard)


## Looted from a corpse — the only thing that grows the pile (can exceed start).
func plunder(amount: int) -> void:
	if amount <= 0:
		return
	hoard += amount
	total_plundered += amount
	EventBus.gold_plundered.emit(amount, hoard)
	EventBus.hoard_changed.emit(hoard)


## Thief escaped with the gold — gone for the rest of the level.
func confirm_loss(amount: int) -> void:
	if amount <= 0:
		return
	gold_lost += amount


func _check_empty() -> void:
	if hoard <= 0:
		hoard = 0
		EventBus.hoard_empty.emit()
