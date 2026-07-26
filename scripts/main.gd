extends Node2D

## MILESTONE 1 — VERTICAL SLICE. Colored shapes. The dungeon is authored in a
## fixed 720x1280 design space and the World node is scaled/rotated to fit any
## viewport (_fit_world). Input converts back through the same transform.
## KEYS: P/Space/Esc = pause, F = 2x speed, R = swap portrait/landscape.

enum Phase { BUILD, COMBAT, WON, LOST }

const DESIGN := Vector2(720, 1280)

## Banner colours for the win summary. Deliberately outside the ColorScheme
## palette — these encode "you won this" / "you lost this", which shouldn't
## change meaning when the player picks a different theme.
const WIN_GREEN := "#5bd87a"
const LOSS_RED := "#ff5c4d"

var phase: Phase = Phase.BUILD
var wave_index: int = 0
var build_timer: float = 0.0

var _curve: Curve2D
var _world: Node2D
var _board: Board
var _spawner: WaveSpawner
var _allure: AllureSystem
var _hud: Hud

var _maze: Maze = null
var _escape_curve: Curve2D = null

var _build_nodes: Array = []
var _selected_trap: String = ""
var _hover_node: int = -1
var _speed: int = 1        ## 1x / 2x / 3x

const SPEED_MIN := 1
const SPEED_MAX := 3

const ROAD_HALF_WIDTH := 25.0
const COMMAND_REACH := 45.0   ## click within this of the path to post; else deselect
const NODE_OFFSET := 38.0
const CANDIDATE_STEP := 34.0
const PATH_END_MARGIN := 80.0
const MINION_POST_OFFSETS := [400.0, 300.0, 205.0, 115.0, 65.0, 35.0]

## Screen-space bands kept clear of the dungeon so the HUD never draws over the
## pathing. TOP covers the hoard bar + wave/minion/toast text; BOTTOM covers the
## trap tray + UNLEASH (bottom-right); LEFT covers the Anti-Heroes roster panel
## and the inspector panel (both bottom-left); RIGHT is now clear. Tune these if
## the HUD layout in hud.gd changes.
## How much darker the screen behind the board is than the board itself. Both are
## the same masonry now, so this is the only thing besides the board's rounded
## border telling you where the playable floor ends. 0.0 makes them identical.
const BACKDROP_DARKEN := 0.42

const HUD_TOP_RESERVE := 100.0
const HUD_BOTTOM_RESERVE := 74.0
const HUD_RIGHT_RESERVE := 0.0
const HUD_LEFT_RESERVE := 290.0


func _ready() -> void:
	## Main is ALWAYS (so pause works); simulation nodes are PAUSABLE.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_backdrop()

	_hud = Hud.new()
	add_child(_hud)
	_hud.unleash_pressed.connect(_unleash)
	_hud.pause_pressed.connect(_toggle_pause)
	_hud.speed_step_pressed.connect(_step_speed)
	_hud.trap_selected.connect(func(id: String): _selected_trap = id)
	_hud.board_step_pressed.connect(_on_switch_board)
	_hud.trap_slots_changed.connect(_on_trap_slots_changed)
	_hud.antihero_selected.connect(_on_antihero_selected)
	_hud.trap_sell_pressed.connect(_on_sell_trap)
	_hud.trap_upgrade_pressed.connect(_on_upgrade_trap)
	_hud.store_recruit.connect(_on_store_recruit)
	_hud.store_buy_gold.connect(_on_store_buy_gold)
	_hud.store_buy_souls.connect(_on_store_buy_souls)
	_hud.store_get_pack.connect(_on_store_get_pack)
	_hud.store_watch_ad.connect(_on_store_watch_ad)
	_hud.profile_play.connect(_on_profile_play)
	_hud.profile_new.connect(_on_profile_new)
	_hud.profile_erase.connect(_on_profile_erase)

	EventBus.hero_died.connect(_on_hero_died)
	EventBus.hero_escaped.connect(_on_hero_escaped)
	EventBus.hoard_empty.connect(_on_hoard_empty)
	EventBus.hoard_changed.connect(_on_hoard_changed)
	EventBus.minion_arrived.connect(func(d: MinionData):
			_hud.say("%s joins you. It smelled the Gold." % d.display_name))
	EventBus.minion_deserted.connect(func(d: MinionData):
			_hud.say("%s walks out. Your pile isn't impressive anymore." % d.display_name))
	EventBus.minion_reinforced.connect(func(d: MinionData, n: int):
			_hud.say("%d fresh %s%s crawl out of the dark." % [n, d.unit_display(), "" if n == 1 else "s"]))

	get_viewport().size_changed.connect(_fit_world)
	_load_board()


## The UI backdrop: the dungeon hide that fills every part of the screen the
## fitted board doesn't cover. It gets its OWN CanvasLayer at -1 so it sits under
## both the world (layer 0) and the HUD (layer 1) — put inside the HUD it would
## paint straight over the board instead. Survives board changes, so it's built
## once here rather than in _load_board.
func _build_backdrop() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)

	var rect := Control.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## The tile is resized at runtime and so carries no import flags — repeat has
	## to be asked for or it would draw once in the corner.
	rect.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	rect.draw.connect(_draw_backdrop.bind(rect))
	layer.add_child(rect)

	## The tint comes from the palette, so the backdrop follows the theme the way
	## the board does; repaint it when either the palette or the window changes.
	Settings.color_scheme_changed.connect(func(_i: int): rect.queue_redraw())
	rect.resized.connect(rect.queue_redraw)


## Tiled with the SAME stone the dungeon floor uses, at the same tile size and the
## same palette tint — then darkened, so the board still reads as the raised
## surface you build on rather than dissolving into its surroundings.
func _draw_backdrop(node: Control) -> void:
	var s: ColorScheme = Settings.scheme()
	var full := Rect2(Vector2.ZERO, node.size)
	var tex := GameData.stone_tile()
	if tex == null:
		node.draw_rect(full, s.stone_dark.lerp(Board.BG_BLUE, Board.BG_BLUE_MIX))
		return
	node.draw_texture_rect(tex, full, true, s.stone.lerp(Board.BG_BLUE, Board.BG_BLUE_MIX))
	node.draw_rect(full, Color(0, 0, 0, BACKDROP_DARKEN))


## Build or rebuild the whole playfield for the active board.
func _load_board() -> void:
	if _world != null and is_instance_valid(_world):
		_world.queue_free()
	if _spawner != null and is_instance_valid(_spawner):
		_spawner.queue_free()
	if _allure != null and is_instance_valid(_allure):
		_allure.clear()
		_allure.queue_free()

	phase = Phase.BUILD
	wave_index = 0
	_selected_trap = ""
	_hover_node = -1
	Engine.time_scale = float(_speed)
	## The centre banner is the one piece of board state that isn't rebuilt below —
	## a WON/LOST result from the previous board would otherwise sit over the new
	## one, reporting numbers EconomySystem.reset() has already cleared.
	_hud.set_message("")

	_build_curve()

	_world = Node2D.new()
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)

	_board = Board.new()
	_board.curve = _curve
	_board.maze = _maze
	_world.add_child(_board)

	_spawner = WaveSpawner.new()
	_spawner.process_mode = Node.PROCESS_MODE_PAUSABLE
	_spawner.setup(_world, _make_routes)
	add_child(_spawner)

	_allure = AllureSystem.new()
	_allure.process_mode = Node.PROCESS_MODE_PAUSABLE
	_allure.setup(_world, _minion_posts())
	_allure.set_router(Callable(self, "_route_between"))
	## The roster list is otherwise only rebuilt by the per-frame _refresh(), which
	## _process skips while the game is PAUSED and in the WON/LOST phases — so an
	## Anti-Hero could walk onto the board (bought in the store, or drawn out by a
	## hoard that just grew) and not appear in the list beside it. This is what the
	## signal was for; nothing had been listening to it.
	_allure.roster_changed.connect(_on_roster_changed)
	add_child(_allure)

	_generate_build_nodes()
	_board.build_nodes = _build_nodes

	EconomySystem.reset(GameData.STARTING_HOARD, GameData.HOARD_CAPACITY)
	_allure.refresh_roster()

	if get_tree().paused:
		_toggle_pause()

	_fit_world()
	_start_build_phase()


func _on_switch_board(delta: int) -> void:
	GameData.step_board(delta)
	_load_board()
	_hud.say("Now playing: %s" % GameData.board()["name"])


func _on_trap_slots_changed() -> void:
	var occupied_positions: Array = []
	for n in _build_nodes:
		if n["occupied"]:
			occupied_positions.append(n["pos"])

	_generate_build_nodes()

	for pos in occupied_positions:
		var matched := false
		for n in _build_nodes:
			if not n["occupied"] and n["pos"].distance_to(pos) < 4.0:
				n["occupied"] = true
				matched = true
				break
		if not matched:
			_build_nodes.append({"pos": pos, "occupied": true})

	_board.build_nodes = _build_nodes
	_board.queue_redraw()
	_hud.say("%s: %d trap locations" % [GameData.board()["name"], Settings.get_trap_slots(GameData.board()["name"])])


# --- Orientation -----------------------------------------------------------

func _fit_world() -> void:
	var vp := Vector2(get_viewport_rect().size)
	if vp.x <= 0.0 or vp.y <= 0.0:
		return

	## Fit the dungeon into the clear region BELOW the top HUD band, ABOVE the
	## bottom trap tray, and BETWEEN the left roster panel and right inspector,
	## so the UI can never overlap the pathing. Reserves are clamped so a small
	## window still leaves the board visible.
	var top := minf(HUD_TOP_RESERVE, vp.y * 0.6)
	var bottom := minf(HUD_BOTTOM_RESERVE, vp.y * 0.2)
	var left := minf(HUD_LEFT_RESERVE, vp.x * 0.3)
	var right := minf(HUD_RIGHT_RESERVE, vp.x * 0.3)
	var avail_pos := Vector2(left, top)
	var avail_size := Vector2(maxf(vp.x - left - right, 1.0), maxf(vp.y - top - bottom, 1.0))

	if vp.x > vp.y:
		var content := Vector2(DESIGN.y, DESIGN.x)
		var s: float = minf(avail_size.x / content.x, avail_size.y / content.y)
		var origin := avail_pos + (avail_size - content * s) * 0.5
		_world.rotation = -PI / 2.0
		_world.scale = Vector2(s, s)
		_world.position = Vector2(origin.x, origin.y + DESIGN.x * s)
	else:
		var s: float = minf(avail_size.x / DESIGN.x, avail_size.y / DESIGN.y)
		var origin := avail_pos + (avail_size - DESIGN * s) * 0.5
		_world.rotation = 0.0
		_world.scale = Vector2(s, s)
		_world.position = origin

	if _hud:
		_hud.redraw_hoard()
	if is_inside_tree():
		for n in get_tree().get_nodes_in_group("heroes"):
			(n as Node2D).queue_redraw()
		for n in get_tree().get_nodes_in_group("minions"):
			(n as Node2D).queue_redraw()


func _to_design(screen_pos: Vector2) -> Vector2:
	return _world.to_local(screen_pos)


# --- Level geometry --------------------------------------------------------

func _build_curve() -> void:
	if GameData.is_maze():
		_build_maze()
		return

	_maze = null
	_curve = Curve2D.new()
	var pts: Array = GameData.path_points()
	var smoothing: float = GameData.path_smoothing()
	var n := pts.size()
	for i in n:
		var p: Vector2 = pts[i]
		var prev: Vector2 = pts[maxi(i - 1, 0)]
		var next: Vector2 = pts[mini(i + 1, n - 1)]
		var tangent := (next - prev) * smoothing * 0.5
		if i == 0 or i == n - 1:
			tangent *= 0.5
		_curve.add_point(p, -tangent, tangent)
	_curve.bake_interval = 4.0


func _build_maze() -> void:
	var b := GameData.board()
	_maze = Maze.new()
	_maze.setup(b["junctions"], b["edges"], b["entrance"], b["vault"])
	_escape_curve = _points_to_curve(_maze.escape_route())
	_curve = _escape_curve


func _points_to_curve(points: PackedVector2Array) -> Curve2D:
	var c := Curve2D.new()
	for p in points:
		c.add_point(p)
	c.bake_interval = 4.0
	return c


func _make_routes() -> Array:
	if GameData.is_maze():
		return [_points_to_curve(_maze.random_approach()), _escape_curve]
	return [_curve, null]


func _generate_build_nodes() -> void:
	_build_nodes.clear()
	var candidates := _maze_slot_candidates() if GameData.is_maze() else _slot_candidates()
	if candidates.is_empty():
		return
	var want: int = clampi(Settings.get_trap_slots(GameData.board()["name"]), 1, candidates.size())
	if want >= candidates.size():
		for pos in candidates:
			_build_nodes.append({"pos": pos, "occupied": false})
		return
	for i in want:
		var idx: int = int(round(float(i) * float(candidates.size() - 1) / float(want - 1))) if want > 1 else candidates.size() / 2
		_build_nodes.append({"pos": candidates[idx], "occupied": false})


func _slot_candidates() -> Array:
	var out: Array = []
	var length := _curve.get_baked_length()
	var d := PATH_END_MARGIN
	var side := 1.0
	while d < length - PATH_END_MARGIN:
		var p := _curve.sample_baked(d)
		var ahead := _curve.sample_baked(minf(d + 8.0, length))
		var behind := _curve.sample_baked(maxf(d - 8.0, 0.0))
		var tangent := (ahead - behind).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		for s: float in [side, -side]:
			var pos: Vector2 = p + normal * s * NODE_OFFSET
			if pos.x <= 30.0 or pos.x >= 690.0 or pos.y <= 30.0 or pos.y >= 1250.0:
				continue
			if _dist_to_path(pos) < ROAD_HALF_WIDTH + 6.0:
				continue
			out.append(pos)
			side = -side
			break
		d += CANDIDATE_STEP
	return out


func _dist_to_path(p: Vector2) -> float:
	var best := INF
	for b in _curve.get_baked_points():
		best = minf(best, p.distance_to(b))
	return best


func _maze_slot_candidates() -> Array:
	var out: Array = []
	var seen: Array = []
	for e in GameData.board()["edges"]:
		var a: Vector2 = _maze.junctions[e[0]]
		var b: Vector2 = _maze.junctions[e[1]]
		var seg := b - a
		var len_seg := seg.length()
		if len_seg < 1.0:
			continue
		var dir := seg / len_seg
		var normal := Vector2(-dir.y, dir.x)
		var d := PATH_END_MARGIN * 0.5
		while d < len_seg - PATH_END_MARGIN * 0.5:
			var p := a + dir * d
			for s: float in [1.0, -1.0]:
				var pos: Vector2 = p + normal * s * NODE_OFFSET
				if pos.x <= 30.0 or pos.x >= 690.0 or pos.y <= 30.0 or pos.y >= 1250.0:
					continue
				if _dist_to_maze(pos) < ROAD_HALF_WIDTH + 6.0:
					continue
				if _too_close(pos, seen, 26.0):
					continue
				out.append(pos)
				seen.append(pos)
				break
			d += CANDIDATE_STEP
	return out


func _dist_to_maze(p: Vector2) -> float:
	var best := INF
	for e in GameData.board()["edges"]:
		best = minf(best, _point_to_segment(p, _maze.junctions[e[0]], _maze.junctions[e[1]]))
	return best


func _point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0
	var d2 := ab.length_squared()
	if d2 > 0.0:
		t = clampf((p - a).dot(ab) / d2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _too_close(p: Vector2, others: Array, r: float) -> bool:
	for o in others:
		if p.distance_to(o) < r:
			return true
	return false


func _minion_posts() -> Array[Vector2]:
	var posts: Array[Vector2] = []
	if GameData.is_maze():
		var elen := _escape_curve.get_baked_length()
		for offset in MINION_POST_OFFSETS:
			if offset < elen - 20.0:
				posts.append(_escape_curve.sample_baked(offset))
	else:
		var length := _curve.get_baked_length()
		for offset in MINION_POST_OFFSETS:
			var d: float = length - offset
			if d >= 60.0:
				posts.append(_curve.sample_baked(d))
	if posts.is_empty():
		posts.append(GameData.vault_pos())
	return posts


## Corridor route between two design-space points, following the board geometry
## (the maze tunnels, or the path curve) instead of a straight line — so a
## commanded Anti-Hero walks to its post without cutting through the stone.
func _route_between(from: Vector2, to: Vector2) -> PackedVector2Array:
	if _maze != null:
		return _maze.route_points(from, to)
	if _curve != null:
		return _curve_route(from, to)
	return PackedVector2Array([to])


## Nearest point ON the path (maze tunnel or curve) to an arbitrary point, so a
## commanded Anti-Hero's post lands on the path rather than in the stone.
func _snap_to_path(p: Vector2) -> Vector2:
	if _maze != null:
		return _maze.nearest_path_point(p)
	if _curve != null:
		var pts := _curve.get_baked_points()
		if pts.is_empty():
			return p
		var best: Vector2 = pts[0]
		var best_d := INF
		for bp in pts:
			var d := bp.distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = bp
		return best
	return p


func _curve_route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var pts := _curve.get_baked_points()
	if pts.size() < 2:
		return PackedVector2Array([to])
	var i_from := _nearest_baked_index(pts, from)
	var i_to := _nearest_baked_index(pts, to)
	var out := PackedVector2Array()
	var step := 6
	if i_from <= i_to:
		var i := i_from
		while i < i_to:
			out.append(pts[i])
			i += step
	else:
		var i := i_from
		while i > i_to:
			out.append(pts[i])
			i -= step
	out.append(pts[i_to])
	out.append(to)
	return out


func _nearest_baked_index(pts: PackedVector2Array, p: Vector2) -> int:
	var best := 0
	var best_d := INF
	for i in pts.size():
		var d := pts[i].distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


# --- Phase flow ------------------------------------------------------------

func _start_build_phase() -> void:
	if wave_index >= GameData.wave_count():
		phase = Phase.WON
		EventBus.level_won.emit(EconomySystem.hoard)
		## Win banner reads at a glance from colour alone: the headline and what you
		## kept in green, what walked out the door in red. Fixed hex rather than
		## palette colours — green/red mean won/lost here, not "current theme".
		_hud.set_message(("[color=%s]HOARD DEFENDED[/color]\n[color=%s]%d Gold kept[/color]\n[color=%s]%d Gold stolen[/color]"
				% [WIN_GREEN, WIN_GREEN, EconomySystem.hoard, LOSS_RED, EconomySystem.gold_lost]))
		_refresh()
		return
	phase = Phase.BUILD
	build_timer = GameData.BUILD_SECONDS
	_allure.advance_to_wave(wave_index)
	_allure.update_restless_flags()
	EventBus.build_phase_started.emit(build_timer)
	_refresh()


func _unleash() -> void:
	if phase != Phase.BUILD:
		return
	phase = Phase.COMBAT
	_spawner.start_wave(wave_index)
	EventBus.wave_started.emit(wave_index, GameData.wave_count())
	_refresh()


func _heroes_remaining() -> int:
	return get_tree().get_nodes_in_group("heroes").size()


func _process(_delta: float) -> void:
	if get_tree().paused:
		return
	match phase:
		Phase.BUILD:
			_refresh()
		Phase.COMBAT:
			if not _spawner.is_spawning() and _heroes_remaining() == 0:
				EventBus.wave_cleared.emit(wave_index)
				_allure.refresh_roster()
				wave_index += 1
				_start_build_phase()
			_refresh()
		_:
			pass
	_board.show_nodes = _can_build()
	_board.hover = _hover_node
	_board.queue_redraw()


## Hoard changed — repaint the bar, and let a growing pile attract minions LIVE.
## Arrivals are evaluated the instant gold moves (e.g. loot recovered mid-fight);
## desertions still wait for the between-waves check in AllureSystem.
func _on_hoard_changed(_total: int) -> void:
	if _hud != null:
		_hud.redraw_hoard()
	if (phase == Phase.BUILD or phase == Phase.COMBAT) and _allure != null and is_instance_valid(_allure):
		_allure.refresh_arrivals()


## Someone arrived, deserted, was reinforced or went restless — repaint the list
## immediately rather than waiting for a frame that may never come.
func _on_roster_changed() -> void:
	if _hud != null:
		_hud.refresh_roster()


func _on_hoard_empty() -> void:
	if phase == Phase.WON or phase == Phase.LOST:
		return
	phase = Phase.LOST
	EventBus.level_lost.emit()
	_hud.set_message("LOOTED.\nThey took everything.")
	_refresh()


# --- Steal-and-flee payoff -------------------------------------------------

func _on_hero_died(hero: Node, carried_gold: int) -> void:
	var hero2d := hero as Node2D
	var h: Hero = hero as Hero

	## Kills feed Souls — the currency that recruits Anti-Heroes.
	var soul_gain := 3
	if h != null:
		soul_gain = 2 + maxi(0, int(h.data.bounty / 8.0))
	Bank.add_souls(soul_gain)

	if h != null and h.data.bounty > 0:
		var loot := Coin.new()
		loot.setup(hero2d.position, GameData.vault_pos(), h.data.bounty, true)
		_world.add_child(loot)

	if carried_gold <= 0:
		if h != null and h.data.bounty > 0:
			_hud.say("Plundered %d Gold." % h.data.bounty)
		return

	var coin := Coin.new()
	coin.setup(hero2d.position, GameData.vault_pos(), carried_gold, false)
	_world.add_child(coin)
	_hud.say("Recovered %d Gold — and plundered %d more." % [carried_gold, h.data.bounty if h != null else 0])


func _on_hero_escaped(_hero: Node, stolen: int) -> void:
	if stolen > 0:
		_hud.say("ROBBED. %d Gold gone for good." % stolen)


# --- Input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			match key.keycode:
				KEY_R:
					_toggle_window_orientation()
					return
				KEY_P, KEY_SPACE, KEY_ESCAPE:
					_toggle_pause()
					return
				KEY_F:
					_cycle_speed()
					return

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _can_build():
			_hover_node = _node_at(_to_design(motion.position))
		return

	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_tap(_to_design(click.position))
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_tap(_to_design(touch.position))


func _toggle_window_orientation() -> void:
	var before := DisplayServer.window_get_size()
	DisplayServer.window_set_size(Vector2i(before.y, before.x))
	await get_tree().process_frame
	if DisplayServer.window_get_size() == before:
		_hud.say("Embedded window can't resize — see README")
		push_warning("Rotation blocked: game embedded in editor. Editor Settings > Run > Window Placement > Game Embed Mode > Disabled.")


func _toggle_pause() -> void:
	var tree := get_tree()
	tree.paused = not tree.paused
	_hud.set_controls(tree.paused, _speed)
	## A finished level already owns the banner. Writing PAUSED over a WON/LOST
	## summary would replace it, and unpausing would then clear it for good — the
	## scrim and the play/pause glyph still show the state.
	if phase == Phase.WON or phase == Phase.LOST:
		return
	_hud.set_message("PAUSED" if tree.paused else "")


## Spinner arrows clamp; the F key cycles round so one key still reaches every speed.
func _step_speed(delta: int) -> void:
	_set_speed(clampi(_speed + delta, SPEED_MIN, SPEED_MAX))


func _cycle_speed() -> void:
	_set_speed(SPEED_MIN if _speed >= SPEED_MAX else _speed + 1)


func _set_speed(value: int) -> void:
	_speed = clampi(value, SPEED_MIN, SPEED_MAX)
	Engine.time_scale = float(_speed)
	_hud.set_controls(get_tree().paused, _speed)


func _tap(design_pos: Vector2) -> void:
	var unit := _unit_at(design_pos)
	if unit != null:
		## Tap a unit to inspect it; tap the SAME unit again to deselect.
		_select(null if unit == _hud.inspected() else unit)
		return
	if get_tree().paused:
		_select(null)
		return
	## A trap armed + a build node tapped always builds (takes priority).
	var idx := _node_at(design_pos)
	if idx >= 0 and _selected_trap != "" and _can_build():
		_try_build(idx)
		return
	## Otherwise, if an Anti-Hero is selected, order it to guard this spot.
	var sel := _hud.inspected()
	if sel != null and is_instance_valid(sel) and sel is Minion:
		var post := _snap_to_path(design_pos)
		if design_pos.distance_to(post) <= COMMAND_REACH:
			(sel as Minion).command_to(post, Callable(self, "_route_between"))
			_hud.say("%s holds this ground." % (sel as Minion).data.unit_display())
		else:
			_select(null)   ## clicked into the stone, off the path — just deselect
		return
	_select(null)


func _can_build() -> bool:
	return phase == Phase.BUILD or phase == Phase.COMBAT


func _select(unit: Node2D) -> void:
	var prev := _hud.inspected()
	if prev != null and is_instance_valid(prev):
		prev.set("selected", false)
		prev.z_index = 0
		prev.queue_redraw()
	if unit != null:
		unit.set("selected", true)
		unit.z_index = 10
		unit.queue_redraw()
	_hud.inspect(unit)


## Roster click selects the Anti-Hero; the next field tap posts it (see _tap).
func _on_antihero_selected(unit: Node2D) -> void:
	if unit != null and is_instance_valid(unit):
		_select(unit)
		_hud.say("%s ready — click the field to post it." % (unit as Minion).data.unit_display())


# --- Store -----------------------------------------------------------------

func _on_store_recruit(id: String, currency: String) -> void:
	var d: MinionData = GameData.minions.get(id)
	if d == null or Bank.is_unlocked(id):
		return
	## A price of 0 means "not sold in this currency" — the Troll, Ogre and Goblins
	## are gem-only. Without this, spend_souls(0) succeeds and hands them over free.
	if currency == "gems":
		if d.recruit_gems <= 0:
			return
		if not Bank.spend_gems(d.recruit_gems):
			_hud.say("Not enough gems.")
			return
	else:
		if d.recruit_souls <= 0:
			return
		if not Bank.spend_souls(d.recruit_souls):
			_hud.say("Not enough souls.")
			return
	Bank.unlock(id)
	if _allure != null and is_instance_valid(_allure):
		_allure.refresh_arrivals()
	_hud.say("%s recruited." % d.display_name)
	_hud.refresh_store()


func _on_store_buy_gold() -> void:
	if not Bank.spend_gems(Bank.GEM_GOLD_COST):
		_hud.say("Not enough gems.")
		return
	EconomySystem.add_gold(Bank.GOLD_REFILL)
	_hud.say("+%d Gold to the hoard." % Bank.GOLD_REFILL)
	_hud.refresh_store()


func _on_store_buy_souls() -> void:
	if not Bank.spend_gems(Bank.GEM_SOULS_COST):
		_hud.say("Not enough gems.")
		return
	Bank.add_souls(Bank.SOULS_PACK)
	_hud.say("+%d souls." % Bank.SOULS_PACK)
	_hud.refresh_store()


func _on_store_get_pack(pack_id: String) -> void:
	Bank.purchase_gems(pack_id)
	_hud.refresh_store()


func _on_store_watch_ad() -> void:
	Bank.watch_ad_for_gems()
	_hud.refresh_store()


# --- Save slots ------------------------------------------------------------
#
# Switching character changes which Anti-Heroes are unlocked, so the level is
# rebuilt from the start rather than left mid-wave with the previous player's
# roster standing on the board.

func _on_profile_play(index: int) -> void:
	Bank.use_profile(index)
	_load_board()
	_hud.refresh_profiles()
	_hud.say("Character %d — %d souls, %d gems." % [index + 1, Bank.souls, Bank.gems])


func _on_profile_new(index: int) -> void:
	Bank.new_profile(index)
	_load_board()
	_hud.refresh_profiles()
	_hud.say("Character %d — a fresh start. Nothing recruited, nothing owed." % (index + 1))


func _on_profile_erase(index: int) -> void:
	var was_active := index == Bank.profile
	Bank.erase_profile(index)
	if was_active:
		_load_board()
	_hud.refresh_profiles()
	_hud.say("Character %d erased." % (index + 1))


func _unit_at(design_pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	var best_order := -1
	for group in ["heroes", "minions", "traps"]:
		for n in get_tree().get_nodes_in_group(group):
			var unit := n as Node2D
			if unit == null or not is_instance_valid(unit):
				continue
			var r: float = 16.0
			if group != "traps":
				var d = unit.get("data")
				if d != null:
					r = d.radius
			var dist := unit.position.distance_to(design_pos)
			if dist > r + 14.0:
				continue
			var order := unit.get_index()
			if dist < best_dist - 0.5:
				best_dist = dist
				best_order = order
				best = unit
			elif absf(dist - best_dist) <= 0.5 and order > best_order:
				best_dist = dist
				best_order = order
				best = unit
	return best


func _node_at(design_pos: Vector2) -> int:
	for i in _build_nodes.size():
		var n: Dictionary = _build_nodes[i]
		if n["occupied"]:
			continue
		var p: Vector2 = n["pos"]
		if p.distance_to(design_pos) <= 30.0:
			return i
	return -1


## Sell a placed trap: refund part of its cost, free the build slot it sat on, and
## remove it. The trap doesn't store its slot index, so match the slot by position
## (the trap was placed exactly on the node).
func _on_sell_trap(trap: Node2D) -> void:
	if trap == null or not is_instance_valid(trap):
		return
	var t := trap as Trap
	if t == null:
		return
	var refund := t.sell_value()
	## Free the slot the trap sat on. Match the NEAREST occupied node rather than an
	## exact position hit: the trap is placed on its node, so the closest occupied
	## node is always its own, and this survives any float drift or node re-indexing
	## from an earlier trap-slot change. Missing the match would strand the slot as
	## permanently occupied — no marker, unbuildable.
	var best_i := -1
	var best_d := INF
	for i in _build_nodes.size():
		if not _build_nodes[i]["occupied"]:
			continue
		var d: float = _build_nodes[i]["pos"].distance_to(t.position)
		if d < best_d:
			best_d = d
			best_i = i
	if best_i >= 0:
		_build_nodes[best_i]["occupied"] = false
	EconomySystem.add_gold(refund)
	_select(null)   ## drops the inspector before the node is freed
	t.queue_free()
	_hud.say("Sold %s  (+%d Gold)" % [t.data.display_name, refund])
	_allure.update_restless_flags()
	if _board != null:
		_board.build_nodes = _build_nodes
		_board.queue_redraw()
	_refresh()


## Upgrade a placed trap in place: pay from the hoard, raise its level. The trap
## keeps its slot and its targeting — this is the answer when there is nowhere
## left to build but plenty of Gold to spend.
func _on_upgrade_trap(trap: Node2D) -> void:
	if trap == null or not is_instance_valid(trap):
		return
	var t := trap as Trap
	if t == null:
		return
	if not t.can_upgrade():
		_hud.say("%s is already at Lv %d." % [t.data.display_name, Trap.MAX_LEVEL])
		return
	var cost := t.next_upgrade_cost()
	if not EconomySystem.can_afford(cost):
		_hud.say("Not enough Gold to upgrade the %s." % t.data.display_name)
		return
	EconomySystem.spend(cost)
	t.upgrade(cost)
	_hud.say("%s is now Lv %d.  (-%d Gold)" % [t.data.display_name, t.level, cost])
	_hud.refresh_inspector()
	_allure.update_restless_flags()
	_refresh()


func _try_build(idx: int) -> void:
	if _selected_trap == "":
		_hud.say("Pick a trap first.")
		return
	var d: TrapData = GameData.traps[_selected_trap]
	if not EconomySystem.can_afford(d.cost):
		_hud.say("Not enough Gold in the vault.")
		return
	EconomySystem.spend(d.cost)
	var t := Trap.new()
	t.setup(d)
	t.position = _build_nodes[idx]["pos"]
	t.add_to_group("traps")
	_world.add_child(t)
	_build_nodes[idx]["occupied"] = true
	_allure.update_restless_flags()
	_refresh()


# --- HUD glue --------------------------------------------------------------

func _wave_summary(index: int) -> String:
	if index < 0 or index >= GameData.WAVES.size():
		return ""
	var comp: Dictionary = GameData.WAVES[index]
	var parts := []
	for key in comp.keys():
		var id: String = key
		var n: int = comp[id]
		var d: HeroData = GameData.heroes[id]
		parts.append("%dx %s" % [n, d.display_name])
	return ", ".join(parts)


func _refresh() -> void:
	if _hud == null:
		return

	var wave_text := ""
	match phase:
		Phase.BUILD:
			wave_text = "BUILD — wave %d/%d  ·  tap START\nIncoming: %s" % [wave_index + 1, GameData.wave_count(), _wave_summary(wave_index)]
		Phase.COMBAT:
			wave_text = "WAVE %d/%d — %d heroes in the dungeon  ·  you can still build" % [wave_index + 1, GameData.wave_count(), _heroes_remaining()]

	if EconomySystem.gold_lost > 0 and wave_text != "":
		wave_text += "   |   stolen: %d" % EconomySystem.gold_lost

	var ids := _allure.active_ids()
	var minion_text := ""
	var minion_col := Color(0.6, 0.9, 0.5)
	var restless := false

	if ids.is_empty():
		minion_text = "No Anti-Heroes drawn to your pile"
		minion_col = Color(0.6, 0.6, 0.6)
	else:
		var names := []
		for key in ids:
			var id: String = key
			var d: MinionData = GameData.minions[id]
			var alive := 0
			for n in get_tree().get_nodes_in_group("minions"):
				var m := n as Minion
				if m != null and is_instance_valid(m) and m.data.id == id:
					alive += 1
			var label := d.unit_display()
			if alive > 1 or d.count > 1:
				label = "%dx %s" % [alive, d.unit_display()]
			if _allure.is_restless(id):
				label += " (LEAVING!)"
				restless = true
			names.append(label)
		minion_text = "Anti-Heroes: " + ", ".join(names)
		if restless:
			minion_col = Color(1.0, 0.45, 0.3)

	_hud.refresh(phase == Phase.BUILD, _can_build(), wave_index, wave_text, minion_text, minion_col)
