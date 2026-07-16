extends CanvasLayer
class_name Hud

## All UI. Anchored (not absolute pixels) so it reflows on rotation.

signal unleash_pressed()
signal pause_pressed()
signal speed_pressed()
signal trap_selected(id: String)
signal switch_board_pressed()
signal trap_slots_changed()

var _root: Control
var _hoard_bar: Control
var _wave_label: Label
var _minion_label: Label
var _toast: Label
var _msg_label: Label
var _tray: HBoxContainer
var _unleash_btn: Button
var _pause_btn: Button
var _speed_btn: Button

var _bestiary: Bestiary
var _inspector: Inspector
var _settings_panel: Control
var _slots_label: Label
var _slots_title: Label

var _wave_index: int = 0
var _preview_cost: int = 0
var _toast_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast.text = ""


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var controls := HBoxContainer.new()
	controls.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	controls.offset_left = -344
	controls.offset_right = -16
	controls.offset_top = 12
	controls.offset_bottom = 56
	controls.add_theme_constant_override("separation", 8)
	_root.add_child(controls)

	var gear_btn := Button.new()
	gear_btn.custom_minimum_size = Vector2(44, 44)
	gear_btn.text = "SET"
	gear_btn.tooltip_text = "Settings"
	gear_btn.pressed.connect(_toggle_settings)
	controls.add_child(gear_btn)

	var board_btn := Button.new()
	board_btn.custom_minimum_size = Vector2(44, 44)
	board_btn.text = ">>"
	board_btn.tooltip_text = "Switch board"
	board_btn.pressed.connect(func(): switch_board_pressed.emit())
	controls.add_child(board_btn)

	var info_btn := Button.new()
	info_btn.custom_minimum_size = Vector2(44, 44)
	info_btn.text = "?"
	info_btn.tooltip_text = "Bestiary"
	info_btn.pressed.connect(func(): _bestiary.toggle(_wave_index))
	controls.add_child(info_btn)

	_speed_btn = Button.new()
	_speed_btn.custom_minimum_size = Vector2(56, 44)
	_speed_btn.text = "1x"
	_speed_btn.pressed.connect(func(): speed_pressed.emit())
	controls.add_child(_speed_btn)

	_pause_btn = Button.new()
	_pause_btn.custom_minimum_size = Vector2(100, 44)
	_pause_btn.text = "PAUSE"
	_pause_btn.pressed.connect(func(): pause_pressed.emit())
	controls.add_child(_pause_btn)

	_hoard_bar = Control.new()
	_hoard_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hoard_bar.offset_left = 20
	_hoard_bar.offset_right = -20
	_hoard_bar.offset_top = 62
	_hoard_bar.offset_bottom = 180
	_hoard_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hoard_bar.draw.connect(_draw_hoard_bar)
	_root.add_child(_hoard_bar)

	_wave_label = _label(20, 188, 19, Color(0.9, 0.9, 0.9))
	_minion_label = _label(20, 240, 17, Color(0.6, 0.9, 0.5))
	_toast = _label(20, 268, 18, Color(1.0, 0.85, 0.3))

	_msg_label = Label.new()
	_msg_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_msg_label.add_theme_font_size_override("font_size", 40)
	_msg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_msg_label)

	_inspector = Inspector.new()
	_inspector.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_inspector.offset_left = -280
	_inspector.offset_right = -12
	_inspector.offset_top = -370
	_inspector.offset_bottom = -120
	_root.add_child(_inspector)

	_build_settings_panel()

	_bestiary = Bestiary.new()
	_root.add_child(_bestiary)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_left = 10
	row.offset_right = -10
	row.offset_top = -110
	row.offset_bottom = -10
	row.add_theme_constant_override("separation", 8)
	_root.add_child(row)

	_tray = HBoxContainer.new()
	_tray.add_theme_constant_override("separation", 8)
	row.add_child(_tray)

	for key in GameData.traps.keys():
		var id: String = key
		var d: TrapData = GameData.traps[id]
		var b := Button.new()
		b.custom_minimum_size = Vector2(96, 92)
		b.toggle_mode = true
		var kind := d.damage_type
		if d.kind == TrapData.Kind.SLOW_AURA:
			kind = "slow"
		b.text = "%s\n%d g %s" % [d.display_name, d.cost, kind]
		b.tooltip_text = d.flavor
		b.set_meta("trap_id", id)
		b.pressed.connect(_on_trap_button.bind(id))
		_tray.add_child(b)

	_unleash_btn = Button.new()
	_unleash_btn.custom_minimum_size = Vector2(120, 92)
	_unleash_btn.text = "UNLEASH"
	_unleash_btn.pressed.connect(func(): unleash_pressed.emit())
	row.add_child(_unleash_btn)


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

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -170
	box.offset_right = 170
	box.offset_top = -110
	box.offset_bottom = 110
	box.add_theme_constant_override("separation", 14)
	_settings_panel.add_child(box)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	box.add_child(title)

	_slots_title = Label.new()
	_slots_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slots_title.add_theme_font_size_override("font_size", 16)
	box.add_child(_slots_title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)

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

	var note := Label.new()
	note.text = "Saved automatically. Applies on this board now."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	box.add_child(note)

	var done := Button.new()
	done.text = "DONE"
	done.custom_minimum_size = Vector2(0, 48)
	done.pressed.connect(_toggle_settings)
	box.add_child(done)

	_refresh_slots_label()


func _toggle_settings() -> void:
	_settings_panel.visible = not _settings_panel.visible
	if _settings_panel.visible:
		_refresh_slots_label()


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


func set_controls(paused: bool, fast: bool) -> void:
	_pause_btn.text = "RESUME" if paused else "PAUSE"
	_speed_btn.text = "2x" if fast else "1x"


func set_message(text: String) -> void:
	_msg_label.text = text


func inspect(unit: Node2D) -> void:
	_inspector.show_unit(unit)


func inspected() -> Node2D:
	return _inspector.target()


func redraw_hoard() -> void:
	_hoard_bar.queue_redraw()


func refresh(is_build: bool, can_build: bool, wave_index: int,
		wave_text: String, minion_text: String, minion_col: Color) -> void:
	_wave_index = wave_index
	_wave_label.text = wave_text
	_minion_label.text = minion_text
	_minion_label.add_theme_color_override("font_color", minion_col)
	_unleash_btn.disabled = not is_build
	for b in _tray.get_children():
		var btn := b as Button
		var id: String = btn.get_meta("trap_id")
		var d: TrapData = GameData.traps[id]
		btn.disabled = not can_build or not EconomySystem.can_afford(d.cost)


func _draw_hoard_bar() -> void:
	var c := _hoard_bar
	var w: float = c.size.x
	if w <= 0.0:
		return
	var h := 32.0
	var top := 34.0

	var frac := EconomySystem.hoard_fraction()
	var after := frac
	if _preview_cost > 0 and EconomySystem.starting_hoard > 0:
		after = maxf(0.0, float(EconomySystem.hoard - _preview_cost) / float(EconomySystem.starting_hoard))

	var f := ThemeDB.fallback_font
	c.draw_string(f, Vector2(0, 24), "HOARD  %d / %d" % [EconomySystem.hoard, EconomySystem.starting_hoard],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.85, 0.25))

	c.draw_rect(Rect2(Vector2(0, top), Vector2(w, h)), Color(0.13, 0.11, 0.09))

	if _preview_cost > 0:
		c.draw_rect(Rect2(Vector2(0, top), Vector2(w * frac, h)), Color(0.55, 0.28, 0.15))
		c.draw_rect(Rect2(Vector2(0, top), Vector2(w * after, h)), Color(0.95, 0.78, 0.2))
	else:
		c.draw_rect(Rect2(Vector2(0, top), Vector2(w * frac, h)), Color(0.95, 0.78, 0.2))

	for key in GameData.minions.keys():
		var id: String = key
		var d: MinionData = GameData.minions[id]
		var x := w * d.allure_arrive
		var present := after >= d.allure_arrive
		var losing := (frac >= d.allure_desert) and (after < d.allure_desert)
		var col := Color(1.0, 0.3, 0.25) if losing else (d.color if present else Color(0.45, 0.45, 0.45))
		c.draw_line(Vector2(x, top - 6), Vector2(x, top + h + 6), col, 3.0)
		c.draw_string(f, Vector2(x - 30, top + h + 24), d.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)

	if _preview_cost > 0:
		c.draw_string(f, Vector2(0, top + h + 44), "spending %d..." % _preview_cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.6, 0.3))
