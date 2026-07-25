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

## Splash damage as a fraction of the direct hit.
const SPLASH_FALLOFF := 0.6

## How long a fired bolt is shown flying to its target. Also the turret's muzzle
## flash duration, so the bolt travels for exactly as long as it's visible.
const BOLT_TIME := 0.22

## The Dart's needle swivels to track its target at this rate (rad/sec). Its
## resting angle (no target, and the trap-tray icon) points up-and-right.
const AIM_SPEED := 9.0
const DART_REST_ANGLE := -PI / 4.0

var _aim_angle: float = DART_REST_ANGLE

## Selling a trap refunds this fraction of what it cost (rounded). One source of
## truth so the Sell button's label and the actual refund can't disagree.
const SELL_REFUND := 0.6


static func sell_value(d: TrapData) -> int:
	return int(round(float(d.cost) * SELL_REFUND))


func setup(trap_data: TrapData) -> void:
	data = trap_data
	targeting = trap_data.targeting


func cycle_targeting() -> void:
	## Simple traps (e.g. the Dart Launcher) can't be re-targeted.
	if data.fixed_targeting:
		return
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
			_aim_at_target(heroes, delta)
		TrapData.Kind.WEAKEN_AURA:
			_tick_rot(heroes)
	queue_redraw()


## Swivel the aim toward the current target each frame (before firing), so the
## Dart's needle visibly tracks whoever it's about to shoot. No target -> hold the
## last angle.
func _aim_at_target(heroes: Array, delta: float) -> void:
	var tgt := _current_target(heroes)
	if tgt == null:
		return
	var desired := (tgt.position - position).angle()
	var diff := wrapf(desired - _aim_angle, -PI, PI)
	_aim_angle += clampf(diff, -AIM_SPEED * delta, AIM_SPEED * delta)


## Best in-range hero by this turret's targeting priority, or null.
func _current_target(heroes: Array) -> Hero:
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
	return best


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
	var best := _current_target(heroes)
	if best == null:
		return
	best.take_damage(data.damage, data.damage_type)
	## Explosive shells catch the pack around the target, at reduced strength —
	## that falloff is what stops a mortar from simply outclassing the crossbow.
	if data.splash_radius > 0.0:
		for h in heroes:
			var other := h as Hero
			if other == null or other == best or not other.is_alive():
				continue
			if best.position.distance_to(other.position) <= data.splash_radius:
				other.take_damage(data.damage * SPLASH_FALLOFF, data.damage_type)
	_muzzle = best.position - position
	_cd = data.fire_rate
	_flash = BOLT_TIME


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
		if data.glyph == "dart":
			## The Dart's art AIMS: rotate it to the live aim angle (in world/design
			## space, so it points at the target and turns with the board).
			var s := 34.0
			var rect := Rect2(Vector2(-s * 0.5, -s * 0.5), Vector2(s, s))
			draw_set_transform(Vector2.ZERO, _aim_angle, Vector2.ONE)
			draw_texture_rect(data.icon, rect, false)
			if flashing:
				draw_texture_rect(data.icon, rect, false, Color(1, 1, 1, 0.4))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			## Other art (Crossbow) reads SCREEN-UPRIGHT (cancel the board rotation) so
			## it matches the tray, drawn through a rounded-rect polygon for soft corners.
			draw_set_transform(Vector2.ZERO, -global_rotation, Vector2.ONE)
			var half := 17.0
			var pts := _rounded_rect_points(half, 7.0)
			var uvs := PackedVector2Array()
			for p in pts:
				uvs.append((p + Vector2(half, half)) / (half * 2.0))
			draw_colored_polygon(pts, Color.WHITE, uvs, data.icon)
			if flashing:
				draw_colored_polygon(pts, Color(1, 1, 1, 0.4), uvs, data.icon)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if data.kind == TrapData.Kind.TURRET and flashing:
			_draw_bolt(1.0 - _flash / BOLT_TIME)
	else:
		## The Dart swivels to aim; other glyph traps draw flat.
		if data.glyph == "dart":
			_dart_shape(self, Vector2.ZERO, body, _aim_angle)
		else:
			draw_glyph(self, Vector2.ZERO, data, body)
		if data.kind == TrapData.Kind.TURRET and flashing:
			_draw_bolt(1.0 - _flash / BOLT_TIME)

	## Show the blast the shell just made, so AoE is visible rather than implied.
	if data.splash_radius > 0.0 and flashing and _muzzle != Vector2.ZERO:
		draw_arc(_muzzle, data.splash_radius, 0.0, TAU, 32, Color(1.0, 0.62, 0.22, 0.8), 2.0)
		draw_circle(_muzzle, data.splash_radius, Color(1.0, 0.62, 0.22, 0.16))

	if selected:
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 28, Color(1, 1, 1, 0.95), 2.5)

	if selected and data.kind == TrapData.Kind.TURRET:
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(-30, -26), targeting_name(targeting), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.95))


# --- Placeholder art -------------------------------------------------------
#
# Drawn once here and used by BOTH the board and the trap tray, so a trap can
# never look like one thing in your hand and another on the floor. Real art in
# TrapData.icon overrides all of this.

## A fired arrow flying from the turret toward its target. `t` (0..1) is how far
## along the shot it is, so the bolt travels out over the flash. Drawn in local
## (world-aligned) space so it points at the target and rotates with the board.
func _draw_bolt(t: float) -> void:
	if _muzzle == Vector2.ZERO:
		return
	var dir := _muzzle.normalized()
	var perp := Vector2(-dir.y, dir.x)
	var tip := _muzzle * clampf(t, 0.0, 1.0)
	var tail := tip - dir * 13.0
	var shaft := Color(0.86, 0.78, 0.52)
	var head := Color(0.97, 0.97, 1.0)
	draw_line(tail, tip, shaft, 2.0)                                     # shaft
	draw_line(tip, tip - dir * 5.0 + perp * 3.5, head, 2.0)             # arrowhead
	draw_line(tip, tip - dir * 5.0 - perp * 3.5, head, 2.0)
	draw_line(tail, tail + dir * 3.0 + perp * 2.5, shaft, 1.5)          # fletching
	draw_line(tail, tail + dir * 3.0 - perp * 2.5, shaft, 1.5)


## Perimeter of a rounded square centred at the origin, spanning [-half, half],
## with quarter-circle corners of radius `r`. Used to draw the trap art clipped to
## rounded corners (draw_colored_polygon with matching UVs).
func _rounded_rect_points(half: float, r: float, seg: int = 4) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [
		Vector2(half - r, half - r),    # bottom-right, 0..90
		Vector2(-half + r, half - r),   # bottom-left, 90..180
		Vector2(-half + r, -half + r),  # top-left, 180..270
		Vector2(half - r, -half + r),   # top-right, 270..360
	]
	var starts := [0.0, PI * 0.5, PI, PI * 1.5]
	for ci in 4:
		var center: Vector2 = corners[ci]
		var a0: float = starts[ci]
		for si in seg + 1:
			var a := a0 + (PI * 0.5) * float(si) / float(seg)
			pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


static func draw_glyph(ci: CanvasItem, ctr: Vector2, d: TrapData, body: Color) -> void:
	var g := d.glyph
	if g == "":
		match d.kind:
			TrapData.Kind.TURRET: g = "crossbow"
			TrapData.Kind.SLOW_AURA: g = "aura_slow"
			TrapData.Kind.WEAKEN_AURA: g = "aura_weaken"
			_: g = "area"
	match g:
		"dart": _g_dart(ci, ctr, body)
		"arcane": _g_arcane(ci, ctr, body)
		"mortar": _g_mortar(ci, ctr, body)
		"fungus": _g_fungus(ci, ctr, body)
		"aura_slow": _g_aura_slow(ci, ctr, body)
		"aura_weaken": _g_aura_weaken(ci, ctr, body)
		"area": _g_area(ci, ctr, body)
		_: _g_crossbow(ci, ctr, body)


static func _outline(ci: CanvasItem, c: Vector2) -> void:
	ci.draw_rect(Rect2(c + Vector2(-14, -14), Vector2(28, 28)), Color(0, 0, 0, 0.35), false, 1.5)


## Cheap, fast, single target — a needle on a swivel mount. In the tray it rests
## at DART_REST_ANGLE; on the board it's drawn at the live aim angle.
static func _g_dart(ci: CanvasItem, c: Vector2, col: Color) -> void:
	_dart_shape(ci, c, col, DART_REST_ANGLE)


## A fixed mount (rotation-invariant ring) with a needle pointing along `ang`.
static func _dart_shape(ci: CanvasItem, ctr: Vector2, col: Color, ang: float) -> void:
	var dark := col.darkened(0.45)
	ci.draw_circle(ctr, 7.5, dark)          # mount base
	ci.draw_circle(ctr, 5.2, col)
	var dir := Vector2.RIGHT.rotated(ang)
	var perp := Vector2(-dir.y, dir.x)
	var pale := Color(0.96, 0.94, 0.82)
	var tip := ctr + dir * 13.0
	ci.draw_line(ctr + dir * 2.0, tip, pale, 2.6)                    # needle
	ci.draw_line(tip, tip - dir * 4.5 + perp * 3.0, pale, 2.2)       # barb
	ci.draw_line(tip, tip - dir * 4.5 - perp * 3.0, pale, 2.2)


static func _g_crossbow(ci: CanvasItem, c: Vector2, col: Color) -> void:
	ci.draw_rect(Rect2(c + Vector2(-13, -13), Vector2(26, 26)), col)
	ci.draw_line(c, c + Vector2(15, -9), Color(0.95, 0.9, 0.7), 3.0)
	_outline(ci, c)


## Magic — a floating orb on a stand. Deliberately round so it reads as "not a
## crossbow" instantly, since its whole point is being the non-physical option.
static func _g_arcane(ci: CanvasItem, c: Vector2, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-9, 13), c + Vector2(9, 13), c + Vector2(5, 5), c + Vector2(-5, 5),
	]), col.darkened(0.45))
	ci.draw_circle(c + Vector2(0, -3), 9.0, col)
	ci.draw_circle(c + Vector2(0, -3), 4.2, Color(0.96, 0.96, 1.0, 0.92))
	ci.draw_arc(c + Vector2(0, -3), 12.5, 0.0, TAU, 26, Color(1, 1, 1, 0.5), 1.4)


## Explosive — squat barrel angled up with a lit shell over the mouth.
static func _g_mortar(ci: CanvasItem, c: Vector2, col: Color) -> void:
	ci.draw_rect(Rect2(c + Vector2(-12, 7), Vector2(24, 6)), col.darkened(0.45))
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-7, 8), c + Vector2(0, -8), c + Vector2(9, -3), c + Vector2(4, 9),
	]), col)
	ci.draw_circle(c + Vector2(4, -10), 4.2, Color(0.24, 0.21, 0.20))
	ci.draw_circle(c + Vector2(4, -10), 1.7, Color(1.0, 0.76, 0.30))
	_outline(ci, c)


static func _g_area(ci: CanvasItem, c: Vector2, col: Color) -> void:
	ci.draw_rect(Rect2(c + Vector2(-14, -14), Vector2(28, 28)), col)
	for i in 3:
		var x := c.x - 9.0 + i * 9.0
		ci.draw_line(Vector2(x, c.y + 8), Vector2(x, c.y - 8), Color(0.9, 0.9, 0.95), 2.0)
	_outline(ci, c)


## Poison — a cap on a stalk with spores drifting off it.
static func _g_fungus(ci: CanvasItem, c: Vector2, col: Color) -> void:
	ci.draw_rect(Rect2(c + Vector2(-2.5, -1.0), Vector2(5.0, 12.0)), col.darkened(0.45))
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-12, 0), c + Vector2(-7, -9), c + Vector2(7, -9), c + Vector2(12, 0),
	]), col)
	ci.draw_circle(c + Vector2(-4.5, -3.5), 1.7, Color(0.10, 0.20, 0.09))
	ci.draw_circle(c + Vector2(3.5, -4.5), 1.3, Color(0.10, 0.20, 0.09))
	ci.draw_circle(c + Vector2(-8.0, -12.5), 1.5, Color(col, 0.7))
	ci.draw_circle(c + Vector2(6.5, -13.0), 1.2, Color(col, 0.55))
	_outline(ci, c)


static func _g_aura_slow(ci: CanvasItem, c: Vector2, col: Color) -> void:
	ci.draw_circle(c, 13.0, col)
	ci.draw_arc(c, 13.0, 0.0, TAU, 20, Color(1, 1, 1, 0.8), 2.0)
	ci.draw_line(c + Vector2(-7, 0), c + Vector2(7, 0), Color(1, 1, 1, 0.7), 1.5)
	ci.draw_line(c + Vector2(0, -7), c + Vector2(0, 7), Color(1, 1, 1, 0.7), 1.5)


static func _g_aura_weaken(ci: CanvasItem, c: Vector2, col: Color) -> void:
	ci.draw_circle(c, 13.0, col)
	ci.draw_arc(c, 13.0, 0.0, TAU, 20, Color(0.2, 0, 0.1, 0.9), 2.0)
	ci.draw_line(c + Vector2(-6, -6), c + Vector2(6, 6), Color(0.15, 0, 0.08), 2.0)
	ci.draw_line(c + Vector2(6, -6), c + Vector2(-6, 6), Color(0.15, 0, 0.08), 2.0)
