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
	var col := Color(1.0, 0.92, 0.55) if is_plunder else Color(1.0, 0.84, 0.2)
	var r := 5.5 if is_plunder else 7.0
	draw_circle(Vector2.ZERO, r, col)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 14, Color(0.5, 0.35, 0.0), 1.5)
