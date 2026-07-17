extends CanvasLayer
class_name Hud

## All UI. Anchored (not absolute pixels) so it reflows on rotation.

signal unleash_pressed()
signal pause_pressed()
signal speed_pressed()
signal trap_selected(id: String)
signal switch_board_pressed()
signal trap_slots_changed()
signal antihero_selected(unit: Node2D)
signal store_recruit(id: String, currency: String)
signal store_buy_gold()
signal store_buy_souls()
signal store_get_pack(pack_id: String)
signal store_watch_ad()

var _root: Control
var _hoard_bar: Control
var _wave_label: Label
var _minion_label: Label
var _toast: Label
var _msg_label: Label
var _tray: HBoxContainer
var _unleash_btn: Button
var _pause_btn: Button
var _pause_icon: Control
var _paused_state: bool = false
var _speed_btn: Button

var _bestiary: Bestiary
var _inspector: Inspector
var _settings_panel: Control
var _slots_label: Label
var _slots_title: Label

var _wave_index: int = 0
var _preview_cost: int = 0
var _toast_timer: float = 0.0

var _roster_box: VBoxContainer
var _roster_rows: Dictionary = {}   ## instance_id -> {"btn": Button, "unit": Node}
var _roster_sig: String = ""
var _roster_balance: Label

var _store_panel: Control
var _store_box: VBoxContainer
var _store_balance: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast.text = ""
	if _store_panel != null and _store_panel.visible:
		_update_store_balance()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

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
	_unleash_btn.text = "UNLEASH"
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
	_pause_btn.custom_minimum_size = Vector2(48, 44)
	_pause_btn.tooltip_text = "Pause / Resume"
	_pause_btn.pressed.connect(func(): pause_pressed.emit())
	controls.add_child(_pause_btn)
	_pause_icon = Control.new()
	_pause_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_icon.draw.connect(_draw_pause_icon.bind(_pause_icon))
	_pause_btn.add_child(_pause_icon)

	_hoard_bar = Control.new()
	_hoard_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hoard_bar.offset_left = 12
	_hoard_bar.offset_right = -380   ## leave the bottom-right for the trap tray
	_hoard_bar.offset_top = -68
	_hoard_bar.offset_bottom = -12
	_hoard_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hoard_bar.draw.connect(_draw_hoard_bar)
	_root.add_child(_hoard_bar)

	_wave_label = _label(20, 18, 19, Color(0.9, 0.9, 0.9))
	_toast = _label(20, 70, 18, Color(1.0, 0.85, 0.3))

	_build_roster_panel()

	_msg_label = Label.new()
	_msg_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_msg_label.add_theme_font_size_override("font_size", 40)
	_msg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_msg_label)

	_inspector = Inspector.new()
	_inspector.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_inspector.offset_left = 12
	_inspector.offset_right = 280
	_inspector.offset_top = -300
	_inspector.offset_bottom = -72   ## sit just above the bottom-left hoard bar
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
	row.add_theme_constant_override("separation", 8)
	_root.add_child(row)

	_tray = HBoxContainer.new()
	_tray.add_theme_constant_override("separation", 8)
	row.add_child(_tray)

	for key in GameData.traps.keys():
		var id: String = key
		var d: TrapData = GameData.traps[id]
		var b := Button.new()
		b.custom_minimum_size = Vector2(64, 58)
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

		var cost := Label.new()
		cost.text = "%dg" % d.cost
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost.add_theme_font_size_override("font_size", 12)
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(cost)

		_tray.add_child(b)


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
	title.add_theme_color_override("font_color", Color(0.85, 0.55, 0.8))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(title)

	_roster_balance = Label.new()
	_roster_balance.add_theme_font_size_override("font_size", 12)
	_roster_balance.add_theme_color_override("font_color", Color(0.75, 0.75, 0.6))
	_roster_balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_roster_balance)

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
		_roster_balance.text = "Souls %d   Gems %d" % [Bank.souls, Bank.gems]
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


func _toggle_store() -> void:
	if _store_panel == null:
		return
	_store_panel.visible = not _store_panel.visible
	if _store_panel.visible:
		refresh_store()


func _update_store_balance() -> void:
	if _store_balance != null:
		_store_balance.text = "Gold %d      Souls %d      Gems %d" % [EconomySystem.hoard, Bank.souls, Bank.gems]


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
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	_store_box.add_child(title)

	_store_balance = Label.new()
	_store_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_store_balance.add_theme_font_size_override("font_size", 15)
	_store_box.add_child(_store_balance)
	_update_store_balance()

	_store_box.add_child(_section_header("Recruit Anti-Heroes"))
	for key in GameData.minions.keys():
		var id: String = key
		var d: MinionData = GameData.minions[id]
		if d.acquire_mode == "auto":
			_store_box.add_child(_info_row("%s — drawn automatically by a rich hoard" % d.display_name))
		elif Bank.is_unlocked(id):
			_store_box.add_child(_info_row("%s — recruited" % d.display_name))
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
			var sbtn := Button.new()
			sbtn.text = "%d souls" % d.recruit_souls
			sbtn.disabled = not Bank.can_afford_souls(d.recruit_souls)
			sbtn.pressed.connect(store_recruit.emit.bind(id, "souls"))
			row.add_child(sbtn)
			var gbtn := Button.new()
			gbtn.text = "%d gems" % d.recruit_gems
			gbtn.disabled = not Bank.can_afford_gems(d.recruit_gems)
			gbtn.pressed.connect(store_recruit.emit.bind(id, "gems"))
			row.add_child(gbtn)
			_store_box.add_child(row)

	_store_box.add_child(_section_header("Spend Gems"))
	var goldbtn := Button.new()
	goldbtn.text = "+%d Gold  —  %d gems" % [Bank.GOLD_REFILL, Bank.GEM_GOLD_COST]
	goldbtn.disabled = not Bank.can_afford_gems(Bank.GEM_GOLD_COST)
	goldbtn.pressed.connect(store_buy_gold.emit)
	_store_box.add_child(goldbtn)
	var soulbtn := Button.new()
	soulbtn.text = "+%d Souls  —  %d gems" % [Bank.SOULS_PACK, Bank.GEM_SOULS_COST]
	soulbtn.disabled = not Bank.can_afford_gems(Bank.GEM_SOULS_COST)
	soulbtn.pressed.connect(store_buy_souls.emit)
	_store_box.add_child(soulbtn)

	_store_box.add_child(_section_header("Get Gems"))
	var adbtn := Button.new()
	adbtn.text = "Watch Ad  —  +%d Gems" % Bank.AD_REWARD_GEMS
	adbtn.pressed.connect(store_watch_ad.emit)
	_store_box.add_child(adbtn)
	for pack_key in Bank.GEM_PACKS.keys():
		var pack_id: String = pack_key
		var pack: Dictionary = Bank.GEM_PACKS[pack_id]
		var pbtn := Button.new()
		pbtn.text = "%d Gems  —  %s" % [int(pack["gems"]), pack["price"]]
		pbtn.pressed.connect(store_get_pack.emit.bind(pack_id))
		_store_box.add_child(pbtn)

	var note := Label.new()
	note.text = "Purchases and ads are stubbed for testing — no real charge."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_store_box.add_child(note)

	var close := Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(_toggle_store)
	_store_box.add_child(close)


func _section_header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(0.85, 0.55, 0.8))
	return l


func _info_row(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


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
	_paused_state = paused
	if _pause_icon != null:
		_pause_icon.queue_redraw()
	_speed_btn.text = "2x" if fast else "1x"


## Store glyph: a wrapped present — box, lid, ribbon, and a bow on top.
func _draw_present_icon(icon: Control) -> void:
	var ctr := icon.size * 0.5
	var box := Color(0.92, 0.92, 0.92)
	var ribbon := Color(0.98, 0.78, 0.32)
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


## Settings glyph: a simple gear — radial teeth, a ring body, and a center axle.
func _draw_gear_icon(icon: Control) -> void:
	var ctr := icon.size * 0.5
	var col := Color(0.92, 0.92, 0.92)
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
	var col := Color(0.92, 0.92, 0.92)
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


func set_message(text: String) -> void:
	_msg_label.text = text


func inspect(unit: Node2D) -> void:
	_inspector.show_unit(unit)


func inspected() -> Node2D:
	if is_instance_valid(_inspector.target()):
		return _inspector.target()
	return null


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
func _draw_trap_icon(icon: Control, d: TrapData) -> void:
	var ctr := icon.size * 0.5
	var col := d.color
	match d.kind:
		TrapData.Kind.AREA_DAMAGE:
			icon.draw_rect(Rect2(ctr - Vector2(14, 14), Vector2(28, 28)), col)
			for i in 3:
				var x := ctr.x - 9.0 + i * 9.0
				icon.draw_line(Vector2(x, ctr.y + 8), Vector2(x, ctr.y - 8), Color(0.9, 0.9, 0.95), 2.0)
			icon.draw_rect(Rect2(ctr - Vector2(14, 14), Vector2(28, 28)), Color(0, 0, 0, 0.4), false, 1.5)
		TrapData.Kind.TURRET:
			icon.draw_rect(Rect2(ctr - Vector2(13, 13), Vector2(26, 26)), col)
			icon.draw_line(ctr, ctr + Vector2(15, -9), Color(0.95, 0.9, 0.7), 3.0)
			icon.draw_rect(Rect2(ctr - Vector2(13, 13), Vector2(26, 26)), Color(0, 0, 0, 0.4), false, 1.5)
		TrapData.Kind.SLOW_AURA:
			icon.draw_circle(ctr, 14.0, col)
			icon.draw_arc(ctr, 14.0, 0.0, TAU, 20, Color(1, 1, 1, 0.85), 2.0)
			icon.draw_line(ctr + Vector2(-7, 0), ctr + Vector2(7, 0), Color(1, 1, 1, 0.7), 1.5)
			icon.draw_line(ctr + Vector2(0, -7), ctr + Vector2(0, 7), Color(1, 1, 1, 0.7), 1.5)
		TrapData.Kind.WEAKEN_AURA:
			icon.draw_circle(ctr, 14.0, col)
			icon.draw_arc(ctr, 14.0, 0.0, TAU, 20, Color(0.2, 0, 0.1, 0.9), 2.0)
			icon.draw_line(ctr + Vector2(-6, -6), ctr + Vector2(6, 6), Color(0.15, 0, 0.08), 2.0)
			icon.draw_line(ctr + Vector2(6, -6), ctr + Vector2(-6, 6), Color(0.15, 0, 0.08), 2.0)


func _draw_hoard_bar() -> void:
	var c := _hoard_bar
	var w: float = c.size.x
	if w <= 0.0:
		return
	var h := 16.0
	var top := 32.0

	var frac := EconomySystem.hoard_fraction()
	var after := frac
	if _preview_cost > 0 and EconomySystem.starting_hoard > 0:
		after = maxf(0.0, float(EconomySystem.hoard - _preview_cost) / float(EconomySystem.starting_hoard))

	var f := ThemeDB.fallback_font
	var title := "HOARD  %d / %d" % [EconomySystem.hoard, EconomySystem.starting_hoard]
	if _preview_cost > 0:
		title += "     spending %d" % _preview_cost
	c.draw_string(f, Vector2(0, 18), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.85, 0.25))

	c.draw_rect(Rect2(Vector2(0, top), Vector2(w, h)), Color(0.13, 0.11, 0.09))
	if _preview_cost > 0:
		c.draw_rect(Rect2(Vector2(0, top), Vector2(w * frac, h)), Color(0.55, 0.28, 0.15))
		c.draw_rect(Rect2(Vector2(0, top), Vector2(w * after, h)), Color(0.95, 0.78, 0.2))
	else:
		c.draw_rect(Rect2(Vector2(0, top), Vector2(w * frac, h)), Color(0.95, 0.78, 0.2))

	## Allure thresholds — a colored tick with the unit's name centered above it.
	for key in GameData.minions.keys():
		var id: String = key
		var d: MinionData = GameData.minions[id]
		var x := w * d.allure_arrive
		var present := after >= d.allure_arrive
		var losing := (frac >= d.allure_desert) and (after < d.allure_desert)
		var col := Color(1.0, 0.3, 0.25) if losing else (d.color if present else Color(0.45, 0.45, 0.45))
		c.draw_line(Vector2(x, top - 5), Vector2(x, top + h + 5), col, 3.0)
		var nm: String = d.display_name
		var nw := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		c.draw_string(f, Vector2(x - nw * 0.5, 18), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
