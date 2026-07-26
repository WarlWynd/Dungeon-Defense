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


func _ready() -> void:
	## A runtime-resized texture carries no import flags, so repeat has to be asked
	## for here or the shrunken stone would draw once and leave the rest bare.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_stone = GameData.stone_tile()
	if ResourceLoader.exists(SLOT_TEX_PATH):
		_slot_tex = load(SLOT_TEX_PATH) as Texture2D


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


## The vault is a ROOM, and the hoard is STACKS of coins in it — not one disc
## that shrinks. Stacks disappear one at a time as gold walks out the door, so
## losing 160 gold is something you can see happen rather than infer.
const VAULT_SIZE := Vector2(170, 124)
const VAULT_COLS := 4
const VAULT_ROWS := 3


func _draw_vault() -> void:
	var s: ColorScheme = Settings.scheme()
	var v := GameData.vault_pos()
	var frac := EconomySystem.hoard_fraction()
	var room := Rect2(v - VAULT_SIZE * 0.5, VAULT_SIZE)

	## Chamber: dark floor inside a stone lip, with an accent wash that fades as
	## the pile is emptied.
	if frac > 0.0:
		var wash := s.accent
		wash.a = 0.10 * frac
		draw_rect(room.grow(7.0 + 9.0 * frac), wash, false, 7.0)
	draw_rect(room, s.floor_col.darkened(0.70))
	draw_rect(room.grow(-6.0), s.floor_col.darkened(0.45))
	draw_rect(room, s.vault_trim, false, 3.0)

	var total := VAULT_COLS * VAULT_ROWS
	var shown := int(ceil(frac * float(total)))
	var cell := Vector2(VAULT_SIZE.x / float(VAULT_COLS + 1), VAULT_SIZE.y / float(VAULT_ROWS + 1))
	for i in total:
		if i >= shown:
			break
		## Fill back-to-front so the pile drains from the front of the room.
		var cx: int = i % VAULT_COLS
		var cy: int = VAULT_ROWS - 1 - (i / VAULT_COLS)
		var p := room.position + Vector2(cell.x * float(cx + 1), cell.y * float(cy + 1))
		_draw_gold_stack(p, 3 + (i % 3))


## A pile of coin edges, tapering as it rises. Drawn SCREEN-UPRIGHT (cancelling
## the board's rotation) so it reads as a stack in portrait and landscape alike.
func _draw_gold_stack(p: Vector2, coins: int) -> void:
	var gold := Color(1.0, 0.82, 0.22)
	var edge := Color(0.55, 0.38, 0.05)
	draw_set_transform(p, -global_rotation, Vector2.ONE)
	for i in coins:
		var w := 16.0 - 1.7 * float(i)
		var y := -4.2 * float(i)
		var r := Rect2(Vector2(-w * 0.5, y - 4.0), Vector2(w, 4.6))
		draw_rect(r, gold)
		draw_rect(r, edge, false, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
