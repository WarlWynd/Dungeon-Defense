extends RefCounted

## The one source of truth for how a character is drawn as a shape. Referenced by
## consumers via `preload()` (const UnitGlyphs := preload(...)) rather than a
## global class_name, so a fresh headless run resolves it without an editor pass
## to rebuild the global class cache.
## The Bestiary,
## the board heroes, and the board minions all call these, so a unit looks the
## same in the book and on the field.
##
## Every glyph draws on any CanvasItem `ci`, centred at `ctr`, scaled by `s`
## (s = 1.0 reproduces the Bestiary's ~34px icon; the board passes s = radius/8
## to fit a unit). `col` is the unit's colour; the eyes/visor darks are derived.
##
## Coordinates are copied verbatim from the original Bestiary glyphs and just
## multiplied by `s`, so the book is pixel-identical to before.


## Two striding legs under the body, driven by `stride` (-1..1). One foot swings
## forward while the other swings back, and the forward foot lifts a little — the
## motion that reads as actually WALKING rather than sliding. Draw this BEFORE the
## body so the torso overlaps the hips. Only the board units call it; the Bestiary
## draws legless icons.
static func legs(ci: CanvasItem, ctr: Vector2, s: float, stride: float, col: Color) -> void:
	var leg := col.darkened(0.4)
	var w := maxf(2.2 * s, 1.6)
	var hip_y := ctr.y + 4.0 * s
	var foot_y := ctr.y + 10.5 * s
	var spread := 2.8 * s
	var swing := 3.4 * s * stride
	var lift := 2.2 * s
	var l_foot := Vector2(ctr.x - spread + swing, foot_y - maxf(0.0, stride) * lift)
	var r_foot := Vector2(ctr.x + spread - swing, foot_y - maxf(0.0, -stride) * lift)
	ci.draw_line(Vector2(ctr.x - spread, hip_y), l_foot, leg, w)
	ci.draw_line(Vector2(ctr.x + spread, hip_y), r_foot, leg, w)
	## Little feet so the ends read as steps, not stumps.
	ci.draw_line(l_foot, l_foot + Vector2(2.4 * s, 0.0), leg, w)
	ci.draw_line(r_foot, r_foot + Vector2(2.4 * s, 0.0), leg, w)


static func draw(ci: CanvasItem, ctr: Vector2, s: float, kind: String, id: String, col: Color) -> void:
	if kind == "minion":
		match id:
			"goblin_pack": goblin(ci, ctr, s, col)
			"troll": troll(ci, ctr, s, col)
			"ogre": ogre(ci, ctr, s, col)
			"succubus": succubus(ci, ctr, s, col)
			"wraith": wraith(ci, ctr, s, col)
			_: ci.draw_circle(ctr, 8.0 * s, col)
	else:
		hero(ci, ctr, s, col)


## A closed helm — every raider is "a hero in armour", told apart by colour.
static func hero(ci: CanvasItem, ctr: Vector2, s: float, c: Color) -> void:
	var dark := Color(0.08, 0.08, 0.10, c.a)
	ci.draw_colored_polygon(PackedVector2Array([
		ctr + Vector2(-6.0, -2.0) * s, ctr + Vector2(-4.5, -7.5) * s, ctr + Vector2(4.5, -7.5) * s,
		ctr + Vector2(6.0, -2.0) * s, ctr + Vector2(6.0, 5.0) * s, ctr + Vector2(3.0, 8.0) * s,
		ctr + Vector2(-3.0, 8.0) * s, ctr + Vector2(-6.0, 5.0) * s,
	]), c)
	ci.draw_rect(Rect2(ctr + Vector2(-6.0, -1.6) * s, Vector2(12.0, 2.8) * s), dark)
	ci.draw_rect(Rect2(ctr + Vector2(-0.9, 1.2) * s, Vector2(1.8, 5.0) * s), dark)


static func goblin(ci: CanvasItem, ctr: Vector2, s: float, c: Color) -> void:
	var dark := Color(0.07, 0.12, 0.07, c.a)
	for e: float in [-1.0, 1.0]:
		ci.draw_colored_polygon(PackedVector2Array([
			ctr + Vector2(4.0 * e, -2.5) * s, ctr + Vector2(10.5 * e, -5.5) * s, ctr + Vector2(4.5 * e, 1.5) * s,
		]), c)
	ci.draw_colored_polygon(PackedVector2Array([
		ctr + Vector2(-5.5, -5.5) * s, ctr + Vector2(5.5, -5.5) * s,
		ctr + Vector2(3.5, 4.5) * s, ctr + Vector2(0.0, 7.5) * s, ctr + Vector2(-3.5, 4.5) * s,
	]), c)
	ci.draw_circle(ctr + Vector2(-2.4, -1.8) * s, 1.5 * s, dark)
	ci.draw_circle(ctr + Vector2(2.4, -1.8) * s, 1.5 * s, dark)


## Hunched brute — heavy shoulders, a head sunk between them, tusks pointing up.
## Reads WIDE where the goblin reads spiky, so the two never blur together at
## board size.
static func troll(ci: CanvasItem, ctr: Vector2, s: float, c: Color) -> void:
	var dark := Color(0.06, 0.10, 0.06, c.a)
	ci.draw_colored_polygon(PackedVector2Array([
		ctr + Vector2(-9.0, -1.5) * s, ctr + Vector2(-6.5, -6.0) * s, ctr + Vector2(6.5, -6.0) * s,
		ctr + Vector2(9.0, -1.5) * s, ctr + Vector2(7.0, 7.5) * s, ctr + Vector2(-7.0, 7.5) * s,
	]), c)
	ci.draw_circle(ctr + Vector2(0.0, -4.5) * s, 4.4 * s, c.lightened(0.12))
	## Tusks last but one, so they sit in front of the jaw.
	for e: float in [-1.0, 1.0]:
		ci.draw_colored_polygon(PackedVector2Array([
			ctr + Vector2(2.4 * e, -2.4) * s, ctr + Vector2(3.9 * e, -7.6) * s,
			ctr + Vector2(4.4 * e, -2.2) * s,
		]), Color(0.92, 0.90, 0.78, c.a))
	ci.draw_circle(ctr + Vector2(-1.8, -5.6) * s, 1.2 * s, dark)
	ci.draw_circle(ctr + Vector2(1.8, -5.6) * s, 1.2 * s, dark)


## The biggest silhouette on the board, and a CYCLOPS — one eye under a heavy
## brow. The single eye is the tell: an Ogre can't be mistaken for a Troll even
## at a glance, which is the whole job of these shapes.
static func ogre(ci: CanvasItem, ctr: Vector2, s: float, c: Color) -> void:
	var dark := Color(0.10, 0.07, 0.05, c.a)
	ci.draw_colored_polygon(PackedVector2Array([
		ctr + Vector2(-10.0, 0.0) * s, ctr + Vector2(-7.5, -7.5) * s, ctr + Vector2(7.5, -7.5) * s,
		ctr + Vector2(10.0, 0.0) * s, ctr + Vector2(8.0, 8.5) * s, ctr + Vector2(-8.0, 8.5) * s,
	]), c)
	ci.draw_rect(Rect2(ctr + Vector2(-6.5, -5.6) * s, Vector2(13.0, 2.0) * s), dark)
	ci.draw_circle(ctr + Vector2(0.0, -1.4) * s, 2.8 * s, Color(0.96, 0.93, 0.80, c.a))
	ci.draw_circle(ctr + Vector2(0.0, -1.4) * s, 1.3 * s, dark)
	## Lower teeth, jutting up from the jaw.
	for e: float in [-1.0, 1.0]:
		ci.draw_colored_polygon(PackedVector2Array([
			ctr + Vector2(2.0 * e, 6.4) * s, ctr + Vector2(4.4 * e, 6.4) * s,
			ctr + Vector2(3.2 * e, 2.8) * s,
		]), Color(0.92, 0.90, 0.78, c.a))


static func succubus(ci: CanvasItem, ctr: Vector2, s: float, c: Color) -> void:
	var dark := Color(0.12, 0.04, 0.08, c.a)
	for e: float in [-1.0, 1.0]:
		ci.draw_colored_polygon(PackedVector2Array([
			ctr + Vector2(3.0 * e, -1.0) * s, ctr + Vector2(12.0 * e, -6.0) * s,
			ctr + Vector2(11.0 * e, 3.0) * s, ctr + Vector2(4.0 * e, 4.0) * s,
		]), Color(c, c.a * 0.55))
	for e: float in [-1.0, 1.0]:
		ci.draw_colored_polygon(PackedVector2Array([
			ctr + Vector2(3.0 * e, -5.5) * s, ctr + Vector2(6.5 * e, -11.0) * s, ctr + Vector2(5.0 * e, -4.5) * s,
		]), c)
	ci.draw_circle(ctr + Vector2(0.0, -1.0) * s, 5.4 * s, c)
	ci.draw_circle(ctr + Vector2(-2.0, -1.6) * s, 1.3 * s, dark)
	ci.draw_circle(ctr + Vector2(2.0, -1.6) * s, 1.3 * s, dark)


static func wraith(ci: CanvasItem, ctr: Vector2, s: float, c: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([
		ctr + Vector2(0.0, -10.0) * s, ctr + Vector2(6.5, -3.0) * s, ctr + Vector2(8.5, 8.0) * s,
		ctr + Vector2(3.0, 5.5) * s, ctr + Vector2(0.0, 9.0) * s, ctr + Vector2(-3.0, 5.5) * s,
		ctr + Vector2(-8.5, 8.0) * s, ctr + Vector2(-6.5, -3.0) * s,
	]), c)
	ci.draw_colored_polygon(PackedVector2Array([
		ctr + Vector2(0.0, -6.0) * s, ctr + Vector2(4.0, -1.0) * s,
		ctr + Vector2(0.0, 3.5) * s, ctr + Vector2(-4.0, -1.0) * s,
	]), Color(0.05, 0.03, 0.08, c.a))
	ci.draw_circle(ctr + Vector2(-1.7, -1.5) * s, 1.1 * s, Color(0.95, 0.90, 1.0, c.a))
	ci.draw_circle(ctr + Vector2(1.7, -1.5) * s, 1.1 * s, Color(0.95, 0.90, 1.0, c.a))
