extends Node2D
class_name Board

## Draws the dungeon: stone, path/maze, vault, entrance, build nodes. Lives
## under the World node so it inherits the fit-and-rotate transform.

const STONE_PATH := "res://assets/textures/dungeon_stone.png"
## Optional build-slot art. Drop a texture here and it replaces the placeholder
## square below with no other code changes.
const SLOT_TEX_PATH := "res://assets/textures/build_slot.png"
const STONE_TINT := Color(0.42, 0.42, 0.46)
const STONE_SCRIM := Color(0, 0, 0, 0.30)

var curve: Curve2D
var maze: Maze = null              ## set on maze boards; null otherwise
var build_nodes: Array = []
var show_nodes: bool = false
var hover: int = -1

var _stone: Texture2D
var _slot_tex: Texture2D


func _ready() -> void:
	if ResourceLoader.exists(STONE_PATH):
		_stone = load(STONE_PATH) as Texture2D
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

	draw_circle(GameData.entrance_pos(), 16.0, Color(0.55, 0.2, 0.2))
	_draw_build_nodes()


func _draw_maze() -> void:
	var edge_col := Color(0.06, 0.05, 0.05, 0.9)
	var floor_col := Color(0.33, 0.29, 0.24)
	var worn_col := Color(0.39, 0.35, 0.29, 0.55)
	for e in maze.get_edges():
		_draw_tunnel(maze.junctions[e[0]], maze.junctions[e[1]], 52.0, edge_col)
	for e in maze.get_edges():
		_draw_tunnel(maze.junctions[e[0]], maze.junctions[e[1]], 44.0, floor_col)
	for e in maze.get_edges():
		_draw_tunnel(maze.junctions[e[0]], maze.junctions[e[1]], 30.0, worn_col)
	for i in maze.junctions.size():
		draw_circle(maze.junctions[i], 22.0, floor_col)
	for i in maze.dead_ends():
		draw_circle(maze.junctions[i], 15.0, Color(0.28, 0.26, 0.22))


func _draw_tunnel(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	draw_line(a, b, col, w)
	draw_circle(a, w * 0.5, col)
	draw_circle(b, w * 0.5, col)


func _draw_stone() -> void:
	var board := Rect2(Vector2.ZERO, Vector2(720, 1280))
	if _stone == null:
		draw_rect(board, Color(0.17, 0.17, 0.19))
		return
	draw_texture_rect(_stone, board, true, STONE_TINT)
	draw_rect(board, STONE_SCRIM)
	for i in 5:
		var inset := float(i) * 9.0
		var a := 0.05 * (5.0 - float(i)) / 5.0
		draw_rect(Rect2(Vector2(inset, inset),
				Vector2(720.0 - inset * 2.0, 1280.0 - inset * 2.0)),
				Color(0, 0, 0, a), false, 18.0)


func _draw_path() -> void:
	var pts := curve.get_baked_points()
	if pts.size() < 2:
		return
	_draw_river(pts, 52.0, Color(0.06, 0.05, 0.05, 0.9))
	_draw_river(pts, 44.0, Color(0.33, 0.29, 0.24))
	_draw_river(pts, 30.0, Color(0.39, 0.35, 0.29, 0.55))


func _draw_river(pts: PackedVector2Array, width: float, col: Color) -> void:
	draw_polyline(pts, col, width)
	var r := width * 0.5
	var i := 0
	while i < pts.size():
		draw_circle(pts[i], r, col)
		i += 3
	draw_circle(pts[0], r, col)
	draw_circle(pts[pts.size() - 1], r, col)


func _draw_vault() -> void:
	var v := GameData.vault_pos()
	var frac := EconomySystem.hoard_fraction()
	draw_circle(v, 50.0, Color(0.10, 0.09, 0.07))
	draw_arc(v, 50.0, 0.0, TAU, 32, Color(0.5, 0.42, 0.2), 2.0)
	if frac > 0.0:
		draw_circle(v, 46.0 + 26.0 * frac, Color(1.0, 0.75, 0.2, 0.10 * frac))
	var pile := 6.0 + 38.0 * frac
	draw_circle(v, pile, Color(1.0, 0.82, 0.22))
	draw_arc(v, pile, 0.0, TAU, 28, Color(0.65, 0.45, 0.05), 2.0)


func _draw_build_nodes() -> void:
	if not show_nodes:
		return
	for i in build_nodes.size():
		var n: Dictionary = build_nodes[i]
		if n["occupied"]:
			continue
		var pos: Vector2 = n["pos"]
		var hovered := i == hover
		## Slot the size of a trap's footprint (matches the crossbow, 28x28). Uses
		## SLOT_TEX_PATH art if present, else the placeholder square.
		var half := 14.0
		if _slot_tex != null:
			## Draw the slot art SCREEN-UPRIGHT (cancel the board's rotation) so it
			## reads the same in portrait or landscape, like the trap sprites.
			var tint := Color(1, 1, 1, 0.95) if hovered else Color(1, 1, 1, 0.55)
			draw_set_transform(pos, -global_rotation, Vector2.ONE)
			draw_texture_rect(_slot_tex, Rect2(Vector2(-half, -half), Vector2(half * 2.0, half * 2.0)), false, tint)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			var rect := Rect2(pos - Vector2(half, half), Vector2(half * 2.0, half * 2.0))
			var col := Color(0.9, 0.9, 0.5, 0.55) if hovered else Color(0.7, 0.7, 0.7, 0.28)
			draw_rect(rect, col)
			draw_rect(rect, Color(1, 1, 1, 0.5), false, 1.5)
