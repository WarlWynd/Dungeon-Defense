extends Node2D
class_name Hero

## A "good guy" — here to steal your gold and leave. You are the dungeon.
## State machine IS the game: ADVANCING -> LOOTING -> FLEEING -> ESCAPED.
## Kill it while FLEEING and the gold comes home; let it ESCAPE and it's gone.

enum State { ADVANCING, LOOTING, FLEEING, ESCAPED, DEAD, CHARMED, RETURNING }

var data: HeroData
var state: State = State.ADVANCING

var hp: float
var carried_gold: int = 0
var _charm_timer: float = 0.0

var selected: bool = false

## Walks its APPROACH curve to the vault, then its ESCAPE curve back out.
## Linear boards: escape = approach reversed. Maze: approach is a random route,
## escape is the shared shortest way out. `_on_escape` says which is active,
## since the vault sits at opposite ends of the two curves.
var _curve: Curve2D
var _approach: Curve2D
var _escape: Curve2D
var _escape_length: float = 0.0
var _on_escape: bool = false
var _progress: float = 0.0
var _path_length: float = 0.0
var _loot_timer: float = 0.0

var _slow_timer: float = 0.0
var _slow_amount: float = 0.0
var _attack_cd: float = 0.0

var _blessing: float = 0.0
var _blessing_timer: float = 0.0

var _resist_flash: float = 0.0

var _heal_cd: float = 0.0
var _healed_flash: float = 0.0
var _cast_target: Vector2 = Vector2.ZERO
var _cast_flash: float = 0.0

var _rot_timer: float = 0.0
var _rot_damage_bonus: float = 0.0
var _rot_heal_cut: float = 0.0

const LOOT_DURATION := 0.55


func setup(hero_data: HeroData, approach: Curve2D, escape: Curve2D = null) -> void:
	data = hero_data
	_approach = approach
	_escape = escape if escape != null else _reversed(approach)
	_escape_length = _escape.get_baked_length()

	_curve = _approach
	_path_length = _approach.get_baked_length()
	_on_escape = false
	_progress = 0.0

	hp = data.max_hp
	position = _curve.sample_baked(0.0)


func _reversed(c: Curve2D) -> Curve2D:
	var out := Curve2D.new()
	var pts := c.get_baked_points()
	for i in range(pts.size() - 1, -1, -1):
		out.add_point(pts[i])
	return out


func is_carrying() -> bool:
	return carried_gold > 0


## 0..1 where 1 == at the vault. Traps sort on this for FIRST/LAST targeting.
func path_progress() -> float:
	if _path_length <= 0.0:
		return 0.0
	var frac := _progress / _path_length
	return (1.0 - frac) if _on_escape else frac


func is_healer() -> bool:
	return data.heal_amount > 0.0


func apply_rot(damage_bonus: float, heal_cut: float) -> void:
	_rot_damage_bonus = maxf(_rot_damage_bonus, damage_bonus)
	_rot_heal_cut = maxf(_rot_heal_cut, heal_cut)
	_rot_timer = 0.12


func is_rotted() -> bool:
	return _rot_timer > 0.0 and (_rot_damage_bonus > 0.0 or _rot_heal_cut > 0.0)


func rot_heal_cut() -> float:
	return _rot_heal_cut if _rot_timer > 0.0 else 0.0


func is_alive() -> bool:
	return state != State.DEAD and state != State.ESCAPED


func apply_slow(amount: float) -> void:
	_slow_amount = maxf(_slow_amount, amount)
	_slow_timer = 0.12


func is_charmed() -> bool:
	return state == State.CHARMED or state == State.RETURNING


func apply_blessing(amount: float) -> void:
	_blessing = maxf(_blessing, amount)
	_blessing_timer = 0.12


func is_blessed() -> bool:
	return _blessing > 0.0


func effective_purity() -> float:
	return maxf(data.purity, _blessing)


## Purity is a resistance CHANCE. Returns true only if the charm LANDED; the
## caller spends its cooldown either way (see Minion._try_charm).
func try_charm(duration: float, power: float) -> bool:
	if not is_alive() or is_charmed():
		return false

	var chance := data.charm_chance(power, _blessing)
	if randf() > chance:
		_resist_flash = 0.35
		queue_redraw()
		return false

	_charm_timer = duration
	if is_carrying():
		state = State.RETURNING
	else:
		state = State.CHARMED
	queue_redraw()
	return true


func heal(amount: float) -> void:
	if not is_alive() or hp >= data.max_hp:
		return
	var received := amount * (1.0 - rot_heal_cut())
	if received <= 0.0:
		return
	hp = minf(hp + received, data.max_hp)
	_healed_flash = 0.4
	queue_redraw()


func missing_hp() -> float:
	return maxf(0.0, data.max_hp - hp)


func take_damage(amount: float, damage_type: String = "physical") -> void:
	if not is_alive():
		return
	var resist := data.resist_to(damage_type)
	var bonus := _rot_damage_bonus if _rot_timer > 0.0 else 0.0
	hp -= amount * (1.0 - resist) * (1.0 + bonus)
	if hp <= 0.0:
		_die()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)

	if data.purity_aura > 0.0 and is_alive():
		for h in get_tree().get_nodes_in_group("heroes"):
			var other := h as Hero
			if other == null or not other.is_alive():
				continue
			if position.distance_to(other.position) <= data.purity_aura_range:
				other.apply_blessing(data.purity_aura)

	var was_blessed := _blessing > 0.0
	if _blessing_timer > 0.0:
		_blessing_timer -= delta
	else:
		_blessing = 0.0
	if was_blessed != (_blessing > 0.0):
		queue_redraw()

	if _resist_flash > 0.0:
		_resist_flash = maxf(0.0, _resist_flash - delta)
		queue_redraw()
	if _healed_flash > 0.0:
		_healed_flash = maxf(0.0, _healed_flash - delta)
		queue_redraw()
	if _cast_flash > 0.0:
		_cast_flash = maxf(0.0, _cast_flash - delta)
		queue_redraw()

	var was_rotted := is_rotted()
	if _rot_timer > 0.0:
		_rot_timer -= delta
	else:
		_rot_damage_bonus = 0.0
		_rot_heal_cut = 0.0
	if was_rotted != is_rotted():
		queue_redraw()

	if data.heal_amount > 0.0 and is_alive() and not is_charmed():
		_heal_cd = maxf(0.0, _heal_cd - delta)
		if _heal_cd <= 0.0:
			_cast_heal()

	if data.damage > 0.0 and state != State.CHARMED:
		var blocker := _minion_in_range()
		if blocker != null:
			_fight(blocker)
			if _slow_timer > 0.0:
				_slow_timer -= delta
			else:
				_slow_amount = 0.0
			return

	match state:
		State.ADVANCING:
			_move(delta, 1.0)
		State.LOOTING:
			_loot(delta)
		State.FLEEING:
			_move(delta, 1.0)
		State.CHARMED:
			_tick_charm(delta)
		State.RETURNING:
			_tick_charm(delta)
			_move(delta, -1.0)
		_:
			pass

	if _slow_timer > 0.0:
		_slow_timer -= delta
	else:
		_slow_amount = 0.0


func _cast_heal() -> void:
	var best: Hero = null
	var worst := 0.0
	for h in get_tree().get_nodes_in_group("heroes"):
		var other := h as Hero
		if other == null or not other.is_alive():
			continue
		if position.distance_to(other.position) > data.heal_range:
			continue
		var missing := other.missing_hp()
		if missing > worst:
			worst = missing
			best = other
	if best == null:
		return
	best.heal(data.heal_amount)
	_cast_target = best.position - position
	_cast_flash = 0.45
	_heal_cd = data.heal_rate
	queue_redraw()


func _minion_in_range() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for m in get_tree().get_nodes_in_group("minions"):
		var minion := m as Node2D
		if minion == null or not is_instance_valid(minion):
			continue
		var d := position.distance_to(minion.position)
		if d <= data.attack_range and d < best_dist:
			best_dist = d
			best = minion
	return best


func _fight(target: Node2D) -> void:
	if _attack_cd > 0.0:
		return
	target.call("take_damage", data.damage)
	_attack_cd = data.attack_rate


func _tick_charm(delta: float) -> void:
	_charm_timer -= delta
	if _charm_timer > 0.0:
		return
	state = State.FLEEING if is_carrying() else State.ADVANCING
	queue_redraw()


func _move(delta: float, direction: float) -> void:
	var speed := data.speed
	if is_carrying():
		speed *= data.flee_speed_mult
	speed *= (1.0 - _slow_amount)

	_progress += speed * direction * delta
	_progress = clampf(_progress, 0.0, _path_length)
	position = _curve.sample_baked(_progress)

	if _on_escape:
		if _progress >= _path_length:
			_reach_exit()
		elif _progress <= 0.0 and state == State.RETURNING:
			_deposit()
	else:
		if _progress >= _path_length and state == State.ADVANCING:
			_begin_looting()


func _deposit() -> void:
	if carried_gold > 0:
		EconomySystem.recover(carried_gold)
		carried_gold = 0
	state = State.ESCAPED
	EventBus.hero_escaped.emit(self, 0)
	queue_free()


func _begin_looting() -> void:
	state = State.LOOTING
	_loot_timer = LOOT_DURATION
	queue_redraw()


func _loot(delta: float) -> void:
	_loot_timer -= delta
	if _loot_timer > 0.0:
		return
	carried_gold = EconomySystem.steal(data.greed, self)
	## Now it knows the way: switch to the ESCAPE curve (vault at index 0).
	_curve = _escape
	_path_length = _escape_length
	_on_escape = true
	_progress = 0.0
	state = State.FLEEING
	queue_redraw()


func _reach_exit() -> void:
	state = State.ESCAPED
	if carried_gold > 0:
		EconomySystem.confirm_loss(carried_gold)
	EventBus.hero_escaped.emit(self, carried_gold)
	queue_free()


func _die() -> void:
	state = State.DEAD
	EventBus.hero_died.emit(self, carried_gold)
	queue_free()


func _draw() -> void:
	var r := data.radius

	if is_carrying():
		draw_circle(Vector2.ZERO, r + 9.0, Color(1.0, 0.85, 0.2, 0.30))
		draw_circle(Vector2.ZERO, r + 5.0, Color(1.0, 0.9, 0.35, 0.45))

	if data.heal_amount > 0.0:
		draw_circle(Vector2.ZERO, data.heal_range, Color(0.5, 1.0, 0.7, 0.05))
		draw_arc(Vector2.ZERO, data.heal_range, 0.0, TAU, 64, Color(0.5, 1.0, 0.7, 0.28), 1.5)
	if _cast_flash > 0.0 and _cast_target != Vector2.ZERO:
		var ca := _cast_flash / 0.45
		draw_line(Vector2.ZERO, _cast_target, Color(0.5, 1.0, 0.7, ca * 0.9), 3.0)

	if is_rotted():
		draw_arc(Vector2.ZERO, r + 4.0, 0.0, TAU, 22, Color(0.75, 0.1, 0.35, 0.9), 2.5)

	if _healed_flash > 0.0:
		var g := _healed_flash / 0.4
		draw_circle(Vector2.ZERO, r + 7.0 + (1.0 - g) * 6.0, Color(0.45, 1.0, 0.6, g * 0.45))

	if data.purity_aura > 0.0:
		draw_circle(Vector2.ZERO, data.purity_aura_range, Color(1.0, 0.95, 0.6, 0.07))
		draw_arc(Vector2.ZERO, data.purity_aura_range, 0.0, TAU, 64, Color(1.0, 0.95, 0.6, 0.35), 2.0)

	if is_blessed() and data.purity_aura <= 0.0:
		draw_arc(Vector2.ZERO, r + 5.0, 0.0, TAU, 20, Color(1.0, 0.97, 0.75, 0.9), 2.0)

	draw_circle(Vector2.ZERO, r, data.color)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 20, Color(0, 0, 0, 0.45), 1.5)

	if selected:
		draw_arc(Vector2.ZERO, r + 11.0, 0.0, TAU, 28, Color(1, 1, 1, 0.95), 2.5)

	if _resist_flash > 0.0:
		var ra := _resist_flash / 0.35
		draw_arc(Vector2.ZERO, r + 8.0 + (1.0 - ra) * 10.0, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, ra * 0.9), 3.0)

	if is_charmed():
		draw_circle(Vector2.ZERO, r + 6.0, Color(0.9, 0.3, 0.6, 0.35))
		draw_arc(Vector2.ZERO, r + 6.0, 0.0, TAU, 20, Color(1.0, 0.5, 0.75, 0.8), 1.5)

	## Screen-aligned overlays: cancel the world rotation so HP bar reads "up".
	draw_set_transform(Vector2.ZERO, -global_rotation, Vector2.ONE)

	var pct := clampf(hp / data.max_hp, 0.0, 1.0)
	var w := r * 2.2
	var bar := Vector2(-w * 0.5, -r - 9.0)
	draw_rect(Rect2(bar, Vector2(w, 3.0)), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(bar, Vector2(w * pct, 3.0)), Color(0.85, 0.25, 0.25))

	if is_carrying():
		draw_circle(Vector2(0, -r - 17.0), 5.0, Color(1.0, 0.84, 0.2))
		draw_arc(Vector2(0, -r - 17.0), 5.0, 0.0, TAU, 12, Color(0.5, 0.35, 0.0), 1.0)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
