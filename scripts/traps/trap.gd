extends Node2D
class_name Trap

## Traps are static and paid for OUT OF THE HOARD — health, Allure and score you
## choose to spend.

var data: TrapData
var _cd: float = 0.0
var _flash: float = 0.0
var _muzzle: Vector2 = Vector2.ZERO

var targeting: TrapData.Targeting = TrapData.Targeting.FIRST
var selected: bool = false


func setup(trap_data: TrapData) -> void:
	data = trap_data
	targeting = trap_data.targeting


func cycle_targeting() -> void:
	targeting = ((targeting + 1) % TrapData.Targeting.size()) as TrapData.Targeting
	queue_redraw()


static func targeting_name(t: TrapData.Targeting) -> String:
	match t:
		TrapData.Targeting.FIRST:    return "First"
		TrapData.Targeting.LAST:     return "Last"
		TrapData.Targeting.NEAREST:  return "Nearest"
		TrapData.Targeting.TOUGHEST: return "Toughest"
		TrapData.Targeting.HEALER:   return "Healer"
		TrapData.Targeting.CARRIER:  return "Gold Carrier"
	return "?"


func _physics_process(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)
	_flash = maxf(0.0, _flash - delta)
	var heroes := get_tree().get_nodes_in_group("heroes")
	match data.kind:
		TrapData.Kind.SLOW_AURA:
			_tick_slow(heroes)
		TrapData.Kind.AREA_DAMAGE:
			_tick_area(heroes)
		TrapData.Kind.TURRET:
			_tick_turret(heroes)
		TrapData.Kind.WEAKEN_AURA:
			_tick_rot(heroes)
	queue_redraw()


func _tick_rot(heroes: Array) -> void:
	for h in heroes:
		var hero := h as Hero
		if hero == null or not hero.is_alive():
			continue
		if position.distance_to(hero.position) <= data.attack_range:
			hero.apply_rot(data.weaken_damage_bonus, data.weaken_heal_cut)


func _tick_slow(heroes: Array) -> void:
	for h in heroes:
		var hero := h as Hero
		if hero == null or not hero.is_alive():
			continue
		if position.distance_to(hero.position) <= data.attack_range:
			hero.apply_slow(data.slow_amount)


func _tick_area(heroes: Array) -> void:
	if _cd > 0.0:
		return
	var hit := false
	for h in heroes:
		var hero := h as Hero
		if hero == null or not hero.is_alive():
			continue
		if position.distance_to(hero.position) <= data.attack_range:
			hero.take_damage(data.damage, data.damage_type)
			hit = true
	if hit:
		_cd = data.fire_rate
		_flash = 0.12


func _tick_turret(heroes: Array) -> void:
	if _cd > 0.0:
		return
	var best: Hero = null
	var best_score := -INF
	for h in heroes:
		var hero := h as Hero
		if hero == null or not hero.is_alive():
			continue
		if position.distance_to(hero.position) > data.attack_range:
			continue
		var score := _score(hero)
		if score > best_score:
			best_score = score
			best = hero
	if best == null:
		return
	best.take_damage(data.damage, data.damage_type)
	_muzzle = best.position - position
	_cd = data.fire_rate
	_flash = 0.1


func _score(hero: Hero) -> float:
	var dist := position.distance_to(hero.position)
	match targeting:
		TrapData.Targeting.FIRST:
			return hero.path_progress()
		TrapData.Targeting.LAST:
			return -hero.path_progress()
		TrapData.Targeting.NEAREST:
			return -dist
		TrapData.Targeting.TOUGHEST:
			return hero.data.max_hp
		TrapData.Targeting.HEALER:
			return (10000.0 if hero.is_healer() else 0.0) + hero.path_progress()
		TrapData.Targeting.CARRIER:
			return (10000.0 if hero.is_carrying() else 0.0) - dist
	return -dist


func _draw() -> void:
	var c := data.color

	if data.kind != TrapData.Kind.AREA_DAMAGE:
		draw_arc(Vector2.ZERO, data.attack_range, 0.0, TAU, 48, Color(c.r, c.g, c.b, 0.13), 1.0)
	else:
		draw_circle(Vector2.ZERO, data.attack_range, Color(c.r, c.g, c.b, 0.13))

	var flashing := _flash > 0.0
	var body := c.lightened(0.5) if flashing else c

	if data.icon != null:
		## Real art assigned — draw the sprite in place of the glyph.
		var s := 34.0
		draw_texture_rect(data.icon, Rect2(Vector2(-s * 0.5, -s * 0.5), Vector2(s, s)), false)
		if flashing:
			draw_texture_rect(data.icon, Rect2(Vector2(-s * 0.5, -s * 0.5), Vector2(s, s)), false, Color(1, 1, 1, 0.4))
		if data.kind == TrapData.Kind.TURRET and _muzzle != Vector2.ZERO:
			draw_line(Vector2.ZERO, _muzzle.normalized() * 18.0, Color(0.95, 0.9, 0.7), 3.0)
	else:
		match data.kind:
			TrapData.Kind.AREA_DAMAGE:
				draw_rect(Rect2(Vector2(-14, -14), Vector2(28, 28)), body)
				for i in 3:
					var x := -9.0 + i * 9.0
					draw_line(Vector2(x, 8), Vector2(x, -8), Color(0.9, 0.9, 0.95), 2.0)
			TrapData.Kind.TURRET:
				draw_rect(Rect2(Vector2(-13, -13), Vector2(26, 26)), body)
				if _muzzle != Vector2.ZERO:
					draw_line(Vector2.ZERO, _muzzle.normalized() * 18.0, Color(0.95, 0.9, 0.7), 3.0)
				if flashing and _muzzle != Vector2.ZERO:
					draw_line(Vector2.ZERO, _muzzle, Color(1, 1, 0.8, 0.5), 1.0)
			TrapData.Kind.SLOW_AURA:
				draw_circle(Vector2.ZERO, 13.0, body)
				draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 20, Color(1, 1, 1, 0.8), 2.0)
			TrapData.Kind.WEAKEN_AURA:
				draw_circle(Vector2.ZERO, 13.0, body)
				draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 20, Color(0.2, 0, 0.1, 0.9), 2.0)
				draw_line(Vector2(-6, -6), Vector2(6, 6), Color(0.15, 0, 0.08), 2.0)
				draw_line(Vector2(6, -6), Vector2(-6, 6), Color(0.15, 0, 0.08), 2.0)

		draw_rect(Rect2(Vector2(-14, -14), Vector2(28, 28)), Color(0, 0, 0, 0.35), false, 1.5)

	if selected:
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 28, Color(1, 1, 1, 0.95), 2.5)

	if selected and data.kind == TrapData.Kind.TURRET:
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(-30, -26), targeting_name(targeting), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.95))
