extends Node

## THE HOARD IS ONE NUMBER OWNED BY ONE SYSTEM. Nothing else mutates `hoard`
## directly — heroes request a steal and this decides. It does four jobs:
## build currency, health bar, Allure rating, and score.

var hoard: int = 0
var starting_hoard: int = 0
var gold_lost: int = 0          ## carried out the front door — gone
var total_plundered: int = 0    ## looted from corpses — the only growth

## What the vault could hold if you filled it — the number the HUD bar counts
## toward. Deliberately NOT the same as `starting_hoard`: you begin with a corner
## of a vault built for far more, so plundering has somewhere visible to go, and
## the Anti-Hero thresholds (plain Gold amounts on MinionData) have room to sit
## above where you start.
var capacity: int = 0


func reset(start_amount: int, capacity_amount: int = 0) -> void:
	starting_hoard = start_amount
	hoard = start_amount
	capacity = maxi(capacity_amount, start_amount)
	gold_lost = 0
	total_plundered = 0
	EventBus.hoard_changed.emit(hoard)


## Fraction of the STARTING hoard still in the vault. Drives the vault room's coin
## stacks, so emptying the pile you began with visibly empties the room. Allure no
## longer reads this — minions are called by absolute Gold amounts.
func hoard_fraction() -> float:
	if starting_hoard <= 0:
		return 0.0
	return float(hoard) / float(starting_hoard)


## How full the vault itself is, 0..1 — what the HUD bar fills to. Clamped, so a
## hoard that outgrows its capacity overflows the number, never the bar.
func capacity_fraction() -> float:
	if capacity <= 0:
		return 0.0
	return clampf(float(hoard) / float(capacity), 0.0, 1.0)


## Where a given AMOUNT of gold sits along the bar, 0..1. The Allure ticks are
## authored as fractions of the starting hoard, so this is what puts them at the
## right place on a bar that measures capacity.
func bar_position(amount: float) -> float:
	if capacity <= 0:
		return 0.0
	return clampf(amount / float(capacity), 0.0, 1.0)


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
