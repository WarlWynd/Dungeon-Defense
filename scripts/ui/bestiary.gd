extends Control
class_name Bestiary

## On-demand reference overlay. LIST of enemies/minions (tap to read), and a
## DETAIL page per unit. Also shows the coming wave's composition.

signal closed()

var wave_index: int = 0

var _list_page: VBoxContainer
var _detail_page: VBoxContainer
var _detail_title: Label
var _detail_stats: Label
var _detail_body: Label
var _entries: VBoxContainer


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0, 0, 0, 0.72)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = 70
	panel.offset_bottom = -70
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)

	_list_page = VBoxContainer.new()
	_list_page.add_theme_constant_override("separation", 6)
	stack.add_child(_list_page)

	var title := Label.new()
	title.text = "BESTIARY"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	_list_page.add_child(title)

	var hint := Label.new()
	hint.text = "Tap anything to read it."
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_list_page.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_page.add_child(scroll)

	_entries = VBoxContainer.new()
	_entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entries.add_theme_constant_override("separation", 4)
	scroll.add_child(_entries)

	var close := Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size = Vector2(0, 48)
	close.pressed.connect(close_panel)
	_list_page.add_child(close)

	_detail_page = VBoxContainer.new()
	_detail_page.add_theme_constant_override("separation", 10)
	_detail_page.visible = false
	stack.add_child(_detail_page)

	_detail_title = Label.new()
	_detail_title.add_theme_font_size_override("font_size", 26)
	_detail_page.add_child(_detail_title)

	_detail_stats = Label.new()
	_detail_stats.add_theme_font_size_override("font_size", 15)
	_detail_stats.add_theme_color_override("font_color", Color(1.0, 0.84, 0.3))
	_detail_page.add_child(_detail_stats)

	var body_scroll := ScrollContainer.new()
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_page.add_child(body_scroll)

	_detail_body = Label.new()
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body.custom_minimum_size = Vector2(240, 0)
	_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_body.add_theme_font_size_override("font_size", 16)
	body_scroll.add_child(_detail_body)

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(0, 48)
	back.pressed.connect(_show_list)
	_detail_page.add_child(back)


func open(index: int) -> void:
	wave_index = index
	_rebuild_entries()
	_show_list()
	visible = true


func close_panel() -> void:
	visible = false
	closed.emit()


func toggle(index: int) -> void:
	if visible:
		close_panel()
	else:
		open(index)


func _show_list() -> void:
	_list_page.visible = true
	_detail_page.visible = false


func _upcoming() -> Dictionary:
	if wave_index < 0 or wave_index >= GameData.WAVES.size():
		return {}
	return GameData.WAVES[wave_index]


func _rebuild_entries() -> void:
	for c in _entries.get_children():
		c.queue_free()
	var comp := _upcoming()

	_add_header("INCOMING — WAVE %d" % (wave_index + 1), Color(0.95, 0.4, 0.35))
	for key in GameData.heroes.keys():
		var id: String = key
		var d: HeroData = GameData.heroes[id]
		var count: int = comp.get(id, 0)
		var label := d.display_name
		if count > 0:
			label = "%d x %s" % [count, d.display_name]
		_add_entry(label, "steals %d" % d.greed, d.color, count > 0, _show_hero.bind(id))

	_add_header("YOUR MINIONS", Color(0.55, 0.9, 0.5))
	var frac := EconomySystem.hoard_fraction()
	for key in GameData.minions.keys():
		var id: String = key
		var d: MinionData = GameData.minions[id]
		var here: bool = frac >= d.allure_desert
		var label := d.display_name
		if d.count > 1:
			label = "%s  (%d x %s)" % [d.display_name, d.count, d.unit_display()]
		_add_entry(label, "needs %d%%" % int(d.allure_arrive * 100.0), d.color, here, _show_minion.bind(id))


func _add_header(text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", col)
	_entries.add_child(l)


func _add_entry(label: String, right: String, col: Color, active: bool, on_press: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_entries.add_child(row)

	var swatch := ColorRect.new()
	swatch.color = col if active else Color(col, 0.3)
	swatch.custom_minimum_size = Vector2(16, 16)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(swatch)

	var b := Button.new()
	b.text = "%s        %s" % [label, right]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not active:
		b.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	b.pressed.connect(on_press)
	row.add_child(b)


func _show_hero(id: String) -> void:
	var d: HeroData = GameData.heroes[id]
	_detail_title.text = d.display_name
	_detail_title.add_theme_color_override("font_color", d.color)

	var lines := []
	if d.greed > 0:
		lines.append("STEALS %d  ·  worth %d when killed" % [d.greed, d.bounty])
	else:
		lines.append("Steals nothing  ·  worth %d when killed" % d.bounty)
	lines.append("%d HP" % int(d.max_hp))

	var move := "Moves %d" % int(d.speed)
	if d.flee_speed_mult > 1.01:
		move += "  ·  FLEES %d (%d%% faster)" % [int(d.speed * d.flee_speed_mult), int((d.flee_speed_mult - 1.0) * 100.0)]
	lines.append(move)

	if d.damage > 0.0:
		lines.append("Hits for %d every %.1fs  (kills your minions)" % [int(d.damage), d.attack_rate])
	else:
		lines.append("Does not fight  ·  runs past your minions")

	if d.heal_amount > 0.0:
		lines.append("HEALS %d every %.1fs  =  %.1f HP/sec" % [int(d.heal_amount), d.heal_rate, d.heal_amount / d.heal_rate])
		lines.append("Mends whoever is WORST HURT  ·  KILL HER FIRST")

	lines.append("Armour %d%%  (vs physical)" % int(d.armor * 100.0))
	lines.append("Magic def %d%%  (vs poison)" % int(d.magic_defense * 100.0))

	var charm_pct := int(d.charm_chance(0.5) * 100.0)
	if charm_pct <= 0:
		lines.append("Purity %d%%  ·  CANNOT EVER BE CHARMED" % int(d.purity * 100.0))
	else:
		lines.append("Purity %d%%  ·  resists charm %d%% of the time" % [int(d.purity * 100.0), 100 - charm_pct])

	if d.purity_aura > 0.0:
		lines.append("BLESSES its escort to %d%% purity. KILL IT FIRST." % int(d.purity_aura * 100.0))

	_detail_stats.text = "\n".join(lines)
	_detail_body.text = d.description
	_list_page.visible = false
	_detail_page.visible = true


func _show_minion(id: String) -> void:
	var d: MinionData = GameData.minions[id]
	_detail_title.text = d.display_name
	_detail_title.add_theme_color_override("font_color", d.color)
	_detail_stats.text = "Arrives at %d%% hoard   ·   leaves below %d%%" % [int(d.allure_arrive * 100.0), int(d.allure_desert * 100.0)]
	if d.count > 1:
		_detail_stats.text += "\n%d separate %ss, %d HP each" % [d.count, d.unit_display(), int(d.max_hp)]
	else:
		_detail_stats.text += "\n%d HP" % int(d.max_hp)
	_detail_body.text = d.description
	_list_page.visible = false
	_detail_page.visible = true
