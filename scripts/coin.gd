extends Node2D
class_name Coin

## Gold flying home to the vault — spilled by a dead thief (recover) or looted
## from a corpse (plunder). The coins-come-home moment is what makes a kill feel
## like a rescue.

var amount: int = 0
var is_plunder: bool = false

var _from: Vector2
var _to: Vector2
var _t: float = 0.0

const FLIGHT_TIME := 0.55


func setup(from: Vector2, to: Vector2, gold: int, plunder: bool = false) -> void:
	amount = gold
	is_plunder = plunder
	_from = from
	_to = to
	position = from


func _process(delta: float) -> void:
	_t += delta / FLIGHT_TIME
	if _t >= 1.0:
		if is_plunder:
			EconomySystem.plunder(amount)   ## new gold — grows the pile
		else:
			EconomySystem.recover(amount)   ## your own gold, snatched back
		queue_free()
		return

	var e := _t * _t
	position = _from.lerp(_to, e)
	position.y -= sin(_t * PI) * 40.0
	queue_redraw()


func _draw() -> void:
	## A small stack of coins flying home, not a single disc — the same shape the
	## vault and the thief use, so you can see it's YOUR pile coming back.
	var gold := Color(1.0, 0.92, 0.55) if is_plunder else Color(1.0, 0.84, 0.2)
	var edge := Color(0.5, 0.35, 0.0)
	var coins := 2 if is_plunder else 3
	draw_set_transform(Vector2.ZERO, -global_rotation, Vector2.ONE)
	for i in coins:
		var w := 12.0 - 1.7 * float(i)
		var y := -3.6 * float(i)
		var r := Rect2(Vector2(-w * 0.5, y - 3.2), Vector2(w, 3.6))
		draw_rect(r, gold)
		draw_rect(r, edge, false, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
