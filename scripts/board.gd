extends Node2D
class_name Board

## Draws the dungeon: stone, path/maze, vault, entrance, build nodes. Lives
## under the World node so it inherits the fit-and-rotate transform.

## Optional build-slot art. Drop a texture here and it replaces the placeholder
## square below with no other code changes.
const SLOT_TEX_PATH := "res://assets/textures/build_slot.png"
const STONE_SCRIM := Color(0, 0, 0, 0.18)

## The board background is pushed toward a lighter blue (blended over whatever the
## active scheme's stone colour is) so the blue Gem glyph in the roster — which
## sits directly over the board with no panel behind it — reads clearly. Raise
## BG_BLUE_MIX toward 1.0 for more blue, lower it to let the scheme show through.
const BG_BLUE := Color(0.52, 0.66, 0.86)
const BG_BLUE_MIX := 0.7

## The dungeon is a CARD sitting on the backdrop, not a full-bleed rectangle:
## rounded corners and a thin outline, matching the panels in the HUD. The border
## follows the palette accent — the Inspector's own outline is the colour of the
## unit it's describing, so there's no single "info window colour" to copy, and
## the accent is what every other panel in the UI is bordered with.
const BOARD_SIZE := Vector2(720, 1280)
const BOARD_CORNER := 34.0
const BOARD_BORDER_W := 2.0
const BOARD_BORDER_ALPHA := 0.75

var curve: Curve2D
var maze: Maze = null              ## set on maze boards; null otherwise
var build_nodes: Array = []
var show_nodes: bool = false
var hover: int = -1

var _stone: Texture2D
var _slot_tex: Texture2D
var _vault_tex: Texture2D


func _ready() -> void:
	## A runtime-resized texture carries no import flags, so repeat has to be asked
	## for here or the shrunken stone would draw once and leave the rest bare.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_stone = GameData.stone_tile()
	_vault_tex = _load_vault_tex()
	if ResourceLoader.exists(SLOT_TEX_PATH):
		_slot_tex = load(SLOT_TEX_PATH) as Texture2D


## The loot-chamber art, cropped to the room and baked down to the size it is
## actually drawn at. Returns null when there is no art to load, which is the
## signal to fall back to the hand-drawn chest.
func _load_vault_tex() -> Texture2D:
	var src := GameData.load_texture(VAULT_TEX_PATH)
	if src == null:
		return null
	var img := src.get_image()
	if img == null:
		return src
	img.decompress()   ## imported textures can come back VRAM-compressed
	if not Rect2i(Vector2i.ZERO, img.get_size()).encloses(VAULT_TEX_REGION):
		return src     ## art was redrawn at another size — better whole than cropped wrong
	var room := img.get_region(VAULT_TEX_REGION)
	room.resize(int(VAULT_TEX_SIZE.x * VAULT_TEX_OVERSAMPLE),
			int(VAULT_TEX_SIZE.y * VAULT_TEX_OVERSAMPLE), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(room)


func _draw() -> void:
	if curve == null and maze == null:
		return

	_draw_stone()
	if maze != null:
		_draw_maze()
	else:
		_draw_path()
	_draw_vault()

	draw_circle(GameData.entrance_pos(), 16.0, Settings.scheme().entrance)
	_draw_build_nodes()


func _draw_maze() -> void:
	var s: ColorScheme = Settings.scheme()
	var edge_col := s.floor_edge
	var floor_col := s.floor_col
	var worn_col := s.floor_worn
	for e in maze.get_edges():
		_draw_tunnel(maze.junctions[e[0]], maze.junctions[e[1]], 52.0, edge_col)
	for e in maze.get_edges():
		_draw_tunnel(maze.junctions[e[0]], maze.junctions[e[1]], 44.0, floor_col)
	for e in maze.get_edges():
		_draw_tunnel(maze.junctions[e[0]], maze.junctions[e[1]], 30.0, worn_col)
	for i in maze.junctions.size():
		draw_circle(maze.junctions[i], 22.0, floor_col)
	for i in maze.dead_ends():
		draw_circle(maze.junctions[i], 15.0, floor_col.darkened(0.18))


func _draw_tunnel(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	draw_line(a, b, col, w)
	draw_circle(a, w * 0.5, col)
	draw_circle(b, w * 0.5, col)


func _draw_stone() -> void:
	var s: ColorScheme = Settings.scheme()
	var board := Rect2(Vector2.ZERO, BOARD_SIZE)
	var shape := _rounded_rect(board, BOARD_CORNER)
	## Lighter-blue background so the blue Gem glyph stands out over the board.
	var bg := s.stone.lerp(BG_BLUE, BG_BLUE_MIX)

	if _stone == null:
		draw_colored_polygon(shape, s.stone_dark.lerp(BG_BLUE, BG_BLUE_MIX))
	else:
		## Tiled through a POLYGON rather than draw_texture_rect, because that
		## can only fill a square rectangle — the UVs repeat the sheet at exactly
		## its own size, which is what tile=true was doing before.
		var tile := Vector2(float(_stone.get_width()), float(_stone.get_height()))
		var uvs := PackedVector2Array()
		for p in shape:
			uvs.append(p / tile)
		draw_colored_polygon(shape, bg, uvs, _stone)
		draw_colored_polygon(shape, STONE_SCRIM)
		## Vignette: concentric rounded outlines, corner radius shrinking with the
		## inset so they stay parallel to the edge instead of cutting the corners.
		for i in 5:
			var inset := float(i) * 9.0
			var a := 0.05 * (5.0 - float(i)) / 5.0
			_stroke_rounded(board.grow(-inset), maxf(BOARD_CORNER - inset, 4.0),
					Color(0, 0, 0, a), 18.0)

	## The outline, inset by half its width so it sits fully on the board.
	_stroke_rounded(board.grow(-BOARD_BORDER_W * 0.5), BOARD_CORNER - BOARD_BORDER_W * 0.5,
			Color(s.accent, BOARD_BORDER_ALPHA), BOARD_BORDER_W)


## Closed rounded-rectangle outline.
func _stroke_rounded(rect: Rect2, radius: float, col: Color, width: float) -> void:
	var pts := _rounded_rect(rect, radius)
	pts.append(pts[0])
	draw_polyline(pts, col, width)


## Perimeter of `rect` with quarter-circle corners of `radius`, clockwise from the
## top-left. Enough segments per corner that the curve reads as smooth at the
## scale the board is drawn.
func _rounded_rect(rect: Rect2, radius: float, seg: int = 8) -> PackedVector2Array:
	var r: float = clampf(radius, 0.0, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var centers := [
		rect.position + Vector2(r, r),                                   # top-left
		rect.position + Vector2(rect.size.x - r, r),                     # top-right
		rect.position + Vector2(rect.size.x - r, rect.size.y - r),       # bottom-right
		rect.position + Vector2(r, rect.size.y - r),                     # bottom-left
	]
	var starts := [PI, PI * 1.5, 0.0, PI * 0.5]
	for ci in 4:
		var center: Vector2 = centers[ci]
		var a0: float = starts[ci]
		for si in seg + 1:
			var a: float = a0 + (PI * 0.5) * float(si) / float(seg)
			pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


func _draw_path() -> void:
	var pts := curve.get_baked_points()
	if pts.size() < 2:
		return
	var s: ColorScheme = Settings.scheme()
	_draw_river(pts, 52.0, s.floor_edge)
	_draw_river(pts, 44.0, s.floor_col)
	_draw_river(pts, 30.0, s.floor_worn)


func _draw_river(pts: PackedVector2Array, width: float, col: Color) -> void:
	draw_polyline(pts, col, width)
	var r := width * 0.5
	var i := 0
	while i < pts.size():
		draw_circle(pts[i], r, col)
		i += 3
	draw_circle(pts[0], r, col)
	draw_circle(pts[pts.size() - 1], r, col)


## The vault is the LOOT CHAMBER: a whole treasure room, drawn from art rather
## than from primitives. The hand-drawn chest below is what shows when the texture
## is missing — the same bargain build_slot.png makes.
##
## Either way it is drawn SCREEN-UPRIGHT, cancelling the board's fit-and-rotate
## the way the coin stacks always did on their own. A treasure room lying on its
## side reads as nothing at all.
const VAULT_TEX_PATH := "res://assets/textures/LootChamber.png"
## The room inside the source image. The PNG is padded with black on all four
## sides and carries the generator's "AI-Generated" badge in the top-right corner;
## both would draw as a black square with a label on it, so the region crops to
## the masonry and nothing else. Measured off the art — retake it if the art is
## ever redrawn.
const VAULT_TEX_REGION := Rect2i(91, 102, 841, 817)
## Footprint on the board. Bigger than the chest it replaces, because it is a
## whole chamber now, and squarer, because the art is.
const VAULT_TEX_SIZE := Vector2(200, 194)
## The art is scaled to twice its drawn size and no further. Pixel art taken from
## 841px to 200px by the sampler every frame shimmers as the board moves; baking
## the shrink once kills that, and the spare 2x keeps the masonry crisp.
const VAULT_TEX_OVERSAMPLE := 2.0
## How dark the room goes as the hoard leaves. The art's coin piles are painted
## in and can't be carried away the way the drawn stacks are, so the light going
## out of the room is what shows the vault emptying instead.
const VAULT_DARK_EMPTY := 0.50

const GOLD := Color(1.0, 0.82, 0.22)
## Layers in the vault's glow. More is smoother and costs one polygon each.
const GLOW_RINGS := 5

## Fallback chest, and the coin stacks inside it.
const VAULT_SIZE := Vector2(170, 124)
const VAULT_COLS := 4
const VAULT_ROWS := 3

## Timber is its OWN colour rather than the palette's: a chest that turned green
## in Crypt Moss stops reading as wood, and the gold needs a warm, dull surround
## to stay the brightest thing on that part of the board. The IRONWORK is
## s.vault_trim, so the chest still answers to the scheme where it can afford to.
const CHEST_WOOD := Color(0.35, 0.21, 0.12)
const CHEST_WOOD_DARK := Color(0.22, 0.13, 0.07)
const CHEST_INSIDE := Color(0.07, 0.05, 0.03)

## Chest landmarks, in chest-local pixels measured from its centre. RIM is where
## the lid meets the body — the mouth the gold stands in, and the line the front
## wall crops the stacks at.
const CHEST_LID_TOP := -62.0
const CHEST_RIM := -8.0
const CHEST_BOTTOM := 56.0


func _draw_vault() -> void:
	var s: ColorScheme = Settings.scheme()
	var frac := EconomySystem.hoard_fraction()

	## ONE transform for the whole vault, so the room, its glow and the fallback
	## chest's ironwork can't drift apart from each other when the board rotates.
	draw_set_transform(GameData.vault_pos(), -global_rotation, Vector2.ONE)
	if _vault_tex != null:
		_draw_loot_chamber(s, frac)
	else:
		_draw_chest(s, frac)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_loot_chamber(s: ColorScheme, frac: float) -> void:
	_draw_vault_glow(s, frac, Vector2.ZERO, VAULT_TEX_SIZE * (0.58 + 0.15 * frac))
	var lit := lerpf(VAULT_DARK_EMPTY, 1.0, frac)
	draw_texture_rect(_vault_tex, Rect2(-VAULT_TEX_SIZE * 0.5, VAULT_TEX_SIZE), false,
			Color(lit, lit, lit, 1.0))


## The glow of a full vault, dying as the pile is carried out the door. Pulled
## halfway to coin-gold rather than left as the raw accent — it is the HOARD that
## lights the room, and a grey scheme's accent just smudges the wall.
##
## Nested ellipses rather than one: draw_colored_polygon has no gradient, and a
## single flat oval reads as a smudge with a hard edge around it. Stacking the
## alpha fakes the falloff — faint at the rim, brightest against the masonry.
func _draw_vault_glow(s: ColorScheme, frac: float, c: Vector2, r: Vector2) -> void:
	if frac <= 0.0:
		return
	var wash := s.accent.lerp(GOLD, 0.5)
	wash.a = 0.05 * frac
	for i in GLOW_RINGS:
		var t := float(i) / float(GLOW_RINGS - 1)     ## 0 outermost, 1 innermost
		draw_colored_polygon(_ellipse(c, r * lerpf(1.0, 0.4, t)), wash)


## The drawn chest: lid thrown open, gold piled in the mouth, stacks vanishing one
## at a time as gold walks out the door. Only reached when the art is missing.
func _draw_chest(s: ColorScheme, frac: float) -> void:
	var iron: Color = s.vault_trim
	var hw := VAULT_SIZE.x * 0.5

	_draw_vault_glow(s, frac, Vector2(0.0, CHEST_RIM),
			Vector2(hw * (1.05 + 0.25 * frac), VAULT_SIZE.y * (0.5 + 0.15 * frac)))
	_draw_chest_lid(iron, hw)

	## The dark inside, then the gold standing in it — both BEFORE the front wall,
	## which is what makes the pile look like it is down in the chest rather than
	## balanced on top of it.
	draw_colored_polygon(_ellipse(Vector2(0.0, CHEST_RIM), Vector2(hw * 0.94, 15.0)), CHEST_INSIDE)
	_draw_hoard(frac, hw)
	_draw_chest_body(iron, hw)


## The lid, thrown back off the mouth. It sits ABOVE the body and slightly
## narrower, with hinges bridging the gap — that offset is what says "open"
## without needing perspective the rest of the board doesn't have.
func _draw_chest_lid(iron: Color, hw: float) -> void:
	var lw := hw * 0.95
	var base := CHEST_RIM - 7.0
	var dome := _dome(Vector2(0.0, base), Vector2(lw, base - CHEST_LID_TOP))

	## Hinges first, so the straps run UNDER the lid and read as going behind it.
	for e: float in [-1.0, 1.0]:
		draw_rect(Rect2(Vector2(hw * 0.62 * e - 4.0, base - 3.0), Vector2(8.0, 13.0)), iron)

	draw_colored_polygon(dome, CHEST_WOOD)
	## The underside of a thrown-back lid faces the ceiling and catches no light.
	draw_colored_polygon(_dome(Vector2(0.0, base - 3.0),
			Vector2(lw * 0.80, (base - CHEST_LID_TOP) * 0.70)), CHEST_WOOD_DARK)
	var outline := dome
	outline.append(dome[0])
	draw_polyline(outline, iron, 3.0)


## The front wall: planks, two iron straps, the lock and the feet. Drawn LAST so
## it crops the bottom of the gold stacks at the rim.
func _draw_chest_body(iron: Color, hw: float) -> void:
	var body := Rect2(Vector2(-hw, CHEST_RIM), Vector2(hw * 2.0, CHEST_BOTTOM - CHEST_RIM))
	draw_rect(body, CHEST_WOOD)
	for i in 3:
		var x := -hw + body.size.x * float(i + 1) / 4.0
		draw_line(Vector2(x, CHEST_RIM + 7.0), Vector2(x, CHEST_BOTTOM), CHEST_WOOD_DARK, 1.5)

	## Iron: the top lip, a vertical strap either side, the feet, and the outline.
	draw_rect(Rect2(Vector2(-hw, CHEST_RIM), Vector2(hw * 2.0, 6.0)), iron)
	for e: float in [-1.0, 1.0]:
		draw_rect(Rect2(Vector2(hw * 0.62 * e - 5.0, CHEST_RIM), Vector2(10.0, body.size.y)), iron)
		draw_rect(Rect2(Vector2(hw * 0.84 * e - 7.0, CHEST_BOTTOM - 3.0), Vector2(14.0, 8.0)), iron)
	draw_rect(body, iron, false, 3.0)

	## The lock, dead centre — the one detail that makes a wooden box a CHEST.
	var lock := Rect2(Vector2(-13.0, CHEST_RIM + 3.0), Vector2(26.0, 24.0))
	draw_rect(lock, iron.lightened(0.25))
	draw_rect(lock, CHEST_WOOD_DARK, false, 2.0)
	draw_circle(Vector2(0.0, CHEST_RIM + 12.0), 4.0, CHEST_INSIDE)
	draw_rect(Rect2(Vector2(-2.0, CHEST_RIM + 12.0), Vector2(4.0, 9.0)), CHEST_INSIDE)


## The pile, back row first so the front of it hides the back — the same
## drain-from-the-front order the old vault room used, now inside the chest.
func _draw_hoard(frac: float, hw: float) -> void:
	var total := VAULT_COLS * VAULT_ROWS
	var shown := int(ceil(frac * float(total)))
	for i in total:
		if i >= shown:
			break
		var cx: int = i % VAULT_COLS
		var cy: int = VAULT_ROWS - 1 - (i / VAULT_COLS)
		## Back rows sit higher and closer together: depth, on a board that has no
		## perspective of its own to borrow.
		var depth := float(cy) / float(VAULT_ROWS - 1)     ## 0 at the front, 1 at the back
		var spread := hw * (0.62 - 0.10 * depth)
		## Rows are staggered half a column apart so the back of the pile shows
		## BETWEEN the front stacks instead of hiding directly behind them. All
		## twelve have to be countable, or "one stack left" stops being a warning.
		var step := 2.0 * spread / float(VAULT_COLS - 1)
		var x := -spread + step * float(cx) + step * 0.25 * (1.0 if cy % 2 == 1 else -1.0)
		_draw_gold_stack(Vector2(x, CHEST_RIM + 2.0 - 9.0 * depth), 3 + (i % 3))


## A pile of coin edges, tapering as it rises. Drawn in whatever transform the
## caller has set — the chest sets one screen-upright transform for everything.
func _draw_gold_stack(p: Vector2, coins: int) -> void:
	var gold := Color(1.0, 0.82, 0.22)
	var edge := Color(0.55, 0.38, 0.05)
	for i in coins:
		var w := 16.0 - 1.7 * float(i)
		var y := p.y - 4.2 * float(i)
		var r := Rect2(Vector2(p.x - w * 0.5, y - 4.0), Vector2(w, 4.6))
		draw_rect(r, gold)
		draw_rect(r, edge, false, 1.0)


## Filled-polygon ellipse. draw_circle only does circles, and every rounded shape
## on the chest is wider than it is tall.
func _ellipse(c: Vector2, r: Vector2, seg: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in seg:
		var a := TAU * float(i) / float(seg)
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


## Half-ellipse standing on its flat edge — the chest's barrel top. `base` is the
## centre of that flat edge; the curve rises by `size.y` above it.
func _dome(base: Vector2, size: Vector2, seg: int = 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in seg + 1:
		var a := PI + PI * float(i) / float(seg)
		pts.append(base + Vector2(cos(a) * size.x, sin(a) * size.y))
	return pts


func _draw_build_nodes() -> void:
	if not show_nodes:
		return
	for i in build_nodes.size():
		var n: Dictionary = build_nodes[i]
		if n["occupied"]:
			continue
		var pos: Vector2 = n["pos"]
		var hovered := i == hover
		## Slot the size of a trap's footprint (matches the crossbow, 28x28). Drawn as
		## an EMPTY rounded square — just a soft-cornered outline, no fill. The old
		## slot texture (SLOT_TEX_PATH) filled these solid; the plain outline reads
		## cleaner, so the art is intentionally bypassed here.
		var half := 14.0
		var rect := Rect2(pos - Vector2(half, half), Vector2(half * 2.0, half * 2.0))
		var s: ColorScheme = Settings.scheme()
		var edge := s.accent if hovered else s.text
		edge.a = 0.9 if hovered else 0.5
		## draw_rect can't round corners; a StyleBoxFlat can. draw_center = false
		## leaves the middle empty so only the rounded border shows.
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = edge
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		draw_style_box(sb, rect)
