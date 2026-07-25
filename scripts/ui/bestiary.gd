extends Control
class_name Bestiary

const UnitGlyphs := preload("res://scripts/data/unit_glyphs.gd")

## On-demand reference overlay. LIST of enemies/minions (tap to read), and a
## DETAIL page per unit. Also shows the coming wave's composition.

signal closed()

var wave_index: int = 0

const TAB_RAIDERS := 0
const TAB_MONSTERS := 1
const TAB_TRAPS := 2
const TAB_NAMES := ["RAIDERS", "YOUR MONSTERS", "YOUR TRAPS"]

## The representative pack size an AoE trap's effective damage is quoted against.
## A raider wave arrives in clumps (six squires at a time), so a tight group of
## this many is what you're actually buying splash for.
const AOE_CLUSTER := 3

var _tab: int = TAB_RAIDERS
var _tab_buttons: Array = []
var _title: Label
var _hint: Label

var _list_page: VBoxContainer
var _detail_page: VBoxContainer
var _detail_title: Label
## Stats and the baseline comparison are RichTextLabels, not plain Labels, so a
## gold coin can sit inline in the flowing text where a Gold amount is named.
var _detail_stats: RichTextLabel
var _detail_body: Label
var _detail_compare: RichTextLabel
## A gold coin and a heart baked to textures once, so RichTextLabel.add_image can
## drop them inline. Supersampled (32px, shown ~15px) so the downscale smooths the
## edge.
var _coin_tex: ImageTexture
var _heart_tex: ImageTexture
var _detail_strengths: Label
var _detail_weaknesses: Label
var _entries: VBoxContainer


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_coin_tex = _make_coin_tex()
	_heart_tex = _make_heart_tex()
	_build()


func _build() -> void:
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0, 0, 0, 0.86)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = 70
	panel.offset_bottom = -70
	## Opaque background. The default panel style is translucent, and with the
	## dungeon rendering behind it the stat columns were unreadable.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.085, 0.095, 0.125, 1.0)
	sb.border_color = Color(0.35, 0.32, 0.22)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", sb)
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
	## Must claim the leftover height, or the ScrollContainer inside it expands
	## into nothing and the whole list renders zero pixels tall.
	_list_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_list_page)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	_list_page.add_child(_title)

	## Two books in one panel: who's coming for the gold, and who fights for it.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	_list_page.add_child(tabs)
	for i in TAB_NAMES.size():
		var t := Button.new()
		t.text = TAB_NAMES[i]
		t.custom_minimum_size = Vector2(0, 42)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.pressed.connect(_select_tab.bind(i))
		tabs.add_child(t)
		_tab_buttons.append(t)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_list_page.add_child(_hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	## Without this the container sizes rows to their MINIMUM width. Row contents
	## are anchored inside the button, so that minimum is zero and every row
	## renders 54px tall and 0px wide — an empty-looking list.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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
	_detail_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_detail_page)

	_detail_title = Label.new()
	_detail_title.add_theme_font_size_override("font_size", 26)
	_detail_page.add_child(_detail_title)

	_detail_stats = _rich_label(15, Color(1.0, 0.84, 0.3))
	_detail_page.add_child(_detail_stats)

	var body_scroll := ScrollContainer.new()
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_page.add_child(body_scroll)

	var body_box := VBoxContainer.new()
	body_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_box.add_theme_constant_override("separation", 12)
	body_scroll.add_child(body_box)

	_detail_body = _wrapped_label(16, Color(0.88, 0.88, 0.88))
	body_box.add_child(_detail_body)

	_detail_compare = _rich_label(15, Color(0.62, 0.80, 0.98))
	body_box.add_child(_detail_compare)

	_detail_strengths = _wrapped_label(15, Color(0.55, 0.92, 0.55))
	body_box.add_child(_detail_strengths)

	_detail_weaknesses = _wrapped_label(15, Color(0.98, 0.52, 0.46))
	body_box.add_child(_detail_weaknesses)

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(0, 48)
	back.pressed.connect(_show_list)
	_detail_page.add_child(back)


func open(index: int) -> void:
	wave_index = index
	## Re-assert full-screen at open time. The detail labels carry a 240px minimum
	## width, and if this ever gets sized to its content instead of the viewport
	## the whole panel collapses into the corner and the list has nowhere to draw.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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

	_refresh_tabs()
	match _tab:
		TAB_RAIDERS: _build_raiders(comp)
		TAB_TRAPS: _build_trap_list()
		_: _build_monsters()


func _select_tab(i: int) -> void:
	_tab = i
	_rebuild_entries()
	_show_list()


func _refresh_tabs() -> void:
	for i in _tab_buttons.size():
		var b: Button = _tab_buttons[i]
		b.add_theme_color_override("font_color",
				Color(1.0, 0.85, 0.25) if i == _tab else Color(0.62, 0.62, 0.62))
	match _tab:
		TAB_RAIDERS:
			_title.text = "BESTIARY — RAIDERS"
			_hint.text = "Who is coming for your Gold. Tap anything to read it."
		TAB_TRAPS:
			_title.text = "BESTIARY — YOUR TRAPS"
			_hint.text = "What you build to stop them. Tap anything to read it."
		_:
			_title.text = "BESTIARY — YOUR MONSTERS"
			_hint.text = "Who fights for it. Tap anything to read it."


## STR/HP are rated against the strongest unit on the SAME side, so the +/-
## answers "how does this compare to the rest of this roster", not "is this big".
func _build_raiders(comp: Dictionary) -> void:
	_add_header("INCOMING — WAVE %d" % (wave_index + 1), Color(0.95, 0.4, 0.35))
	var href := _reference(true)
	for key in GameData.heroes.keys():
		var id: String = key
		var d: HeroData = GameData.heroes[id]
		var count: int = comp.get(id, 0)
		var label := d.display_name
		if count > 0:
			label = "%d x %s" % [count, d.display_name]
		_add_entry(label, d.color, count > 0, "hero", id,
				d.damage / maxf(d.attack_rate, 0.01), href["str"],
				d.max_hp, href["hp"], _show_hero.bind(id))


func _build_monsters() -> void:
	var frac := EconomySystem.hoard_fraction()
	var mref := _reference(false)
	_add_header("IN THE DUNGEON NOW", Color(0.55, 0.9, 0.5))
	var absent: Array = []
	for key in GameData.minions.keys():
		var id: String = key
		var d: MinionData = GameData.minions[id]
		if _minion_present(d, frac):
			_add_monster_entry(d, id, true, mref)
		else:
			absent.append(id)

	if not absent.is_empty():
		_add_header("NOT HERE YET", Color(0.72, 0.62, 0.35))
		for key in absent:
			_add_monster_entry(GameData.minions[key], key, false, mref)


func _add_monster_entry(d: MinionData, id: String, here: bool, mref: Dictionary) -> void:
	var label := d.display_name
	if d.count > 1:
		label = "%s  (%d x %s)" % [d.display_name, d.count, d.unit_display()]
	_add_entry(label, d.color, here, "minion", id,
			(d.damage / maxf(d.attack_rate, 0.01)) * float(d.count), mref["str"],
			d.max_hp * float(d.count), mref["hp"], _show_minion.bind(id))


## Traps split by what the hoard will actually buy right now, mirroring the
## monsters tab's here/not-here split — the useful question standing at the tray
## is "what can I put down THIS build phase", not "what exists".
func _build_trap_list() -> void:
	var tref := _trap_reference()
	var affordable: Array = []
	var too_dear: Array = []
	for key in GameData.traps.keys():
		if EconomySystem.can_afford(GameData.traps[key].cost):
			affordable.append(key)
		else:
			too_dear.append(key)

	if not affordable.is_empty():
		_add_header("YOU CAN AFFORD NOW", Color(0.55, 0.9, 0.5))
		for key in affordable:
			_add_trap_entry(GameData.traps[key], key, true, tref)

	if not too_dear.is_empty():
		_add_header("TOO EXPENSIVE RIGHT NOW", Color(0.72, 0.62, 0.35))
		for key in too_dear:
			_add_trap_entry(GameData.traps[key], key, false, tref)


## Second chip is COST, not HP — a trap can't be hurt, so HP would be a dead
## column. Cost is unrated: on every other row "+++" means strong, and a big
## "+++" against a price tag would read as a recommendation.
func _add_trap_entry(d: TrapData, id: String, affordable: bool, tref: Dictionary) -> void:
	## AoE traps advertise their effective damage against a packed group — that's
	## the whole reason to pay for splash. Single-target traps show plain DPS.
	var dmg := _trap_cluster_dps(d, AOE_CLUSTER) if _is_aoe(d) else _trap_dps(d)
	_add_entry(d.display_name, d.color, affordable, "trap", id,
			dmg, tref["dps"],
			float(d.cost), 0.0, _show_trap.bind(id),
			"AoE" if _is_aoe(d) else "DPS", "COST", false)


## Splash turrets and floor traps both hit more than the one raider they aimed
## at, so their damage number is tagged AoE — otherwise it reads as single-target
## and the Explosive Turret looks strictly worse than a Crossbow.
func _is_aoe(d: TrapData) -> bool:
	return d.splash_radius > 0.0 or d.kind == TrapData.Kind.AREA_DAMAGE


## Total damage one shot deals when `bodies` raiders are packed at the target.
## Splash: the aimed raider takes full, the rest take the falloff share. Floor
## trap: everyone standing on it takes full. Mirrors Trap._tick_turret /
## _tick_area exactly, so the book can't quote damage the trap doesn't deal.
func _trap_cluster_shot(d: TrapData, bodies: int) -> float:
	if d.splash_radius > 0.0:
		return d.damage + float(bodies - 1) * d.damage * Trap.SPLASH_FALLOFF
	if d.kind == TrapData.Kind.AREA_DAMAGE:
		return d.damage * float(bodies)
	return d.damage


func _trap_cluster_dps(d: TrapData, bodies: int) -> float:
	if d.fire_rate <= 0.0 or d.damage <= 0.0:
		return 0.0
	return _trap_cluster_shot(d, bodies) / d.fire_rate


func _trap_reference() -> Dictionary:
	var best := 0.0
	for key in GameData.traps.keys():
		best = maxf(best, _trap_dps(GameData.traps[key]))
	return {"dps": best}


func _trap_dps(d: TrapData) -> float:
	if d.fire_rate <= 0.0 or d.damage <= 0.0:
		return 0.0
	return d.damage / d.fire_rate


## Is this Anti-Hero actually in the dungeon right now? Auto units come and go
## with the hoard; bought/earned ones are permanent once unlocked.
func _minion_present(d: MinionData, frac: float) -> bool:
	if d.acquire_mode == "auto":
		return frac >= d.allure_desert
	return Bank.is_unlocked(d.id)


func _reference(heroes: bool) -> Dictionary:
	var best_str := 0.0
	var best_hp := 0.0
	if heroes:
		for key in GameData.heroes.keys():
			var d: HeroData = GameData.heroes[key]
			best_str = maxf(best_str, d.damage / maxf(d.attack_rate, 0.01))
			best_hp = maxf(best_hp, d.max_hp)
	else:
		for key in GameData.minions.keys():
			var d: MinionData = GameData.minions[key]
			best_str = maxf(best_str, (d.damage / maxf(d.attack_rate, 0.01)) * float(d.count))
			best_hp = maxf(best_hp, d.max_hp * float(d.count))
	return {"str": best_str, "hp": best_hp}


func _rating(value: float, ref: float) -> String:
	if ref <= 0.0 or value <= 0.001:
		return "--"
	var r := value / ref
	if r < 0.20:
		return "-"
	if r < 0.45:
		return "+"
	if r < 0.75:
		return "++"
	return "+++"


func _add_header(text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", col)
	_entries.add_child(l)


## The two chip tags are parameters because the traps tab shows DPS/COST where
## units show STR/HP. `rate_right` turns off the +/- bar for values where a
## rating would be meaningless or misleading (a price).
func _add_entry(label: String, col: Color, active: bool, kind: String, id: String,
		str_val: float, str_ref: float, hp_val: float, hp_ref: float,
		on_press: Callable, str_tag: String = "STR", hp_tag: String = "HP",
		rate_right: bool = true) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 54)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(on_press)
	_entries.add_child(b)

	## Contents ride inside the Button and ignore the mouse, so the whole row
	## stays one tap target (same trick the trap tray uses).
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -8
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	b.add_child(row)

	## Absent units stay listed but dimmed — you can still read them.
	var dim := 1.0 if active else 0.42

	var glyph := Control.new()
	glyph.custom_minimum_size = Vector2(34, 34)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.draw.connect(_draw_unit_glyph.bind(glyph, kind, id, col, dim))
	row.add_child(glyph)

	var name_label := Label.new()
	name_label.text = label
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, dim))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)

	row.add_child(_stat_chip(str_tag, str_val, str_ref, Color(0.98, 0.72, 0.35), dim))
	## Second chip: traps price in Gold (coin glyph); units show HP as the heart
	## glyph + amount + rating. Neither spells out a tag word any more.
	if kind == "trap":
		row.add_child(_coin_chip(hp_val, dim))
	else:
		row.add_child(_heart_chip(hp_val, hp_ref, dim, rate_right))


func _stat_chip(tag: String, value: float, ref: float, col: Color, dim: float,
		rate: bool = true) -> Label:
	var l := Label.new()
	l.custom_minimum_size = Vector2(104, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(col, dim))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rate:
		l.text = "%s %d  %s" % [tag, int(round(value)), _rating(value, ref)]
	else:
		l.text = "%s %d" % [tag, int(round(value))]
	return l


## A price chip: the amount and a gold coin, right-aligned to sit where the STR/HP
## chips do. Mirrors the coin the Store and trap tray draw, so Gold reads the same
## everywhere. Its own draw so the Bestiary needn't reach into the HUD.
func _coin_chip(value: float, dim: float) -> Control:
	var box := HBoxContainer.new()
	box.custom_minimum_size = Vector2(104, 0)
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lbl := Label.new()
	lbl.text = str(int(round(value)))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, dim))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lbl)

	var coin := Control.new()
	coin.custom_minimum_size = Vector2(15, 16)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.draw.connect(_draw_coin_glyph.bind(coin, dim))
	box.add_child(coin)
	return box


## An HP chip: a heart glyph then the value and its +/- rating, sitting where the
## old "HP 42 +++" text chip did. Value keeps the HP green; the heart is red.
func _heart_chip(value: float, ref: float, dim: float, rate: bool) -> Control:
	var box := HBoxContainer.new()
	box.custom_minimum_size = Vector2(104, 0)
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var heart := Control.new()
	heart.custom_minimum_size = Vector2(15, 16)
	heart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heart.draw.connect(_draw_heart_glyph.bind(heart, dim))
	box.add_child(heart)

	var lbl := Label.new()
	lbl.text = "%d  %s" % [int(round(value)), _rating(value, ref)] if rate else "%d" % int(round(value))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.88, 0.55, dim))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lbl)
	return box


## Gold coin — a rimmed disc with an inner ring and a minted highlight, dimmed for
## can't-afford rows. Same fixed gold the HUD uses.
func _draw_coin_glyph(icon: Control, dim: float) -> void:
	var ctr := icon.size * 0.5
	var body := Color(1.0, 0.82, 0.22, dim)
	var rim := Color(0.6, 0.45, 0.08, dim)
	icon.draw_circle(ctr, 7.0, rim)
	icon.draw_circle(ctr, 5.8, body)
	icon.draw_arc(ctr, 4.0, 0.0, TAU, 20, rim, 1.0)
	icon.draw_circle(ctr + Vector2(-1.8, -1.8), 1.5, Color(1.0, 0.92, 0.55, dim))


func _draw_unit_glyph(icon: Control, kind: String, id: String, col: Color, dim: float) -> void:
	var c := Color(col, dim)
	## Traps reuse the trap glyph; heroes/minions reuse the shared UnitGlyphs the
	## board also draws, so a unit looks identical in the book and on the field.
	## s = 1.0 is the Bestiary's native icon size.
	if kind == "trap":
		Trap.draw_glyph(icon, icon.size * 0.5, GameData.traps[id], c)
		return
	UnitGlyphs.draw(icon, icon.size * 0.5, 1.0, kind, id, c)


func _show_hero(id: String) -> void:
	var d: HeroData = GameData.heroes[id]
	_detail_title.text = d.display_name
	_detail_title.add_theme_color_override("font_color", d.color)

	var lines := []
	if d.greed > 0:
		lines.append("STEALS %d  ·  worth %d when killed" % [d.greed, d.bounty])
	else:
		lines.append("Steals nothing  ·  worth %d when killed" % d.bounty)
	lines.append("%d {heart}" % int(d.max_hp))

	var move := "Moves %d" % int(d.speed)
	if d.flee_speed_mult > 1.01:
		move += "  ·  FLEES %d (%d%% faster)" % [int(d.speed * d.flee_speed_mult), int((d.flee_speed_mult - 1.0) * 100.0)]
	lines.append(move)

	if d.damage > 0.0:
		lines.append("Hits for %d every %.1fs  (kills your minions)" % [int(d.damage), d.attack_rate])
	else:
		lines.append("Does not fight  ·  runs past your minions")

	if d.heal_amount > 0.0:
		lines.append("HEALS %d every %.1fs  =  %.1f {heart}/sec" % [int(d.heal_amount), d.heal_rate, d.heal_amount / d.heal_rate])
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

	_set_rich_text(_detail_stats, "\n".join(lines))
	_detail_body.text = d.description
	## Heroes are read on their own terms — no "VS THE SQUIRE" block. (Monsters
	## keep their comparison; it's still useful against the free Goblin Pack.)
	_detail_compare.text = ""
	_detail_compare.visible = false
	_set_pros_cons(d.strengths, d.weaknesses)
	_list_page.visible = false
	_detail_page.visible = true


## The Goblin Pack is the monsters' baseline for the same reason the Squire is
## the raiders': it's the free one you always have, so everything you PAY for
## should be quoted against it.
func _vs_monster_baseline(d: MinionData) -> String:
	var b: MinionData = GameData.minions.get("goblin_pack")
	if b == null:
		return ""
	if d.id == b.id:
		return "THE BASELINE\nThe free one, and the one that never leaves. Every monster you pay for is measured against this."
	var out := ["VS THE GOBLIN PACK (the free one)"]
	out.append("{heart} %d total   %s" % [
		int(d.max_hp * d.count), _delta(d.max_hp * float(d.count), b.max_hp * float(b.count))])
	out.append("STR %.1f DPS   %s" % [_mdps(d), _delta(_mdps(d), _mdps(b))])
	out.append("Speed %d   %s" % [int(d.speed), _delta(d.speed, b.speed)])
	out.append("Bodies %d   (baseline %d)" % [d.count, b.count])
	return "\n".join(out)


func _mdps(d: MinionData) -> float:
	if d.attack_rate <= 0.0:
		return 0.0
	return (d.damage / d.attack_rate) * float(d.count)




func _delta(v: float, base: float) -> String:
	if base <= 0.0:
		return "(none on the standard)" if v > 0.0 else ""
	if v <= 0.0:
		return "none at all"
	var pct := int(round((v / base - 1.0) * 100.0))
	if pct == 0:
		return "same as standard"
	return "%+d%%" % pct


func _show_minion(id: String) -> void:
	var d: MinionData = GameData.minions[id]
	_detail_title.text = d.display_name
	_detail_title.add_theme_color_override("font_color", d.color)

	var lines := []
	## How you get it comes first — it decides whether this unit is even an option.
	lines.append(_acquire_line(d))

	if d.count > 1:
		lines.append("%d separate %ss  ·  %d {heart} each" % [d.count, d.unit_display(), int(d.max_hp)])
	else:
		lines.append("%d {heart}" % int(d.max_hp))

	if d.damage > 0.0 and d.attack_rate > 0.0:
		var dps := d.damage / d.attack_rate
		var dmg := "Hits %d every %.1fs  =  %.1f DPS" % [int(d.damage), d.attack_rate, dps]
		if d.count > 1:
			dmg += "  (%.1f as a pack)" % (dps * float(d.count))
		lines.append(dmg)
	else:
		lines.append("Deals no damage")

	lines.append("Moves %d" % int(d.speed))

	if d.can_charm:
		lines.append("CHARMS within %d  ·  re-rolls every %.0fs  ·  lasts %.0fs" % [
			int(d.charm_range), d.charm_cooldown, d.charm_duration])
		lines.append("Charm power %.2f  ·  stopped only by purity" % d.charm_power)

	if d.pursue_thieves_first:
		lines.append("Chases whoever is CARRYING your Gold")

	_set_rich_text(_detail_stats, "\n".join(lines))
	_detail_body.text = d.description
	_set_rich_text(_detail_compare, _vs_monster_baseline(d))
	_detail_compare.visible = true
	_set_pros_cons(d.strengths, d.weaknesses)
	_list_page.visible = false
	_detail_page.visible = true


func _show_trap(id: String) -> void:
	var d: TrapData = GameData.traps[id]
	_detail_title.text = d.display_name
	_detail_title.add_theme_color_override("font_color", d.color)

	var lines := []
	## Price first — it's the only stat that decides whether the rest is reachable.
	## {coin} tokens become an inline gold coin (see _set_rich_text).
	lines.append("Costs %d {coin}" % d.cost)
	lines.append(_trap_kind_line(d))

	var dps := _trap_dps(d)
	if dps <= 0.0:
		lines.append("Deals no damage at all")
	elif _is_aoe(d):
		## Two numbers, because an AoE trap has two honest answers: what it does to
		## one raider, and what it does to a packed group. The group figure is the
		## one that justifies the price, so per-Gold is quoted from it.
		var group_dps := _trap_cluster_dps(d, AOE_CLUSTER)
		lines.append("Hits %d every %.2fs  (%s)" % [int(d.damage), d.fire_rate, d.damage_type])
		lines.append("One raider:  %.1f DPS" % dps)
		lines.append("A tight group of %d:  %.0f per shot  =  %.1f AoE DPS" % [
			AOE_CLUSTER, _trap_cluster_shot(d, AOE_CLUSTER), group_dps])
		lines.append("%.2f AoE DPS per {coin} spent  (vs a group of %d)" % [
			group_dps / maxf(float(d.cost), 1.0), AOE_CLUSTER])
	else:
		lines.append("Hits %d every %.2fs  =  %.1f DPS  (%s)" % [
			int(d.damage), d.fire_rate, dps, d.damage_type])
		lines.append("%.2f DPS per {coin} spent" % (dps / maxf(float(d.cost), 1.0)))

	lines.append("Reaches %d" % int(d.attack_range))

	if d.splash_radius > 0.0:
		lines.append("SPLASH %d around the target at %d%% strength" % [
			int(d.splash_radius), int(Trap.SPLASH_FALLOFF * 100.0)])
	if d.slow_amount > 0.0:
		lines.append("SLOWS everything in range by %d%%" % int(d.slow_amount * 100.0))
	if d.weaken_damage_bonus > 0.0:
		lines.append("ROT: +%d%% damage taken by anything in range" % int(d.weaken_damage_bonus * 100.0))
	if d.weaken_heal_cut > 0.0:
		lines.append("ROT: -%d%% healing received in range  (beats the priests)" % int(d.weaken_heal_cut * 100.0))
	if d.kind == TrapData.Kind.TURRET:
		lines.append("Shoots: %s  ·  tap a built trap to change this" % Trap.targeting_name(d.targeting))

	_set_rich_text(_detail_stats, "\n".join(lines))
	_detail_body.text = d.flavor
	_set_rich_text(_detail_compare, _vs_trap_baseline(d))
	_detail_compare.visible = true
	## TrapData carries no authored strengths/weaknesses the way HeroData and
	## MinionData do, so both bullet blocks hide themselves here.
	_set_pros_cons(PackedStringArray(), PackedStringArray())
	_list_page.visible = false
	_detail_page.visible = true


func _trap_kind_line(d: TrapData) -> String:
	match d.kind:
		TrapData.Kind.TURRET:
			return "Turret  ·  picks one raider and shoots it"
		TrapData.Kind.AREA_DAMAGE:
			return "Floor trap  ·  hurts everything standing on it"
		TrapData.Kind.SLOW_AURA:
			return "Aura  ·  no damage, slows everything in range"
		TrapData.Kind.WEAKEN_AURA:
			return "Aura  ·  no damage, rots everything in range"
	return ""


## The Dart Launcher is the traps' baseline for the same reason the Squire and the
## Goblin Pack are: it's the cheapest thing you can always afford, so everything
## pricier should have to justify itself against it.
func _vs_trap_baseline(d: TrapData) -> String:
	var b: TrapData = GameData.traps.get("dart_launcher")
	if b == null:
		return ""
	if d.id == b.id:
		return "THE BASELINE\nThe cheap one you can always afford. Every other trap in this book is measured against this."
	var out := ["VS THE DART LAUNCHER (the cheap one)"]
	out.append("Cost %d {coin}   %s" % [d.cost, _delta(float(d.cost), float(b.cost))])
	out.append("DPS %.1f   %s" % [_trap_dps(d), _delta(_trap_dps(d), _trap_dps(b))])
	out.append("Range %d   %s" % [int(d.attack_range), _delta(d.attack_range, b.attack_range)])
	## Two darts cost less than one of most things — the real question is whether
	## the expensive trap beats the same Gold spent on the cheap one.
	var darts := float(d.cost) / float(b.cost)
	out.append("Same {coin} buys %.1f Dart Launchers  =  %.1f DPS" % [darts, darts * _trap_dps(b)])
	return "\n".join(out)


func _acquire_line(d: MinionData) -> String:
	match d.acquire_mode:
		"buy":
			var owned := "  ·  RECRUITED" if Bank.is_unlocked(d.id) else ""
			return "Recruit for %d souls (or %d gems)  ·  permanent%s" % [
				d.recruit_souls, d.recruit_gems, owned]
		"earn":
			return "Earned by clearing wave %d  ·  never deserts" % d.unlock_wave
		_:
			return "Arrives at %d%% hoard  ·  LEAVES below %d%%" % [
				int(d.allure_arrive * 100.0), int(d.allure_desert * 100.0)]


func _set_pros_cons(strengths: PackedStringArray, weaknesses: PackedStringArray) -> void:
	_detail_strengths.text = "STRENGTHS\n" + _bullets(strengths) if not strengths.is_empty() else ""
	_detail_strengths.visible = not strengths.is_empty()
	_detail_weaknesses.text = "WEAKNESSES\n" + _bullets(weaknesses) if not weaknesses.is_empty() else ""
	_detail_weaknesses.visible = not weaknesses.is_empty()


func _bullets(items: PackedStringArray) -> String:
	var out := []
	for s in items:
		out.append("•  %s" % s)
	return "\n".join(out)


func _wrapped_label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	## No minimum width — it inherits the scroll's width and wraps to it. A fixed
	## minimum here is what collapsed the panel into the corner.
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


## Wrapping RichTextLabel that sizes to its content — the coin-capable twin of
## _wrapped_label. `default_color` (not `font_color`) is the colour key a
## RichTextLabel reads.
func _rich_label(size: int, col: Color) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_color_override("default_color", col)
	return r


## Fills a RichTextLabel, turning each "{coin}" token into an inline gold coin and
## each "{heart}" into an inline heart. Plain text otherwise; append_text keeps
## the label's own default colour (the glyph images carry their own).
func _set_rich_text(r: RichTextLabel, text: String) -> void:
	r.clear()
	var rest := text
	while true:
		var ci := rest.find("{coin}")
		var hi := rest.find("{heart}")
		if ci == -1 and hi == -1:
			if rest != "":
				r.append_text(rest)
			return
		var use_coin := hi == -1 or (ci != -1 and ci < hi)
		var idx := ci if use_coin else hi
		if idx > 0:
			r.append_text(rest.substr(0, idx))
		if use_coin:
			r.add_image(_coin_tex, 15, 15, Color.WHITE, INLINE_ALIGNMENT_CENTER)
			rest = rest.substr(idx + 6)   ## len("{coin}")
		else:
			r.add_image(_heart_tex, 15, 15, Color.WHITE, INLINE_ALIGNMENT_CENTER)
			rest = rest.substr(idx + 7)   ## len("{heart}")


## Bakes the gold coin to a 32px texture (shown ~15px, so the downscale smooths
## the edge): a rimmed disc, an engraved inner ring, and a minted highlight — the
## same colours _draw_coin_glyph paints.
func _make_coin_tex() -> ImageTexture:
	var sz := 32
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ctr := Vector2(16, 16)
	var body := Color(1.0, 0.82, 0.22)
	var rim := Color(0.55, 0.40, 0.06)
	var hi := Color(1.0, 0.93, 0.6)
	for y in sz:
		for x in sz:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(ctr)
			if d > 14.0:
				continue
			var c := body
			if d > 11.6 or absf(d - 8.0) < 1.3:
				c = rim
			if Vector2(x + 0.5, y + 0.5).distance_to(ctr + Vector2(-3.6, -3.6)) < 3.2:
				c = hi
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## Bakes the heart to a 32px texture (shown ~15px). The shape is two lobe circles
## plus a triangle down to the point — the same geometry _draw_heart paints, so
## the inline heart and the chip/inspector hearts match.
func _make_heart_tex() -> ImageTexture:
	var sz := 32
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(16, 16)
	var s := 13.0
	var col := Color(0.93, 0.26, 0.33)
	var r := 0.5 * s
	var ly := c.y - 0.30 * s
	var lx := 0.50 * s
	var lc := Vector2(c.x - lx, ly)
	var rc := Vector2(c.x + lx, ly)
	var ta := Vector2(c.x - lx - r, ly)
	var tb := Vector2(c.x + lx + r, ly)
	var tbot := Vector2(c.x, c.y + 0.95 * s)
	for y in sz:
		for x in sz:
			var p := Vector2(x + 0.5, y + 0.5)
			if p.distance_to(lc) <= r or p.distance_to(rc) <= r or _in_tri(p, ta, tb, tbot):
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## Heart as primitives (two lobes + a triangle to the point), for the list chip
## and — mirrored in inspector.gd — the live card. `s` is roughly the half-size.
func _draw_heart(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var r := 0.5 * s
	var ly := c.y - 0.30 * s
	var lx := 0.50 * s
	ci.draw_circle(Vector2(c.x - lx, ly), r, col)
	ci.draw_circle(Vector2(c.x + lx, ly), r, col)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - lx - r, ly), Vector2(c.x + lx + r, ly), Vector2(c.x, c.y + 0.95 * s),
	]), col)


func _draw_heart_glyph(icon: Control, dim: float) -> void:
	_draw_heart(icon, icon.size * 0.5, 6.5, Color(0.93, 0.26, 0.33, dim))


## Point-in-triangle by edge-sign consistency, for the texture bake.
func _in_tri(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y)
	var d2 := (p.x - c.x) * (b.y - c.y) - (b.x - c.x) * (p.y - c.y)
	var d3 := (p.x - a.x) * (c.y - a.y) - (c.x - a.x) * (p.y - a.y)
	var has_neg := d1 < 0.0 or d2 < 0.0 or d3 < 0.0
	var has_pos := d1 > 0.0 or d2 > 0.0 or d3 > 0.0
	return not (has_neg and has_pos)
