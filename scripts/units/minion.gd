extends Node2D
class_name Minion

## A monster your HOARD attracted. Mobile, loyal to the pile, and it PURSUES
## FLEEING THIEVES — which is what makes it worth more than its damage.

var data: MinionData
var hp: float

## Which one of the pack this is (three goblins are three separate creatures).
var pack_index: int = 0
var pack_size: int = 1

var _home: Vector2
var _attack_cd: float = 0.0
var _charm_cd: float = 0.0
var _target: Hero = null

var restless: bool = false   ## telegraphed "about to leave" during build window
var selected: bool = false

const LEASH := 260.0


func setup(minion_data: MinionData, home: Vector2) -> void:
	data = minion_data
	hp = data.max_hp
	_home = home
	position = home


func is_alive() -> bool:
	return hp > 0.0


func take_damage(amount: float, _damage_type: String = "physical") -> void:
	hp -= amount
	if hp <= 0.0:
		queue_free()
		return
	queue_redraw()


func _physics_process(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_charm_cd = maxf(0.0, _charm_cd - delta)

	var heroes := get_tree().get_nodes_in_group("heroes")
	_target = _pick_target(heroes)

	if data.can_charm and _charm_cd <= 0.0:
		if _try_charm(heroes):
			_charm_cd = data.charm_cooldown

	if _target == null:
		_return_home(delta)
		queue_redraw()
		return

	var to_target := _target.position - position
	var dist := to_target.length()
	if dist > data.attack_range:
		position += to_target.normalized() * data.speed * delta
	elif _attack_cd <= 0.0:
		_target.take_damage(data.damage, "physical")
		_attack_cd = data.attack_rate

	queue_redraw()


## Thieves first, always.
func _pick_target(heroes: Array) -> Hero:
	var best: Hero = null
	var best_score := -INF
	for h in heroes:
		var hero := h as Hero
		if hero == null or not hero.is_alive():
			continue
		if hero.is_charmed():
			continue
		if position.distance_to(hero.position) > LEASH:
			continue
		var score := -position.distance_to(hero.position)
		if data.pursue_thieves_first and hero.is_carrying():
			score += 10000.0
		if score > best_score:
			best_score = score
			best = hero
	return best


## Charm the greediest thief in range. Returns true if an ATTEMPT was made (the
## caller spends the cooldown whether or not the charm landed — see comment).
func _try_charm(heroes: Array) -> bool:
	var best: Hero = null
	var best_score := -INF
	for h in heroes:
		var hero := h as Hero
		if hero == null or not hero.is_alive() or hero.is_charmed():
			continue
		if position.distance_to(hero.position) > data.charm_range:
			continue
		var score := float(hero.carried_gold) * 100.0
		score -= position.distance_to(hero.position)
		if score > best_score:
			best_score = score
			best = hero
	if best == null:
		return false
	## Cooldown spent on the ATTEMPT, not on success — else she'd re-roll every
	## frame and a 50% purity would mean nothing.
	best.try_charm(data.charm_duration, data.charm_power)
	return true


func _return_home(delta: float) -> void:
	var to_home := _home - position
	if to_home.length() > 4.0:
		position += to_home.normalized() * data.speed * 0.6 * delta


func _draw() -> void:
	var r := data.radius

	if restless:
		draw_arc(Vector2.ZERO, r + 8.0, 0.0, TAU, 24, Color(1.0, 0.35, 0.2, 0.9), 2.0)
	if data.can_charm and data.charm_range > 0.0:
		draw_arc(Vector2.ZERO, data.charm_range, 0.0, TAU, 48, Color(0.9, 0.3, 0.6, 0.10), 1.0)

	draw_circle(Vector2.ZERO, r, data.color)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 20, Color(0, 0, 0, 0.5), 1.5)

	if selected:
		draw_arc(Vector2.ZERO, r + 11.0, 0.0, TAU, 28, Color(1, 1, 1, 0.95), 2.5)

	## Screen-aligned overlays (cancel world rotation).
	draw_set_transform(Vector2.ZERO, -global_rotation, Vector2.ONE)

	draw_line(Vector2(-r * 0.6, -r * 0.7), Vector2(-r * 0.9, -r * 1.5), Color(0, 0, 0, 0.7), 2.0)
	draw_line(Vector2(r * 0.6, -r * 0.7), Vector2(r * 0.9, -r * 1.5), Color(0, 0, 0, 0.7), 2.0)

	var pct := clampf(hp / data.max_hp, 0.0, 1.0)
	var w := r * 2.2
	var bar := Vector2(-w * 0.5, -r - 9.0)
	draw_rect(Rect2(bar, Vector2(w, 3.0)), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(bar, Vector2(w * pct, 3.0)), Color(0.4, 0.85, 0.4))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
