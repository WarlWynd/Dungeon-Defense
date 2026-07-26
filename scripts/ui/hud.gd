extends CanvasLayer
class_name Hud

## All UI. Anchored (not absolute pixels) so it reflows on rotation.

signal unleash_pressed()
signal pause_pressed()
signal speed_step_pressed(delta: int)
signal trap_selected(id: String)
signal board_step_pressed(delta: int)
signal trap_slots_changed()
signal antihero_selected(unit: Node2D)
signal trap_sell_pressed(trap: Node2D)
signal trap_upgrade_pressed(trap: Node2D)
signal store_recruit(id: String, currency: String)
signal store_buy_gold()
signal store_buy_souls()
signal store_get_pack(pack_id: String)
signal store_watch_ad()
signal profile_play(index: int)
signal profile_new(index: int)
signal profile_erase(index: int)

var _root: Control
var _hoard_bar: Control
var _wave_label: Label
var _minion_label: Label
var _toast: Label
var _msg_label: RichTextLabel
var _tray: HBoxContainer
var _unleash_btn: Button
var _pause_btn: Button
var _pause_icon: Control
var _pause_scrim: ColorRect
var _paused_state: bool = false
var _speed_label: Label

var _bestiary: Bestiary
var _inspector: Inspector
var _settings_panel: Control
var _settings_tabs: TabContainer
var _profile_box: VBoxContainer

## Simulated rewarded ad.
var _ad_panel: Control
var _ad_countdown: Label
var _ad_progress: Control
var _ad_claim: Button
var _ad_time: float = 0.0
const AD_SECONDS := 5.0
var _slots_label: Label
var _slots_title: Label
var _board_label: Label

## Labels whose colour comes from the palette rather than a fixed value, and the
## procedurally-drawn glyphs that read Settings.scheme() at draw time. Both are
## refreshed by _apply_scheme() when the player picks a new palette.
var _accent_labels: Array[Label] = []
var _dim_labels: Array[Label] = []
var _themed_icons: Array[Control] = []
var _scheme_buttons: Array[Button] = []

var _wave_index: int = 0
var _preview_cost: int = 0
var _toast_timer: float = 0.0

var _roster_box: VBoxContainer
var _roster_rows: Dictionary = {}   ## instance_id -> {"btn": Button, "unit": Node}
var _roster_sig: String = ""
var _roster_balance: Label
var _gems_label: Label

var _store_panel: Control
var _store_box: VBoxContainer
var _store_balance: Label
var _store_souls_label: Label
var _store_gems_label: Label

## Which creature stands for the Bestiary. One glyph only — change this number to
## swap it. 0 = horned skull, 1 = goblin, 2 = dragon.
const BESTIARY_GLYPH := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_apply_scheme()


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast.text = ""
	if _store_panel != null and _store_panel.visible:
		_update_store_balance()
	if _ad_panel != null and _ad_panel.visible:
		_tick_ad(delta)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	## Dims the DUNGEON while paused so a paused game reads as paused at a glance,
	## not just from one line of text. Added FIRST so every HUD element still draws
	## at full brightness on top of it — only the board behind the layer goes dark,
	## and it stays visible through the scrim rather than being covered.
	_pause_scrim = ColorRect.new()
	_pause_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_scrim.color = Color(0.0, 0.0, 0.0, 0.45)
	_pause_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_scrim.visible = false
	_root.add_child(_pause_scrim)

	var controls := HBoxContainer.new()
	controls.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	controls.offset_left = -530
	controls.offset_right = -16
	controls.offset_top = 12
	controls.offset_bottom = 56
	controls.alignment = BoxContainer.ALIGNMENT_END   ## keep the row flush to the right edge
	controls.add_theme_constant_override("separation", 8)
	_root.add_child(controls)

	_unleash_btn = Button.new()
	_unleash_btn.custom_minimum_size = Vector2(110, 44)
	_unleash_btn.text = "START"
	_unleash_btn.pressed.connect(func(): unleash_pressed.emit())
	controls.add_child(_unleash_btn)

	var shop_btn := Button.new()
	shop_btn.custom_minimum_size = Vector2(44, 44)
	shop_btn.tooltip_text = "Store"
	shop_btn.pressed.connect(_toggle_store)
	controls.add_child(shop_btn)
	var shop_icon := Control.new()
	shop_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_icon.draw.connect(_draw_present_icon.bind(shop_icon))
	shop_btn.add_child(shop_icon)
	_themed_icons.append(shop_icon)

	var gear_btn := Button.new()
	gear_btn.custom_minimum_size = Vector2(44, 44)
	gear_btn.tooltip_text = "Settings"
	gear_btn.pressed.connect(_toggle_settings)
	controls.add_child(gear_btn)
	var gear_icon := Control.new()
	gear_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	gear_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear_icon.draw.connect(_draw_gear_icon.bind(gear_icon))
	gear_btn.add_child(gear_icon)
	_themed_icons.append(gear_icon)

	controls.add_child(_bestiary_button(BESTIARY_GLYPH, "Bestiary"))

	## Speed picker: 1x / 2x / 3x. Clamps at both ends rather than wrapping, so
	## holding the arrow can't drop you from 3x back to 1x mid-wave.
	var speed_spin := HBoxContainer.new()
	speed_spin.add_theme_constant_override("separation", 2)
	controls.add_child(speed_spin)

	_speed_label = Label.new()
	_speed_label.custom_minimum_size = Vector2(30, 44)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_speed_label.add_theme_font_size_override("font_size", 18)
	_speed_label.text = "1x"
	_speed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_spin.add_child(_speed_label)

	var speed_arrows := VBoxContainer.new()
	speed_arrows.add_theme_constant_override("separation", 2)
	speed_spin.add_child(speed_arrows)
	speed_arrows.add_child(_arrow_button(true, "Faster", _step_speed))
	speed_arrows.add_child(_arrow_button(false, "Slower", _step_speed))

	_pause_btn = Button.new()
	_pause_btn.custom_minimum_size = Vector2(48, 44)
	_pause_btn.tooltip_text = "Pause / Resume"
	_pause_btn.pressed.connect(func(): pause_pressed.emit())
	controls.add_child(_pause_btn)
	_pause_icon = Control.new()
	_pause_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_icon.draw.connect(_draw_pause_icon.bind(_pause_icon))
	_pause_btn.add_child(_pause_icon)
	_themed_icons.append(_pause_icon)

	## Board picker: the number is the board you're on, arrows step through the
	## ones we have. Wraps at both ends, so you can browse in either direction.
	## Sits bottom-left, just ahead of the hoard bar.
	var board_spin := HBoxContainer.new()
	board_spin.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	board_spin.offset_left = 12
	board_spin.offset_right = 66
	board_spin.offset_top = -62
	board_spin.offset_bottom = -18
	board_spin.add_theme_constant_override("separation", 2)
	_root.add_child(board_spin)

	_board_label = Label.new()
	_board_label.custom_minimum_size = Vector2(28, 44)
	_board_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_board_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_board_label.add_theme_font_size_override("font_size", 20)
	_board_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_spin.add_child(_board_label)

	var arrows := VBoxContainer.new()
	arrows.add_theme_constant_override("separation", 2)
	board_spin.add_child(arrows)
	arrows.add_child(_arrow_button(true, "Next board", _step_board))
	arrows.add_child(_arrow_button(false, "Previous board", _step_board))

	_refresh_board_label()

	_hoard_bar = HoardBar.new()
	_hoard_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hoard_bar.offset_left = 78          ## clear of the board picker to its left
	_hoard_bar.offset_right = -470   ## leave the bottom-right for the trap tray
	_hoard_bar.offset_top = -68
	_hoard_bar.offset_bottom = -12
	## PASS, not IGNORE: the bar has to see the pointer to answer a tooltip, but
	## must not swallow the click — PASS leaves it to fall through to the board.
	_hoard_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	_hoard_bar.draw.connect(_draw_hoard_bar)
	(_hoard_bar as HoardBar).tick_pressed.connect(_on_hoard_tick_pressed)
	_root.add_child(_hoard_bar)

	## Primary status line and the toast under it both track the palette — the
	## colors passed here are only what shows before _apply_scheme() first runs.
	_wave_label = _label(20, 18, 19, Color(0.9, 0.9, 0.9))
	_accent_labels.append(_wave_label)
	_toast = _label(20, 70, 18, Color(1.0, 0.85, 0.3))
	_accent_labels.append(_toast)

	_build_roster_panel()

	## Centre-screen banner. A RichTextLabel rather than a Label so one message can
	## carry more than one colour — the win summary greens the Gold you kept and
	## reds what walked out. RichTextLabel can't centre itself vertically, hence
	## the CenterContainer wrapper.
	var msg_holder := CenterContainer.new()
	msg_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	msg_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(msg_holder)

	_msg_label = RichTextLabel.new()
	_msg_label.bbcode_enabled = true
	_msg_label.fit_content = true
	_msg_label.scroll_active = false
	_msg_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_msg_label.add_theme_font_size_override("normal_font_size", 40)
	_msg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg_holder.add_child(_msg_label)

	_inspector = Inspector.new()
	_inspector.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_inspector.offset_left = 12
	_inspector.offset_right = 280
	_inspector.offset_top = -300
	_inspector.offset_bottom = -72   ## sit just above the bottom-left hoard bar
	## Relay the inspector's Sell and Upgrade up to main, which owns the economy
	## and the build slots.
	_inspector.sell_requested.connect(func(trap): trap_sell_pressed.emit(trap))
	_inspector.upgrade_requested.connect(func(trap): trap_upgrade_pressed.emit(trap))
	_root.add_child(_inspector)

	_build_settings_panel()
	_build_store_panel()

	_bestiary = Bestiary.new()
	_root.add_child(_bestiary)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_left = 10
	row.offset_right = -10
	row.offset_top = -66
	row.offset_bottom = -8
	row.alignment = BoxContainer.ALIGNMENT_END   ## trap menu + UNLEASH sit bottom-right
	## Spans the full bottom strip but only fills the right end. Without IGNORE the
	## empty left half still swallows clicks meant for the board picker beneath it.
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	_root.add_child(row)

	_tray = HBoxContainer.new()
	_tray.add_theme_constant_override("separation", 8)
	row.add_child(_tray)

	for key in GameData.traps.keys():
		var id: String = key
		var d: TrapData = GameData.traps[id]
		var b := Button.new()
		b.custom_minimum_size = Vector2(58, 58)
		b.toggle_mode = true
		b.tooltip_text = "%s — %s" % [d.display_name, d.flavor]
		b.set_meta("trap_id", id)
		b.pressed.connect(_on_trap_button.bind(id))

		## Icon on top (the trap's in-game glyph), cost underneath.
		var col := VBoxContainer.new()
		col.set_anchors_preset(Control.PRESET_FULL_RECT)
		col.add_theme_constant_override("separation", 0)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(col)

		if d.icon != null:
			## Real art assigned — show the sprite.
			var tex := TextureRect.new()
			tex.texture = d.icon
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.custom_minimum_size = Vector2(0, 38)
			tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
			tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(tex)
		else:
			## Placeholder — draw the trap's in-game glyph.
			var icon := Control.new()
			icon.custom_minimum_size = Vector2(0, 38)
			icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.draw.connect(_draw_trap_icon.bind(icon, d))
			col.add_child(icon)

		## Cost as the number and the gold coin, centred under the trap glyph — the
		## same coin the Store uses. Registered so it repaints on a scheme change.
		var cost_row := HBoxContainer.new()
		cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
		cost_row.add_theme_constant_override("separation", 2)
		cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(cost_row)

		var cost := Label.new()
		cost.text = str(d.cost)
		cost.add_theme_font_size_override("font_size", 12)
		cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_row.add_child(cost)

		var coin := Control.new()
		coin.custom_minimum_size = Vector2(14, 14)
		coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.draw.connect(_draw_gold_icon.bind(coin))
		cost_row.add_child(coin)
		_themed_icons.append(coin)

		_tray.add_child(b)

	## Built last so it sits above the store, the settings and the bestiary — an ad
	## that something else can draw over isn't standing in for anything.
	_build_ad_panel()


## Left-side list of the Anti-Heroes currently drawn to your hoard. Click a row
## to select that unit; the next tap on the field posts it there (see main._tap).
func _build_roster_panel() -> void:
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 12
	panel.offset_right = 200
	panel.offset_top = 106
	panel.offset_bottom = -310   ## stop above the bottom-left inspector panel
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vb)

	var title := Label.new()
	title.text = "ANTI-HEROES"
	title.add_theme_font_size_override("font_size", 14)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(title)
	_accent_labels.append(title)

	## Souls and Gems as glyph+count pairs — no words. Both track the ANTI-HEROES
	## heading colour, and both glyphs persist (this panel is built once and lives
	## for the session, so they need repainting when the scheme changes).
	var bal_row := HBoxContainer.new()
	bal_row.add_theme_constant_override("separation", 12)
	bal_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(bal_row)
	_roster_balance = _balance_group(bal_row, _draw_soul_icon, 12, true, true)
	_gems_label = _balance_group(bal_row, _draw_gem_icon, 12, true, true)

	## Scrollable list, so a long roster scrolls instead of overflowing.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)

	_roster_box = VBoxContainer.new()
	_roster_box.add_theme_constant_override("separation", 4)
	_roster_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_roster_box)


## Rebuild the roster only when the set of live units changes; refresh HP and the
## selection highlight every frame. `selected` is the currently inspected unit.
func _update_roster(selected) -> void:
	## `selected` may be a freed unit (it just died) — untyped param + this guard
	## avoids a type-check crash on the dangling reference.
	if not is_instance_valid(selected):
		selected = null
	if _roster_box == null:
		return
	if _roster_balance != null:
		_roster_balance.text = str(Bank.souls)
	if _gems_label != null:
		_gems_label.text = str(Bank.gems)
	var units: Array = []
	for n in get_tree().get_nodes_in_group("minions"):
		if is_instance_valid(n):
			units.append(n)

	var sig := ""
	for u in units:
		sig += str(u.get_instance_id()) + ","
	if sig != _roster_sig:
		_rebuild_roster(units)
		_roster_sig = sig

	for key in _roster_rows.keys():
		var row: Dictionary = _roster_rows[key]
		var u = row["unit"]
		if not is_instance_valid(u) or u.data == null:
			continue
		var btn: Button = row["btn"]
		var tag := "  (LEAVING!)" if u.restless else ""
		btn.text = "%s   %d/%d%s" % [u.data.unit_display(), int(round(u.hp)), int(u.data.max_hp), tag]
		btn.button_pressed = (u == selected)


func _rebuild_roster(units: Array) -> void:
	for c in _roster_box.get_children():
		c.queue_free()
	_roster_rows.clear()
	for u in units:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(170, 36)
		btn.clip_text = true
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_on_roster_click.bind(u))
		_roster_box.add_child(btn)
		_roster_rows[u.get_instance_id()] = {"btn": btn, "unit": u}


func _on_roster_click(unit: Node) -> void:
	if is_instance_valid(unit):
		antihero_selected.emit(unit)


## Modal store: recruit Anti-Heroes (souls or gems), spend gems on Gold/Souls,
## and get gems from rewarded ads or cash packs (both stubbed for testing).
func _build_store_panel() -> void:
	_store_panel = Control.new()
	_store_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_store_panel.visible = false
	_root.add_child(_store_panel)

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0, 0, 0, 0.7)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
				_toggle_store())
	_store_panel.add_child(scrim)

	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -220
	frame.offset_right = 220
	frame.offset_top = -300
	frame.offset_bottom = 300
	_store_panel.add_child(frame)

	var scroll := ScrollContainer.new()
	frame.add_child(scroll)

	_store_box = VBoxContainer.new()
	_store_box.custom_minimum_size = Vector2(410, 0)
	_store_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_store_box)


## A SIMULATED rewarded ad. The real thing is an SDK that takes the screen for a
## few seconds and calls back when the video finishes; this stands in for it so
## the whole flow can be played and tested before any SDK exists — including the
## path that matters most, the player quitting early and getting NOTHING. Swap
## the body of Bank.watch_ad_for_gems() for the SDK call and keep this panel as
## the editor-only fallback, or delete it and let the SDK own the screen.
func _build_ad_panel() -> void:
	_ad_panel = Control.new()
	_ad_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ad_panel.visible = false
	_root.add_child(_ad_panel)

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0, 0, 0, 0.88)
	## STOP, and deliberately NOT click-to-close: an ad you can dismiss by tapping
	## the backdrop doesn't test the thing it exists to test.
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_ad_panel.add_child(scrim)

	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -190
	frame.offset_right = 190
	frame.offset_top = -200
	frame.offset_bottom = 200
	_ad_panel.add_child(frame)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	frame.add_child(box)

	var header := _section_header("ADVERTISEMENT")
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(header)

	var art := Control.new()
	art.custom_minimum_size = Vector2(0, 150)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(_draw_ad_art.bind(art))
	box.add_child(art)

	var pitch := Label.new()
	pitch.text = "GEM QUEST SAGA"
	pitch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pitch.add_theme_font_size_override("font_size", 20)
	box.add_child(pitch)
	_accent_labels.append(pitch)

	box.add_child(_note_label("Three billion players can't be wrong. Probably."))

	_ad_countdown = Label.new()
	_ad_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ad_countdown.add_theme_font_size_override("font_size", 14)
	box.add_child(_ad_countdown)

	_ad_progress = Control.new()
	_ad_progress.custom_minimum_size = Vector2(0, 8)
	_ad_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ad_progress.draw.connect(_draw_ad_progress)
	box.add_child(_ad_progress)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)

	## SKIP is live from the first frame, exactly like a real rewarded ad: leaving
	## early is allowed, and it costs you the reward.
	var skip := Button.new()
	skip.text = "SKIP"
	skip.custom_minimum_size = Vector2(110, 42)
	skip.pressed.connect(_close_ad.bind(false))
	row.add_child(skip)

	_ad_claim = _icon_button(["CLAIM  +%d" % Bank.AD_REWARD_GEMS, _draw_gem_icon], true)
	_ad_claim.custom_minimum_size = Vector2(0, 42)
	_ad_claim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ad_claim.pressed.connect(_close_ad.bind(true))
	row.add_child(_ad_claim)


## _icon_button dims its contents at BUILD time, so flipping `disabled` later has
## to re-dim the row it made — that row is the button's only child.
func _set_ad_claim_enabled(on: bool) -> void:
	_ad_claim.disabled = not on
	var row := _ad_claim.get_child(0) as Control
	if row != null:
		row.modulate = Color(1, 1, 1, 1) if on else Color(1, 1, 1, 0.4)


func _open_ad() -> void:
	_ad_time = AD_SECONDS
	_set_ad_claim_enabled(false)
	_ad_countdown.text = "Reward in %ds" % int(AD_SECONDS)
	_ad_panel.visible = true
	_ad_progress.queue_redraw()


func _close_ad(claimed: bool) -> void:
	_ad_panel.visible = false
	if claimed:
		store_watch_ad.emit()
	else:
		say("Ad skipped — no gems.")


func _tick_ad(delta: float) -> void:
	if _ad_time <= 0.0:
		return
	## REAL seconds. The game's 2x/3x speed scales delta, and an ad that finishes
	## in a third of the time because the player left the game fast-forwarded is
	## not an ad worth simulating.
	_ad_time = maxf(0.0, _ad_time - delta / maxf(Engine.time_scale, 0.001))
	if _ad_time > 0.0:
		_ad_countdown.text = "Reward in %ds" % ceili(_ad_time)
	else:
		_ad_countdown.text = "Reward unlocked"
		_set_ad_claim_enabled(true)
	_ad_progress.queue_redraw()


func _draw_ad_progress() -> void:
	var s: ColorScheme = Settings.scheme()
	var sz := _ad_progress.size
	if sz.x <= 0.0:
		return
	_ad_progress.draw_rect(Rect2(Vector2.ZERO, sz), Color(s.text, 0.18))
	var pct := 1.0 - clampf(_ad_time / AD_SECONDS, 0.0, 1.0)
	_ad_progress.draw_rect(Rect2(Vector2.ZERO, Vector2(sz.x * pct, sz.y)), s.accent)


## Stand-in ad artwork: an oversized gem with the accent glinting off it. Drawn
## rather than shipped as an image so it costs nothing and follows the palette.
func _draw_ad_art(icon: Control) -> void:
	var s: ColorScheme = Settings.scheme()
	var ctr := icon.size * 0.5
	var body := Color(0.35, 0.62, 1.0)
	var facet := body.darkened(0.4)
	var k := 6.0                       ## scale-up of the HUD's little gem glyph
	var table_l := ctr + Vector2(-3.5, -5.5) * k
	var table_r := ctr + Vector2(3.5, -5.5) * k
	var giro_l := ctr + Vector2(-6.0, -1.5) * k
	var giro_r := ctr + Vector2(6.0, -1.5) * k
	var tip := ctr + Vector2(0.0, 6.5) * k
	icon.draw_colored_polygon(PackedVector2Array([table_l, table_r, giro_r, tip, giro_l]), body)
	icon.draw_line(table_l, giro_l, facet, 2.0)
	icon.draw_line(table_r, giro_r, facet, 2.0)
	icon.draw_line(giro_l, giro_r, facet, 2.0)
	icon.draw_line(giro_l, tip, facet, 2.0)
	icon.draw_line(giro_r, tip, facet, 2.0)
	icon.draw_line(table_l, tip, facet, 1.5)
	icon.draw_line(table_r, tip, facet, 1.5)
	## Sparkles — four-pointed stars around the stone.
	for p: Vector2 in [Vector2(-52, -34), Vector2(48, -20), Vector2(-38, 30), Vector2(56, 34)]:
		var c := ctr + p
		var r := 7.0
		icon.draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), s.accent, 2.0)
		icon.draw_line(c + Vector2(0, -r), c + Vector2(0, r), s.accent, 2.0)


## A mark on the hoard bar is the one place an Anti-Hero is named before you own
## it — so clicking it opens its page, whether it's standing in your dungeon or
## still a number you're saving toward.
func _on_hoard_tick_pressed(id: String) -> void:
	if _store_panel != null and _store_panel.visible:
		_toggle_store()
	if _settings_panel != null and _settings_panel.visible:
		_toggle_settings()
	_bestiary.open_minion(id, _wave_index)


func _toggle_store() -> void:
	if _store_panel == null:
		return
	_store_panel.visible = not _store_panel.visible
	if _store_panel.visible:
		refresh_store()


func _update_store_balance() -> void:
	if _store_balance != null:
		_store_balance.text = str(EconomySystem.hoard)
	if _store_souls_label != null:
		_store_souls_label.text = str(Bank.souls)
	if _store_gems_label != null:
		_store_gems_label.text = str(Bank.gems)


## Rebuild the whole store: recruit rows reflect current ownership/affordability,
## then the Gem sinks, then the Gem sources.
func refresh_store() -> void:
	if _store_box == null:
		return
	for c in _store_box.get_children():
		c.queue_free()

	var title := Label.new()
	title.text = "STORE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Settings.scheme().accent)
	_store_box.add_child(title)

	## Gold, Souls, Gems as glyph+count pairs, centred as one group. These icons are
	## thrown away and rebuilt every time the store opens, so they draw with the
	## live accent and skip _themed_icons registration.
	var bal_row := HBoxContainer.new()
	bal_row.add_theme_constant_override("separation", 12)
	bal_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_store_box.add_child(bal_row)
	_store_balance = _balance_group(bal_row, _draw_gold_icon, 15, false, false)
	_store_souls_label = _balance_group(bal_row, _draw_soul_icon, 15, false, false)
	_store_gems_label = _balance_group(bal_row, _draw_gem_icon, 15, false, false)
	_update_store_balance()

	_store_box.add_child(_section_header("Recruit Anti-Heroes"))
	for key in GameData.minions.keys():
		var id: String = key
		var d: MinionData = GameData.minions[id]
		## Owned first: an unlocked unit is recruited whatever its acquire mode, and
		## telling a player who just bought a Troll that it's "drawn out by a hoard
		## of 1300" would be describing the route they paid to skip.
		if Bank.is_unlocked(id):
			_store_box.add_child(_info_row("%s — recruited" % d.display_name))
		elif d.acquire_mode == "auto":
			_store_box.add_child(_info_row("%s — drawn out by a hoard of %d Gold" % [
					d.display_name, int(d.allure_arrive)]))
		elif d.acquire_mode == "earn":
			_store_box.add_child(_info_row("%s — earn by clearing wave %d" % [d.display_name, d.unlock_wave]))
		else:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var lbl := Label.new()
			lbl.text = d.display_name
			lbl.custom_minimum_size = Vector2(150, 0)
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(lbl)
			var sbtn := _icon_button(["%d" % d.recruit_souls, _draw_soul_icon],
					not Bank.can_afford_souls(d.recruit_souls))
			sbtn.pressed.connect(store_recruit.emit.bind(id, "souls"))
			row.add_child(sbtn)
			var gbtn := _icon_button(["%d" % d.recruit_gems, _draw_gem_icon],
					not Bank.can_afford_gems(d.recruit_gems))
			gbtn.pressed.connect(store_recruit.emit.bind(id, "gems"))
			row.add_child(gbtn)
			_store_box.add_child(row)

	_store_box.add_child(_section_header("Spend Gems"))
	## Anti-Heroes you would otherwise have to WAIT for — clear the wave, or grow
	## the hoard to their number. Gems buy the wait, and buy permanence with it.
	## The Wraith isn't here: it's soul-priced, so it keeps its two-currency row up
	## in Recruit rather than being offered twice.
	for key in GameData.minions.keys():
		var id: String = key
		var d: MinionData = GameData.minions[id]
		if d.recruit_gems <= 0 or d.acquire_mode == "buy" or Bank.is_unlocked(id):
			continue
		var mbtn := _icon_button(["%s  —  %d" % [d.display_name, d.recruit_gems], _draw_gem_icon],
				not Bank.can_afford_gems(d.recruit_gems))
		mbtn.pressed.connect(store_recruit.emit.bind(id, "gems"))
		_store_box.add_child(mbtn)

	## "+250 [coin]  —  8 [gem]": buy Gold with Gems. Both amounts are glyphs.
	var goldbtn := _icon_button(["+%d" % Bank.GOLD_REFILL, _draw_gold_icon,
			"  —  %d" % Bank.GEM_GOLD_COST, _draw_gem_icon],
			not Bank.can_afford_gems(Bank.GEM_GOLD_COST))
	goldbtn.pressed.connect(store_buy_gold.emit)
	_store_box.add_child(goldbtn)
	var soulbtn := _icon_button(["+%d" % Bank.SOULS_PACK, _draw_soul_icon,
			"  —  %d" % Bank.GEM_SOULS_COST, _draw_gem_icon],
			not Bank.can_afford_gems(Bank.GEM_SOULS_COST))
	soulbtn.pressed.connect(store_buy_souls.emit)
	_store_box.add_child(soulbtn)

	_store_box.add_child(_section_header("Get Gems"))
	## Gems as the REWARD here, not a price — the ad's amount ends the line, the
	## packs' amount sits mid-line before the money price.
	## Opens the ad; the gems are granted by its CLAIM button, not by this one.
	var adbtn := _icon_button(["Watch Ad  —  +%d" % Bank.AD_REWARD_GEMS, _draw_gem_icon], false)
	adbtn.pressed.connect(_open_ad)
	_store_box.add_child(adbtn)
	for pack_key in Bank.GEM_PACKS.keys():
		var pack_id: String = pack_key
		var pack: Dictionary = Bank.GEM_PACKS[pack_id]
		var pbtn := _icon_button(["%d" % int(pack["gems"]), _draw_gem_icon, "  —  %s" % pack["price"]], false)
		pbtn.pressed.connect(store_get_pack.emit.bind(pack_id))
		_store_box.add_child(pbtn)

	var note := Label.new()
	note.text = "Purchases and ads are stubbed for testing — no real charge."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Settings.scheme().dim)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_store_box.add_child(note)

	var close := Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(_toggle_store)
	_store_box.add_child(close)


## Build a store button from an ordered mix of text and currency glyphs. A String
## segment becomes a label; a Callable segment becomes a small icon drawn by that
## handler (_draw_gold_icon / _draw_soul_icon / _draw_gem_icon). Lets one button
## read "+100 [soul]  —  8 [gem]". Content rides inside the button with the mouse
## ignored, so the whole thing stays one tap target — the same trick the trap tray
## and roster rows use.
func _icon_button(segments: Array, disabled: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 34)
	b.disabled = disabled

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Child Labels can't read the Button's disabled font colour, so dim the whole
	## row (text + glyphs) to match a greyed-out button.
	if disabled:
		row.modulate = Color(1.0, 1.0, 1.0, 0.4)
	b.add_child(row)

	for seg in segments:
		if seg is String:
			row.add_child(_icon_button_label(seg))
		else:
			var ic := Control.new()
			ic.custom_minimum_size = Vector2(14, 16)
			ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ic.draw.connect((seg as Callable).bind(ic))
			row.add_child(ic)
	return b


func _icon_button_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A [glyph][count] pair for the balance readouts. `draw_fn` is the glyph's draw
## handler; `font` sizes the count; `accent` makes the count follow the accent
## palette (roster) rather than the default text colour (store); `persist` adds
## the glyph to _themed_icons so a long-lived panel repaints on a scheme change —
## the store rebuilds itself each open, so it passes false. Returns the count
## Label for the caller to keep updating.
func _balance_group(parent: Control, draw_fn: Callable, font: int, accent: bool, persist: bool) -> Label:
	var g := HBoxContainer.new()
	g.add_theme_constant_override("separation", 3)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(g)

	var ic := Control.new()
	ic.custom_minimum_size = Vector2(14, 16)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.draw.connect(draw_fn.bind(ic))
	g.add_child(ic)
	if persist:
		_themed_icons.append(ic)

	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", font)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.add_child(lbl)
	if accent:
		_accent_labels.append(lbl)
	return lbl


func _section_header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Settings.scheme().accent)
	return l


func _info_row(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Settings.scheme().dim)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Modal settings, split into tabs. Each tab is one VBoxContainer whose NODE NAME
## becomes the tab title — add a tab by adding a child here.
func _build_settings_panel() -> void:
	_settings_panel = Control.new()
	_settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_panel.visible = false
	_root.add_child(_settings_panel)

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0, 0, 0, 0.7)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
				_toggle_settings())
	_settings_panel.add_child(scrim)

	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -240
	frame.offset_right = 240
	frame.offset_top = -250
	frame.offset_bottom = 250
	_settings_panel.add_child(frame)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	frame.add_child(box)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	_accent_labels.append(title)

	_settings_tabs = TabContainer.new()
	_settings_tabs.custom_minimum_size = Vector2(450, 390)
	_settings_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_settings_tabs)

	## Appearance first: it's the tab people open Settings for, and the board's
	## trap-slot count is a per-board tweak you go looking for deliberately.
	_settings_tabs.add_child(_build_appearance_tab())
	_settings_tabs.add_child(_build_board_tab())
	_settings_tabs.add_child(_build_player_tab())

	var done := Button.new()
	done.text = "DONE"
	done.custom_minimum_size = Vector2(0, 44)
	done.pressed.connect(_toggle_settings)
	box.add_child(done)

	_refresh_slots_label()


## Tab 2 — per-board build settings.
func _build_board_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "Board"
	tab.add_theme_constant_override("separation", 14)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	tab.add_child(spacer)

	_slots_title = Label.new()
	_slots_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slots_title.add_theme_font_size_override("font_size", 16)
	tab.add_child(_slots_title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	tab.add_child(row)

	var minus := Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(60, 56)
	minus.pressed.connect(func(): _nudge_slots(-1))
	row.add_child(minus)

	_slots_label = Label.new()
	_slots_label.custom_minimum_size = Vector2(80, 56)
	_slots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slots_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_slots_label.add_theme_font_size_override("font_size", 30)
	row.add_child(_slots_label)

	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(60, 56)
	plus.pressed.connect(func(): _nudge_slots(1))
	row.add_child(plus)

	tab.add_child(_note_label("Saved automatically. Applies on this board now."))
	return tab


## Tab 3 — save slots. Souls, gems and recruited Anti-Heroes are ONE character's
## progress, so a slot is a whole character: start a new one, or go back to a
## saved one. Colour scheme and trap-slot counts are not part of it — those are
## preferences about the app, not about the player.
func _build_player_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "Player"
	tab.add_theme_constant_override("separation", 8)

	var heading := Label.new()
	heading.text = "Characters"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 16)
	tab.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)

	_profile_box = VBoxContainer.new()
	_profile_box.custom_minimum_size = Vector2(410, 0)
	_profile_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_profile_box)

	tab.add_child(_note_label(
			"A character keeps its souls, gems and recruited Anti-Heroes. Your dungeon settings are shared by all of them."))
	_refresh_profiles()
	return tab


## Rebuilt whole rather than patched: a slot's row changes shape entirely between
## empty and occupied, and there are only three of them.
func _refresh_profiles() -> void:
	if _profile_box == null:
		return
	for c in _profile_box.get_children():
		c.queue_free()

	var s: ColorScheme = Settings.scheme()
	for i in Bank.PROFILE_COUNT:
		var info := Bank.profile_summary(i)
		var active: bool = i == Bank.profile
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_profile_box.add_child(row)

		var name_lbl := Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 14)
		if info["exists"]:
			name_lbl.text = "Character %d\n%d souls · %d gems · %d recruited" % [
					i + 1, info["souls"], info["gems"], info["unlocked"]]
		else:
			name_lbl.text = "Character %d\nempty" % (i + 1)
		name_lbl.add_theme_color_override("font_color", s.accent if active else s.text)
		row.add_child(name_lbl)

		## The active slot can't be "played" again — that button becomes its badge.
		if active:
			var badge := Label.new()
			badge.text = "PLAYING"
			badge.custom_minimum_size = Vector2(84, 44)
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			badge.add_theme_font_size_override("font_size", 13)
			badge.add_theme_color_override("font_color", s.accent)
			row.add_child(badge)
		elif info["exists"]:
			var play := Button.new()
			play.text = "PLAY"
			play.custom_minimum_size = Vector2(84, 44)
			play.pressed.connect(func(): profile_play.emit(i))
			row.add_child(play)
		else:
			var fresh := Button.new()
			fresh.text = "NEW"
			fresh.custom_minimum_size = Vector2(84, 44)
			fresh.pressed.connect(func(): profile_new.emit(i))
			row.add_child(fresh)

		## Erase doubles as "start this one over", so an occupied slot is never a
		## dead end once all three are full.
		var erase := Button.new()
		erase.text = "ERASE"
		erase.custom_minimum_size = Vector2(76, 44)
		erase.disabled = not info["exists"]
		erase.pressed.connect(func(): profile_erase.emit(i))
		row.add_child(erase)


## Tab 1 — palette picker. One toggle per ColorScheme, showing the palette's own
## colors as a swatch strip so you can see the scheme before you commit to it.
func _build_appearance_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "Appearance"
	tab.add_theme_constant_override("separation", 8)

	var heading := Label.new()
	heading.text = "Color scheme"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 16)
	tab.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	## One ButtonGroup keeps the picker single-choice — selecting a scheme
	## releases the previous one for free.
	var group := ButtonGroup.new()
	_scheme_buttons.clear()
	for i in ColorScheme.count():
		var s: ColorScheme = ColorScheme.get_scheme(i)
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_group = group
		btn.custom_minimum_size = Vector2(200, 66)
		btn.tooltip_text = s.display_name
		btn.pressed.connect(_on_scheme_picked.bind(i))

		var col := VBoxContainer.new()
		col.set_anchors_preset(Control.PRESET_FULL_RECT)
		col.offset_left = 6
		col.offset_right = -6
		col.offset_top = 6
		col.offset_bottom = -6
		col.add_theme_constant_override("separation", 4)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(col)

		var swatch := Control.new()
		swatch.custom_minimum_size = Vector2(0, 20)
		swatch.size_flags_vertical = Control.SIZE_EXPAND_FILL
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.draw.connect(_draw_swatch.bind(swatch, s))
		col.add_child(swatch)

		var name_lbl := Label.new()
		name_lbl.text = s.display_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(name_lbl)

		grid.add_child(btn)
		_scheme_buttons.append(btn)

	tab.add_child(_note_label("Repaints the dungeon and the HUD. Saved automatically."))
	return tab


## The palette's four defining colors as vertical bars — accent, stone, floor, panel.
func _draw_swatch(swatch: Control, s: ColorScheme) -> void:
	var bars: Array[Color] = [s.accent, s.stone, s.floor_col, s.panel]
	var w: float = swatch.size.x / float(bars.size())
	for i in bars.size():
		swatch.draw_rect(Rect2(Vector2(w * float(i), 0.0), Vector2(w, swatch.size.y)), bars[i])
	swatch.draw_rect(Rect2(Vector2.ZERO, swatch.size), s.text, false, 1.0)


func _note_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 12)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dim_labels.append(l)
	return l


func _on_scheme_picked(index: int) -> void:
	Settings.set_color_scheme(index)
	_apply_scheme()


## Rebuild the UI Theme from the active palette and repaint everything that
## caches a color. The board repaints itself — it reads Settings.scheme() live.
func _apply_scheme() -> void:
	var s: ColorScheme = Settings.scheme()
	_root.theme = _make_theme(s)
	for l in _accent_labels:
		if is_instance_valid(l):
			l.add_theme_color_override("font_color", s.accent)
	for l in _dim_labels:
		if is_instance_valid(l):
			l.add_theme_color_override("font_color", s.dim)
	for icon in _themed_icons:
		if is_instance_valid(icon):
			icon.queue_redraw()
	for i in _scheme_buttons.size():
		if is_instance_valid(_scheme_buttons[i]):
			_scheme_buttons[i].button_pressed = (i == Settings.get_color_scheme())
	## RichTextLabel reads "default_color", not the Theme's Label font_color, so the
	## banner needs its own override to follow the palette.
	if _msg_label != null:
		_msg_label.add_theme_color_override("default_color", s.text)
	if _hoard_bar != null:
		_hoard_bar.queue_redraw()
	if _store_panel != null and _store_panel.visible:
		refresh_store()
	## The Bestiary bakes colours into its rows and its own title/tab labels, so it
	## can't just inherit the new Theme — it has to be told. Same for the save-slot
	## rows, which colour the active character with the accent.
	if _bestiary != null and is_instance_valid(_bestiary):
		_bestiary.apply_scheme()
	_refresh_profiles()


func _make_theme(s: ColorScheme) -> Theme:
	var t := Theme.new()

	t.set_stylebox("normal", "Button", _flat(s.button, s.accent.darkened(0.55)))
	t.set_stylebox("hover", "Button", _flat(s.button_hover, s.accent))
	t.set_stylebox("pressed", "Button", _flat(s.button_pressed, s.accent))
	t.set_stylebox("disabled", "Button", _flat(s.panel.lerp(s.button, 0.4), s.panel))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", s.text)
	t.set_color("font_hover_color", "Button", s.text)
	t.set_color("font_pressed_color", "Button", s.panel)
	t.set_color("font_focus_color", "Button", s.text)
	t.set_color("font_disabled_color", "Button", s.dim)

	t.set_color("font_color", "Label", s.text)
	t.set_stylebox("panel", "PanelContainer", _flat(s.panel, s.accent.darkened(0.45), 12.0))
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())

	t.set_stylebox("panel", "TabContainer", _flat(s.panel.lerp(s.button, 0.5), s.accent.darkened(0.6), 8.0))
	t.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())
	t.set_stylebox("tab_selected", "TabContainer", _flat(s.panel.lerp(s.button, 0.5), s.accent, 8.0))
	t.set_stylebox("tab_unselected", "TabContainer", _flat(s.panel, s.accent.darkened(0.7), 8.0))
	t.set_stylebox("tab_hovered", "TabContainer", _flat(s.button_hover, s.accent, 8.0))
	t.set_color("font_selected_color", "TabContainer", s.accent)
	t.set_color("font_unselected_color", "TabContainer", s.dim)
	t.set_color("font_hovered_color", "TabContainer", s.text)
	return t


func _flat(fill: Color, border: Color, radius: float = 6.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(radius))
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb


func _toggle_settings() -> void:
	_settings_panel.visible = not _settings_panel.visible
	if _settings_panel.visible:
		_refresh_slots_label()
		_refresh_profiles()
		for i in _scheme_buttons.size():
			if is_instance_valid(_scheme_buttons[i]):
				_scheme_buttons[i].button_pressed = (i == Settings.get_color_scheme())


func _nudge_slots(delta: int) -> void:
	var board: String = GameData.board()["name"]
	Settings.set_trap_slots(board, Settings.get_trap_slots(board) + delta)
	_refresh_slots_label()
	trap_slots_changed.emit()


func _refresh_slots_label() -> void:
	var board: String = GameData.board()["name"]
	if _slots_label:
		_slots_label.text = str(Settings.get_trap_slots(board))
	if _slots_title:
		_slots_title.text = "Trap locations on %s" % board


## One half of a spinner. `on_step` is called with +1 (up) or -1 (down).
func _arrow_button(up: bool, tip: String, on_step: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(24, 21)
	btn.tooltip_text = tip
	btn.pressed.connect(func(): on_step.call(1 if up else -1))
	var icon := Control.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(_draw_arrow_icon.bind(icon, up))
	btn.add_child(icon)
	_themed_icons.append(icon)
	return btn


func _step_speed(delta: int) -> void:
	speed_step_pressed.emit(delta)


func _step_board(delta: int) -> void:
	board_step_pressed.emit(delta)
	## Emission is synchronous — the board has already changed by now.
	_refresh_board_label()
	_refresh_slots_label()


func _refresh_board_label() -> void:
	if _board_label == null:
		return
	_board_label.text = str(GameData.active_board + 1)
	_board_label.tooltip_text = "Board %d of %d — %s" % [
		GameData.active_board + 1, GameData.board_count(), GameData.board()["name"]
	]


## Spinner glyph: a small solid triangle, pointing up for next, down for previous.
func _draw_arrow_icon(icon: Control, up: bool) -> void:
	var ctr := icon.size * 0.5
	var col := Settings.scheme().text
	var w := 5.0
	var h := 3.5
	var dy := -h if up else h
	icon.draw_colored_polygon(PackedVector2Array([
		ctr + Vector2(-w, -dy), ctr + Vector2(w, -dy), ctr + Vector2(0.0, dy),
	]), col)


func _label(x: float, y: float, size: int, col: Color) -> Label:
	var l := Label.new()
	l.position = Vector2(x, y)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l


func _on_trap_button(id: String) -> void:
	var d: TrapData = GameData.traps[id]
	_preview_cost = d.cost
	for b in _tray.get_children():
		var btn := b as Button
		btn.button_pressed = btn.get_meta("trap_id") == id
	_hoard_bar.queue_redraw()
	trap_selected.emit(id)


func say(text: String) -> void:
	_toast.text = text
	_toast_timer = 2.2


func set_controls(paused: bool, speed: int) -> void:
	_paused_state = paused
	if _pause_scrim != null:
		_pause_scrim.visible = paused
	if _pause_icon != null:
		_pause_icon.queue_redraw()
	if _speed_label != null:
		_speed_label.text = "%dx" % speed


func _bestiary_button(variant: int, tip: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(44, 44)
	btn.tooltip_text = tip
	btn.pressed.connect(func(): _bestiary.toggle(_wave_index))
	var icon := Control.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(_draw_beast_icon.bind(icon, variant))
	btn.add_child(icon)
	_themed_icons.append(icon)
	return btn


func _draw_beast_icon(icon: Control, variant: int) -> void:
	match variant:
		0: _draw_skull_icon(icon)
		1: _draw_goblin_icon(icon)
		_: _draw_dragon_icon(icon)


## A — horned skull. The monster-manual read: this is a book of dead things.
func _draw_skull_icon(icon: Control) -> void:
	var ctr := icon.size * 0.5
	var bone := Settings.scheme().text
	var dark := Settings.scheme().panel
	for s: float in [-1.0, 1.0]:
		icon.draw_colored_polygon(PackedVector2Array([
			ctr + Vector2(6.0 * s, -4.0),
			ctr + Vector2(11.5 * s, -12.0),
			ctr + Vector2(6.5 * s, -9.0),
		]), bone)
	icon.draw_circle(ctr + Vector2(0.0, -1.5), 7.2, bone)
	icon.draw_rect(Rect2(ctr + Vector2(-4.0, 3.0), Vector2(8.0, 5.5)), bone)
	icon.draw_circle(ctr + Vector2(-2.9, -2.2), 2.3, dark)
	icon.draw_circle(ctr + Vector2(2.9, -2.2), 2.3, dark)
	icon.draw_colored_polygon(PackedVector2Array([
		ctr + Vector2(0.0, 0.4), ctr + Vector2(-1.5, 3.0), ctr + Vector2(1.5, 3.0),
	]), dark)
	for i in 3:
		icon.draw_rect(Rect2(ctr + Vector2(-3.4 + 2.4 * float(i), 4.4), Vector2(1.1, 4.0)), dark)


## B — goblin. Ties the icon to the ally you actually field (the Goblin Pack).
func _draw_goblin_icon(icon: Control) -> void:
	var ctr := icon.size * 0.5
	var skin := Color(0.52, 0.82, 0.40)
	var dark := Color(0.08, 0.14, 0.08)
	for s: float in [-1.0, 1.0]:
		icon.draw_colored_polygon(PackedVector2Array([
			ctr + Vector2(5.0 * s, -3.5),
			ctr + Vector2(13.0 * s, -7.0),
			ctr + Vector2(5.5 * s, 2.0),
		]), skin)
	icon.draw_colored_polygon(PackedVector2Array([
		ctr + Vector2(-7.0, -7.0), ctr + Vector2(7.0, -7.0),
		ctr + Vector2(4.5, 5.5), ctr + Vector2(0.0, 9.5), ctr + Vector2(-4.5, 5.5),
	]), skin)
	icon.draw_circle(ctr + Vector2(-3.0, -2.4), 1.9, dark)
	icon.draw_circle(ctr + Vector2(3.0, -2.4), 1.9, dark)
	icon.draw_line(ctr + Vector2(-3.4, 2.8), ctr + Vector2(3.4, 2.8), dark, 1.6)
	for i in 3:
		icon.draw_rect(Rect2(ctr + Vector2(-2.6 + 2.2 * float(i), 2.8), Vector2(1.0, 2.2)), dark)


## C — dragon. Nods to the Allure "Dragon" playstyle: sit on gold, let it come.
func _draw_dragon_icon(icon: Control) -> void:
	var ctr := icon.size * 0.5
	var hide := Color(0.86, 0.30, 0.34)
	var dark := Color(0.12, 0.07, 0.09)
	var fang := Color(0.97, 0.95, 0.90)
	## Swept-back horn, kept clear of the skull so the silhouette stays readable.
	icon.draw_colored_polygon(PackedVector2Array([
		ctr + Vector2(-4.0, -5.5), ctr + Vector2(-13.0, -10.5), ctr + Vector2(-5.5, -2.5),
	]), hide)
	## Skull and snout, facing right.
	icon.draw_colored_polygon(PackedVector2Array([
		ctr + Vector2(-6.5, -5.0), ctr + Vector2(2.0, -6.5), ctr + Vector2(11.5, -1.5),
		ctr + Vector2(11.0, 1.0), ctr + Vector2(-1.0, 1.5), ctr + Vector2(-6.5, -0.5),
	]), hide)
	## Lower jaw, with a deliberate gap above it — that gap is the open maw.
	icon.draw_colored_polygon(PackedVector2Array([
		ctr + Vector2(-3.5, 3.5), ctr + Vector2(9.5, 3.0), ctr + Vector2(-0.5, 7.5),
	]), hide)
	## Fangs hang from the upper jaw into the gap.
	for i in 3:
		var x := 2.0 + 3.0 * float(i)
		icon.draw_colored_polygon(PackedVector2Array([
			ctr + Vector2(x, 1.2), ctr + Vector2(x + 1.7, 1.2), ctr + Vector2(x + 0.85, 3.4),
		]), fang)
	icon.draw_circle(ctr + Vector2(-1.5, -2.6), 1.7, dark)
	icon.draw_circle(ctr + Vector2(9.0, -1.2), 0.9, dark)


## Store glyph: a wrapped present — box, lid, ribbon, and a bow on top.
func _draw_present_icon(icon: Control) -> void:
	var ctr := icon.size * 0.5
	var box := Settings.scheme().text
	var ribbon := Settings.scheme().accent
	var bx := ctr.x
	var top := ctr.y - 1.0
	icon.draw_rect(Rect2(Vector2(bx - 8.0, top), Vector2(16.0, 10.0)), box)              # body
	icon.draw_rect(Rect2(Vector2(bx - 9.0, top - 3.5), Vector2(18.0, 3.5)), box)         # lid
	icon.draw_rect(Rect2(Vector2(bx - 1.5, top - 3.5), Vector2(3.0, 13.5)), ribbon)      # ribbon
	var by := top - 3.5
	icon.draw_colored_polygon(PackedVector2Array([
		Vector2(bx, by), Vector2(bx - 7.0, by - 6.0), Vector2(bx - 1.0, by - 0.5)
	]), ribbon)
	icon.draw_colored_polygon(PackedVector2Array([
		Vector2(bx, by), Vector2(bx + 7.0, by - 6.0), Vector2(bx + 1.0, by - 0.5)
	]), ribbon)


## Currency glyph: a faceted, downward-pointing cut gem — flat table on top, a
## girdle at its widest, culet at the bottom, with facet lines scored across it
## so it reads as jewel rather than plain diamond. Fixed sapphire blue (NOT the
## palette accent) so the gem keeps one identity across every scheme and stays
## distinct from the accent-tinted Gold and Soul glyphs beside it.
func _draw_gem_icon(icon: Control) -> void:
	var ctr := icon.size * 0.5
	var body := Color(0.35, 0.62, 1.0)
	var facet := body.darkened(0.4)
	var tw := 3.5   ## half-width of the flat top (table)
	var mw := 6.0   ## half-width at the girdle (widest point)
	var ty := -5.5  ## table height
	var gy := -1.5  ## girdle height
	var by := 6.5   ## culet (bottom point)
	var table_l := ctr + Vector2(-tw, ty)
	var table_r := ctr + Vector2(tw, ty)
	var giro_l := ctr + Vector2(-mw, gy)
	var giro_r := ctr + Vector2(mw, gy)
	var tip := ctr + Vector2(0.0, by)
	icon.draw_colored_polygon(PackedVector2Array([table_l, table_r, giro_r, tip, giro_l]), body)
	## Facets: crown edges, the girdle line, and pavilion ridges down to the tip.
	icon.draw_line(table_l, giro_l, facet, 1.0)
	icon.draw_line(table_r, giro_r, facet, 1.0)
	icon.draw_line(giro_l, giro_r, facet, 1.0)
	icon.draw_line(table_l, tip, facet, 1.0)
	icon.draw_line(table_r, tip, facet, 1.0)


## Currency glyph: a soul as a little wisp — a rounded head, a body tapering to a
## wavy hem of three tails, and two hollow eyes. Fixed bright white (NOT the
## palette accent), matching the Gold coin and blue Gem which also hold one colour
## across every scheme. Distinct from the Bestiary skull: this is a spirit, not a
## dead thing. Eyes are cut from a dark ghost-grey so they read as holes on white.
func _draw_soul_icon(icon: Control) -> void:
	var ctr := icon.size * 0.5
	var body := Color(0.97, 0.98, 1.0)
	var hollow := Color(0.20, 0.22, 0.28)
	icon.draw_circle(ctr + Vector2(0.0, -2.0), 5.0, body)              # head
	icon.draw_rect(Rect2(ctr + Vector2(-5.0, -2.0), Vector2(10.0, 6.0)), body)  # body
	for i in 3:                                                        # wavy hem
		icon.draw_circle(ctr + Vector2(-3.4 + 3.4 * float(i), 4.0), 1.7, body)
	icon.draw_circle(ctr + Vector2(-1.9, -2.4), 1.2, hollow)          # eyes
	icon.draw_circle(ctr + Vector2(1.9, -2.4), 1.2, hollow)


## Currency glyph: a gold coin — a rimmed disc with an inner ring and a minted
## highlight. Fixed gold (NOT the palette accent) so the coin always reads as gold
## and stays distinct from the accent-tinted Soul glyph and the blue Gem.
func _draw_gold_icon(icon: Control) -> void:
	var ctr := icon.size * 0.5
	var body := Color(1.0, 0.82, 0.22)
	var rim := body.darkened(0.4)
	icon.draw_circle(ctr, 7.0, rim)
	icon.draw_circle(ctr, 5.8, body)
	icon.draw_arc(ctr, 4.0, 0.0, TAU, 20, rim, 1.0)
	icon.draw_circle(ctr + Vector2(-1.8, -1.8), 1.5, body.lightened(0.4))


## Settings glyph: a simple gear — radial teeth, a ring body, and a center axle.
func _draw_gear_icon(icon: Control) -> void:
	var ctr := icon.size * 0.5
	var col := Settings.scheme().text
	var teeth := 8
	var r_in := 5.5
	var r_out := 9.5
	for i in teeth:
		var ang := TAU * float(i) / float(teeth)
		var dir := Vector2(cos(ang), sin(ang))
		icon.draw_line(ctr + dir * (r_in - 1.0), ctr + dir * r_out, col, 3.5)
	icon.draw_arc(ctr, r_in, 0.0, TAU, 32, col, 3.0)
	icon.draw_circle(ctr, 2.0, col)


## Pause/resume glyph: two bars while running, a play triangle while paused.
func _draw_pause_icon(icon: Control) -> void:
	var ctr := icon.size * 0.5
	var col := Settings.scheme().text
	if _paused_state:
		var s := 8.0
		icon.draw_colored_polygon(PackedVector2Array([
			ctr + Vector2(-s, -s),
			ctr + Vector2(-s, s),
			ctr + Vector2(s + 3.0, 0.0),
		]), col)
	else:
		icon.draw_rect(Rect2(ctr + Vector2(-7.0, -8.0), Vector2(4.0, 16.0)), col)
		icon.draw_rect(Rect2(ctr + Vector2(3.0, -8.0), Vector2(4.0, 16.0)), col)


## Accepts BBCode — callers colour individual lines (see main._start_build_phase).
## Wrapping in [center] here rather than at each call site keeps every banner
## centred whether or not it uses colour.
func set_message(text: String) -> void:
	_msg_label.text = "" if text == "" else "[center]%s[/center]" % text


func inspect(unit: Node2D) -> void:
	_inspector.show_unit(unit)


func inspected() -> Node2D:
	if is_instance_valid(_inspector.target()):
		return _inspector.target()
	return null


## A levelled-up trap changes both its refund and its next price — re-lay the
## open card so the two buttons agree with the trap they belong to.
func refresh_inspector() -> void:
	_inspector.refresh_trap_buttons()


func refresh_profiles() -> void:
	_refresh_profiles()


## Rebuild the left-hand Anti-Hero list now. Driven by AllureSystem.roster_changed
## so an arrival shows up the moment it happens, whatever the game is doing.
func refresh_roster() -> void:
	_update_roster(_inspector.target())


func redraw_hoard() -> void:
	_hoard_bar.queue_redraw()


func refresh(is_build: bool, can_build: bool, wave_index: int,
		wave_text: String, minion_text: String, minion_col: Color) -> void:
	_wave_index = wave_index
	_wave_label.text = wave_text
	_unleash_btn.disabled = not is_build
	for b in _tray.get_children():
		var btn := b as Button
		var id: String = btn.get_meta("trap_id")
		var d: TrapData = GameData.traps[id]
		btn.disabled = not can_build or not EconomySystem.can_afford(d.cost)
	_update_roster(_inspector.target())


## Procedural fallback icon for a trap tray button — used until real art is
## assigned to TrapData.icon. Mirrors the glyph the trap draws on the board.
## Delegates to the same glyphs the board draws, so a trap looks identical in
## your hand and on the floor.
func _draw_trap_icon(icon: Control, d: TrapData) -> void:
	Trap.draw_glyph(icon, icon.size * 0.5, d, d.color)


## The hoard bar, as its own Control purely so it can answer a DIFFERENT tooltip
## depending on which tick you're pointing at — a plain Control only carries one
## `tooltip_text`, and the marks each mean something different. Drawing still
## lives in Hud._draw_hoard_bar via the `draw` signal.
class HoardBar:
	extends Control

	signal tick_pressed(id: String)

	## How near the pointer has to be, in pixels, to count as "on" a tick.
	const HIT := 10.0

	## Which Anti-Hero's mark is under `x`, or "" for the bar itself. One hit test,
	## shared by the tooltip and the click, so what you read is what you open.
	func _tick_at(local: Vector2) -> String:
		var best_id := ""
		var best_dx := HIT
		for key in GameData.minions.keys():
			var d: MinionData = GameData.minions[key]
			var x: float = size.x * EconomySystem.bar_position(d.allure_arrive)
			var dx: float = absf(local.x - x)
			if dx < best_dx:
				best_dx = dx
				best_id = key
		return best_id

	## Clicking a mark opens that Anti-Hero's Bestiary entry. The event is only
	## consumed when a mark was actually hit — anywhere else on the bar the click
	## still falls through to the board underneath.
	func _gui_input(event: InputEvent) -> void:
		var pressed := false
		var at := Vector2.ZERO
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			pressed = true
			at = mb.position
		var touch := event as InputEventScreenTouch
		if touch != null and touch.pressed:
			pressed = true
			at = touch.position
		if not pressed:
			return
		var id := _tick_at(at)
		if id == "":
			return
		tick_pressed.emit(id)
		accept_event()

	func _get_tooltip(at_position: Vector2) -> String:
		var best_id := _tick_at(at_position)
		if best_id == "":
			return "THE HOARD — %d of %d Gold\nYour build budget, your health bar, and the only reason anyone is coming.\nThe marks along the bar are the Anti-Heroes. Point at one, or click it to read its page." % [
					EconomySystem.hoard, EconomySystem.capacity]
		return _tick_tooltip(GameData.minions[best_id])

	## What one mark actually means. The acquire mode is the important half: a mark
	## for a bought or earned unit is only a POSITION on the scale, and without
	## saying so it reads as "reach this much Gold and it appears", which is a lie.
	func _tick_tooltip(d: MinionData) -> String:
		var lines := ["%s — %d Gold" % [d.display_name, int(d.allure_arrive)]]
		match d.acquire_mode:
			"auto":
				lines.append("Comes out of the dark on its own once the hoard reaches %d."
						% int(d.allure_arrive))
				lines.append("Walks out again if the hoard falls below %d."
						% int(d.allure_desert))
				var short: int = int(d.allure_arrive) - EconomySystem.hoard
				lines.append("Here now." if short <= 0 else "%d Gold to go." % short)
			"earn":
				lines.append("Earned by clearing wave %d, then yours for good — it never deserts."
						% d.unlock_wave)
				lines.append("The mark is only where it sits on the scale. Gold does not summon it.")
			"buy":
				lines.append("Recruited in the Store for %d souls (or %d gems), then yours for good."
						% [d.recruit_souls, d.recruit_gems])
				lines.append("The mark is only where it sits on the scale. Gold does not summon it.")
		return "\n".join(lines)


func _draw_hoard_bar() -> void:
	var c := _hoard_bar
	var w: float = c.size.x
	if w <= 0.0:
		return
	var h := 16.0
	var top := 32.0

	## The bar measures the vault's capacity; the Allure thresholds are plain Gold
	## amounts, so both live on the same scale and a tick sits exactly where its
	## number is. `gold_after` is what you'd be left with if you spent what's armed.
	var frac := EconomySystem.capacity_fraction()
	var after := frac
	var gold_after := float(EconomySystem.hoard)
	if _preview_cost > 0:
		gold_after = float(maxi(EconomySystem.hoard - _preview_cost, 0))
		after = EconomySystem.bar_position(gold_after)

	var s: ColorScheme = Settings.scheme()
	var f := ThemeDB.fallback_font
	var title := "HOARD  %d / %d" % [EconomySystem.hoard, EconomySystem.capacity]
	if _preview_cost > 0:
		title += "     spending %d" % _preview_cost
	c.draw_string(f, Vector2(0, 18), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, s.accent)

	c.draw_rect(Rect2(Vector2(0, top), Vector2(w, h)), s.accent.darkened(0.85))
	if _preview_cost > 0:
		## Two bands: what you have now, and the shorter bar you'd be left with.
		c.draw_rect(Rect2(Vector2(0, top), Vector2(w * frac, h)), s.accent.darkened(0.55))
		c.draw_rect(Rect2(Vector2(0, top), Vector2(w * after, h)), s.accent)
	else:
		c.draw_rect(Rect2(Vector2(0, top), Vector2(w * frac, h)), s.accent)

	## Allure thresholds — a coloured tick per Anti-Hero, and ONE name.
	##
	## Every tick draws, because each one is a real number on a real scale. Only the
	## NEXT monster you haven't reached gets named, and it's named with its price:
	## five labels packed into the left of a 10000-wide bar would overprint each
	## other and the title, and the one with room to spare would be the furthest,
	## dearest unit — advertising the thing you can't have for hours while saying
	## nothing about the one you're twenty Gold short of.
	var next_id := ""
	var next_at := INF
	for key in GameData.minions.keys():
		var arrive: float = (GameData.minions[key] as MinionData).allure_arrive
		if arrive > gold_after and arrive < next_at:
			next_at = arrive
			next_id = key

	var title_right := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 10.0
	for key in GameData.minions.keys():
		var id: String = key
		var d: MinionData = GameData.minions[id]
		## The tick sits at the GOLD AMOUNT that summons this one, so its place on
		## the bar means the same thing the number above the bar does.
		var x := w * EconomySystem.bar_position(d.allure_arrive)
		var present := gold_after >= d.allure_arrive
		var losing := (float(EconomySystem.hoard) >= d.allure_desert) \
				and (gold_after < d.allure_desert)
		var col := Color(1.0, 0.3, 0.25) if losing else (d.color if present else Color(0.45, 0.45, 0.45))
		c.draw_line(Vector2(x, top - 5), Vector2(x, top + h + 5), col, 3.0)
		if id != next_id:
			continue
		var nm := "%s  %d" % [d.display_name, int(d.allure_arrive)]
		var nw := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		## Centred on its tick, then shoved clear of the title and the right edge.
		var nx := clampf(x - nw * 0.5, title_right, maxf(w - nw, title_right))
		c.draw_string(f, Vector2(nx, 18), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
