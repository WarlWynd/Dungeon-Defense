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
var _had_target: bool = false

## Corridor route to the commanded post, so the unit walks the tunnels instead of
## cutting through the stone. Supplied by a router Callable (main builds it from
## the board's maze graph or path curve).
var _router: Callable = Callable()
var _route: PackedVector2Array = PackedVector2Array()
var _route_i: int = 0
var _chase_route: PackedVector2Array = PackedVector2Array()
var _chase_i: int = 0
var _chase_target_pos: Vector2 = Vector2.ZERO


func set_router(r: Callable) -> void:
	_router = r

var restless: bool = false   ## telegraphed "about to leave" during build window
var selected: bool = false

## Player order: when you click this Anti-Hero and then click a spot, it GUARDS
## that spot — only engaging heroes that come within GUARD_RADIUS of the post
## and returning there afterwards. Persists across waves while the unit lives.
var commanded: bool = false

const LEASH := 260.0
const GUARD_RADIUS := 160.0


func setup(minion_data: MinionData, home: Vector2) -> void:
	data = minion_data
	hp = data.max_hp
	_home = home
	position = home


func is_alive() -> bool:
	return hp > 0.0


## Player order: guard this spot (design-space point), clamped to the board.
## `router` builds a corridor path from here to the post and is stored so the
## unit can re-route back to its post after chasing a thief.
func command_to(pos: Vector2, router: Callable = Callable()) -> void:
	_home = Vector2(clampf(pos.x, 20.0, 700.0), clampf(pos.y, 20.0, 1260.0))
	commanded = true
	if router.is_valid():
		_router = router
	_set_route_to(_home)
	queue_redraw()


func _set_route_to(target: Vector2) -> void:
	if _router.is_valid():
		_route = _router.call(position, target)
	else:
		_route = PackedVector2Array()
	_route_i = 0


## Move toward a (moving) target along the corridors instead of straight through
## the stone. The route is refreshed only when the target drifts far enough to
## matter, so it's cheap even with several units chasing.
func _chase_toward(target_pos: Vector2, delta: float) -> void:
	if not _router.is_valid():
		position += (target_pos - position).normalized() * data.speed * delta
		return
	if _chase_route.is_empty() or _chase_i >= _chase_route.size() \
			or _chase_target_pos.distance_to(target_pos) > 40.0:
		_chase_route = _router.call(position, target_pos)
		_chase_i = 0
		_chase_target_pos = target_pos
	while _chase_i < _chase_route.size():
		var wp: Vector2 = _chase_route[_chase_i]
		var to_wp := wp - position
		if to_wp.length() <= 8.0:
			_chase_i += 1
			continue
		position += to_wp.normalized() * data.speed * delta
		return
	## Route consumed — final straight step onto the target.
	position += (target_pos - position).normalized() * data.speed * delta


## Walk the corridor waypoints to the post, then step onto the exact spot.
func _follow_route(delta: float) -> void:
	var spd := data.speed * (1.0 if commanded else 0.6)
	while _route_i < _route.size():
		var wp: Vector2 = _route[_route_i]
		var to_wp := wp - position
		if to_wp.length() <= 6.0:
			_route_i += 1
			continue
		position += to_wp.normalized() * spd * delta
		return
	var to_home := _home - position
	if to_home.length() > 3.0:
		position += to_home.normalized() * spd * delta


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
		## Just lost a target — recompute a corridor route back to the post/home.
		if _had_target and _router.is_valid():
			_set_route_to(_home)
		_had_target = false
		if not _route.is_empty():
			_follow_route(delta)
		else:
			_return_home(delta)
		queue_redraw()
		return

	_had_target = true
	var dist := _target.position.distance_to(position)
	if dist > data.attack_range:
		_chase_toward(_target.position, delta)
	elif _attack_cd <= 0.0:
		_target.take_damage(data.damage, "physical")
		_attack_cd = data.attack_rate

	queue_redraw()


## Thieves first, always.
func _pick_target(heroes: Array) -> Hero:
	var best: Hero = null
	var best_score := -INF
	## A commanded Anti-Hero measures its reach from its guarded POST (so it
	## holds the line); a free one measures from itself (so it can chase).
	var center := _home if commanded else position
	var reach := GUARD_RADIUS if commanded else LEASH
	for h in heroes:
		var hero := h as Hero
		if hero == null or not hero.is_alive():
			continue
		if hero.is_charmed():
			continue
		if center.distance_to(hero.position) > reach:
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
		## Move at full speed to a player-ordered post; saunter back otherwise.
		var spd := data.speed * (1.0 if commanded else 0.6)
		position += to_home.normalized() * spd * delta


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

	## Show the guarded post and a tether to it while this unit is selected.
	if commanded and selected:
		var lp := _home - position
		draw_line(Vector2.ZERO, lp, Color(1.0, 0.9, 0.4, 0.5), 1.5)
		draw_arc(lp, 12.0, 0.0, TAU, 24, Color(1.0, 0.9, 0.4, 0.8), 2.0)

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
