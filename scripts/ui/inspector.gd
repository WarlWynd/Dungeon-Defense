extends Control
class_name Inspector

## Tap any unit on the board and it appears here, live.
##
## This is deliberately NOT the Bestiary. The Bestiary tells you what a Squire
## IS (static, reference, read it once). The Inspector tells you what THAT ONE
## is doing RIGHT NOW: how much HP it has left, whether it's carrying 160 gold
## out of your vault, whether a Paladin is blessing it so your Succubus can't
## touch it.
##
## Static reference answers "what should I build?". Live state answers "what is
## going wrong, right now?" — and on a board of identical coloured dots, that
## second question is the one the player actually has.

signal sell_requested(trap: Node2D)

var _target: Node2D = null
var _priority_btn: Button
var _sell_btn: Button

const W := 268.0
const PAD := 12.0


func _ready() -> void:
	## The card itself ignores clicks, but the priority button must not.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	## TARGETING PRIORITY. The player cannot move a turret, but they can tell
	## it who matters — this button is the entire answer to "the healer stands
	## at the back and my traps will never shoot her".
	_priority_btn = Button.new()
	_priority_btn.custom_minimum_size = Vector2(W - PAD * 2.0, 40)
	_priority_btn.position = Vector2(PAD, 8)
	_priority_btn.visible = false
	_priority_btn.pressed.connect(_on_priority_pressed)
	add_child(_priority_btn)

	## Sell sits on every trap card (not just turrets). A dedicated button rather
	## than a step in the targeting cycle, so cycling priority can't sell by
	## accident. Position is set per-card in show_unit.
	_sell_btn = Button.new()
	_sell_btn.custom_minimum_size = Vector2(W - PAD * 2.0, 32)
	_sell_btn.visible = false
	_sell_btn.pressed.connect(_on_sell_pressed)
	add_child(_sell_btn)


func _on_priority_pressed() -> void:
	var trap := _target as Trap
	if trap == null:
		return
	trap.cycle_targeting()
	queue_redraw()


func _on_sell_pressed() -> void:
	if _target is Trap:
		sell_requested.emit(_target)


## Fill the Sell button with "Sell  +N" and a gold coin glyph instead of the word
## "Gold". Content rides inside the button (mouse ignored) so the whole thing stays
## one tap target; rebuilt each time because the refund text changes per trap.
func _build_sell_content(refund: int) -> void:
	for c in _sell_btn.get_children():
		c.queue_free()
	_sell_btn.text = ""

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sell_btn.add_child(row)

	var lbl := Label.new()
	lbl.text = "Sell   +%d" % refund
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	var coin := Control.new()
	coin.custom_minimum_size = Vector2(15, 16)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.draw.connect(_draw_sell_coin.bind(coin))
	row.add_child(coin)


## Gold coin — matches the HUD/Bestiary coin.
func _draw_sell_coin(icon: Control) -> void:
	var ctr := icon.size * 0.5
	var body := Color(1.0, 0.82, 0.22)
	var rim := Color(0.6, 0.45, 0.08)
	icon.draw_circle(ctr, 7.0, rim)
	icon.draw_circle(ctr, 5.8, body)
	icon.draw_arc(ctr, 4.0, 0.0, TAU, 20, rim, 1.0)
	icon.draw_circle(ctr + Vector2(-1.8, -1.8), 1.5, Color(1.0, 0.92, 0.55))


func show_unit(unit: Node2D) -> void:
	_target = unit
	visible = unit != null

	## Only turrets choose a target, and only if they aren't 'simple' (fixed) — the
	## Dart Launcher shows no priority button at all.
	var trap := unit as Trap
	var has_priority := trap != null and trap.data.kind == TrapData.Kind.TURRET \
			and not trap.data.fixed_targeting
	_priority_btn.visible = has_priority

	## Sell is offered for any trap, parked at the bottom of the card (whose height
	## _trap_card_height mirrors what _draw_trap_card lays out).
	if trap != null:
		_build_sell_content(Trap.sell_value(trap.data))
		_sell_btn.position = Vector2(PAD, _trap_card_height(has_priority) - 40.0)
		_sell_btn.visible = true
	else:
		_sell_btn.visible = false
	queue_redraw()


func clear() -> void:
	_target = null
	visible = false
	_priority_btn.visible = false
	_sell_btn.visible = false


func target() -> Node2D:
	return _target


func _process(_delta: float) -> void:
	if not visible:
		return
	## The unit can die or escape while you're looking at it. That's not an
	## error, it's the game — just close the card.
	if _target == null or not is_instance_valid(_target):
		clear()
		return
	queue_redraw()


func _draw() -> void:
	if _target == null or not is_instance_valid(_target):
		return

	var hero := _target as Hero
	var minion := _target as Minion
	var trap := _target as Trap

	if trap != null:
		_draw_trap_card(trap)
		return

	if hero != null:
		_draw_card(_hero_lines(hero), hero.data.display_name, hero.data.color,
				hero.hp, hero.data.max_hp, Color(0.85, 0.25, 0.25))
	elif minion != null:
		## Name the CREATURE, not the arrival group. You tapped a Goblin, not
		## a "Goblin Pack" — the pack is three separate creatures, and the one
		## under your finger has its own HP and its own imminent death.
		var name := minion.data.unit_display()
		if minion.pack_size > 1:
			name += "  (%d of %d)" % [minion.pack_index + 1, minion.pack_size]
		_draw_card(_minion_lines(minion), name,
				minion.data.color, minion.hp, minion.data.max_hp,
				Color(0.4, 0.85, 0.4))


## LIVE state first, stats second. What it's doing beats what it is.
func _hero_lines(h: Hero) -> Array:
	var lines := []

	match h.state:
		Hero.State.ADVANCING:
			lines.append(["Heading for your vault", Color(0.9, 0.9, 0.9)])
		Hero.State.LOOTING:
			lines.append(["LOOTING YOUR HOARD", Color(1.0, 0.5, 0.2)])
		Hero.State.FLEEING:
			lines.append(["ESCAPING — KILL IT", Color(1.0, 0.3, 0.25)])
		Hero.State.CHARMED:
			lines.append(["Charmed — going nowhere", Color(1.0, 0.5, 0.8)])
		Hero.State.RETURNING:
			lines.append(["Charmed — bringing it BACK", Color(0.5, 1.0, 0.6)])
		_:
			lines.append(["", Color.WHITE])

	## The number the player is actually panicking about.
	if h.is_carrying():
		lines.append(["Carrying %d of your Gold" % h.carried_gold,
				Color(1.0, 0.84, 0.25)])
	elif h.data.greed > 0:
		lines.append(["Will steal %d" % h.data.greed, Color(0.75, 0.68, 0.4)])

	## What's on the corpse.
	lines.append(["Plunder: %d Gold if it dies here" % h.data.bounty,
			Color(1.0, 0.92, 0.55)])

	## The healer, called out in green — she is very often the reason the
	## player's traps appear to have stopped working.
	if h.data.heal_amount > 0.0:
		if h.is_charmed():
			lines.append(["Charmed — HEALING NOBODY", Color(0.5, 1.0, 0.7)])
		else:
			lines.append(["HEALING %.1f HP/sec — KILL HER FIRST"
					% (h.data.heal_amount / h.data.heal_rate),
					Color(0.5, 1.0, 0.7)])

	if h.data.purity_aura > 0.0:
		lines.append(["Blessing its escort (%d%%)"
				% int(h.data.purity_aura * 100.0), Color(1.0, 0.97, 0.7)])

	## THE LIVE ODDS. Purity is a dice roll, and the blessing changes the roll,
	## so the player needs the number that applies RIGHT NOW — not the stat on
	## the card. "Charmable 15%" while a Paladin lives, "50%" once it's dead.
	var pct := int(h.data.charm_chance(0.5, 0.0) * 100.0)
	if h.is_blessed():
		pct = int(h.data.charm_chance(0.5, h.effective_purity() ) * 100.0)
	if pct <= 0:
		lines.append(["Incorruptible — charm will never land",
				Color(1.0, 0.97, 0.7)])
	elif h.is_blessed():
		lines.append(["BLESSED — charm lands only %d%% of the time" % pct,
				Color(1.0, 0.97, 0.7)])
	else:
		lines.append(["Charm lands %d%% of the time" % pct,
				Color(0.95, 0.6, 0.85)])

	lines.append(["", Color.WHITE])
	lines.append(["Armour %d%%   Magic %d%%   Purity %d%%" % [
			int(h.data.armor * 100.0), int(h.data.magic_defense * 100.0),
			int(h.effective_purity() * 100.0)], Color(0.7, 0.75, 0.85)])

	if h.data.damage > 0.0:
		lines.append(["Hits your minions for %d" % int(h.data.damage),
				Color(0.9, 0.6, 0.5)])
	else:
		lines.append(["Does not fight", Color(0.6, 0.6, 0.6)])

	return lines


func _minion_lines(m: Minion) -> Array:
	var lines := []

	## How many of its pack are still alive. Heroes kill minions now, so this
	## is a number the player will actually be watching.
	if m.pack_size > 1:
		var alive := 0
		for n in m.get_tree().get_nodes_in_group("minions"):
			var other := n as Minion
			if other != null and is_instance_valid(other) \
					and other.data.id == m.data.id:
				alive += 1
		lines.append(["%d of %d %ss still standing"
				% [alive, m.pack_size, m.data.unit_display()],
				Color(0.75, 0.9, 0.75)])

	if m.restless:
		lines.append(["RESTLESS — about to walk out", Color(1.0, 0.4, 0.25)])
	else:
		lines.append(["Loyal to the pile. For now.", Color(0.7, 0.9, 0.7)])

	if m.data.can_charm:
		lines.append(["Charms thieves into returning Gold",
				Color(1.0, 0.55, 0.8)])
	if m.data.pursue_thieves_first:
		lines.append(["Hunts whoever carries your Gold",
				Color(0.8, 0.9, 0.8)])

	lines.append(["", Color.WHITE])
	lines.append(["Hits for %d every %.1fs" % [int(m.data.damage),
			m.data.attack_rate], Color(0.7, 0.85, 0.7)])
	lines.append(["Stays while hoard > %d%%"
			% int(m.data.allure_desert * 100.0), Color(0.75, 0.75, 0.6)])
	return lines


## Heart as primitives — two lobes and a triangle to the point. Mirrors the
## Bestiary's _draw_heart so the HP heart looks the same on the card and in the
## book. `s` is roughly the half-size.
func _draw_heart(c: Vector2, s: float, col: Color) -> void:
	var r := 0.5 * s
	var ly := c.y - 0.30 * s
	var lx := 0.50 * s
	draw_circle(Vector2(c.x - lx, ly), r, col)
	draw_circle(Vector2(c.x + lx, ly), r, col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - lx - r, ly), Vector2(c.x + lx + r, ly), Vector2(c.x, c.y + 0.95 * s),
	]), col)


## Rounded background panel with a colored border, shared by every card.
func _draw_rounded_panel(rect: Rect2, bg: Color, border: Color, border_w: float, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(int(border_w))
	sb.set_corner_radius_all(radius)
	draw_style_box(sb, rect)


## Card height, shared by the drawing and the sell-button placement so they can't
## drift. Turrets reserve the top strip for the priority button; every trap
## reserves the bottom strip for the sell button. `has_priority` = a turret whose
## targeting can actually be changed (not a 'simple' fixed one like the Dart).
func _trap_card_height(has_priority: bool) -> float:
	return (56.0 if has_priority else 8.0) + 96.0 + 42.0


## The trap card. Its whole reason for existing is the priority button at the
## top — everything below it is context for that one decision, and the sell
## button at the very bottom.
func _draw_trap_card(t: Trap) -> void:
	var f := ThemeDB.fallback_font
	var d := t.data
	var has_priority := d.kind == TrapData.Kind.TURRET and not d.fixed_targeting

	## Leave room for the button only when it's showing.
	var top := 56.0 if has_priority else 8.0
	var h := _trap_card_height(has_priority)

	_draw_rounded_panel(Rect2(Vector2.ZERO, Vector2(W, h)),
			Color(0.06, 0.05, 0.04, 0.92), Color(d.color, 0.75), 2.0, 10)

	if has_priority:
		_priority_btn.text = "Target: %s   (tap to change)" % Trap.targeting_name(
				t.targeting)

	draw_circle(Vector2(PAD + 8.0, top + 10.0), 7.0, d.color)
	draw_string(f, Vector2(PAD + 22.0, top + 16.0), d.display_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, d.color)

	var y := top + 40.0
	if d.damage > 0.0:
		draw_string(f, Vector2(PAD, y), "%d %s damage every %.2fs" % [
				int(d.damage), d.damage_type, d.fire_rate],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.85, 0.75))
	elif d.weaken_heal_cut > 0.0:
		draw_string(f, Vector2(PAD, y), "ROT: +%d%% damage taken" % int(
				d.weaken_damage_bonus * 100.0),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.5, 0.7))
		y += 18.0
		draw_string(f, Vector2(PAD, y), "ROT: heals cut by %d%%" % int(
				d.weaken_heal_cut * 100.0),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.5, 0.7))
	elif d.slow_amount > 0.0:
		draw_string(f, Vector2(PAD, y), "Slows by %d%%" % int(
				d.slow_amount * 100.0),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 0.85, 0.95))

	y += 20.0
	draw_string(f, Vector2(PAD, y), d.flavor,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.55, 0.55, 0.55))


func _draw_card(lines: Array, title: String, col: Color, hp: float,
		max_hp: float, hp_col: Color) -> void:
	var f := ThemeDB.fallback_font
	var h := PAD * 2.0 + 62.0 + float(lines.size()) * 19.0

	_draw_rounded_panel(Rect2(Vector2.ZERO, Vector2(W, h)),
			Color(0.06, 0.05, 0.04, 0.92), Color(col, 0.7), 2.0, 10)

	draw_circle(Vector2(PAD + 9.0, PAD + 10.0), 8.0, col)
	draw_string(f, Vector2(PAD + 24.0, PAD + 16.0), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 19, col)

	# Live HP bar — the whole reason to tap a unit mid-fight.
	var pct := clampf(hp / max_hp, 0.0, 1.0)
	var bar := Vector2(PAD, PAD + 28.0)
	var bw := W - PAD * 2.0
	draw_rect(Rect2(bar, Vector2(bw, 12.0)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(bar, Vector2(bw * pct, 12.0)), hp_col)
	## Counter reads "42 / 42 ♥" — the heart replaces the "HP" label.
	var hp_text := "%d / %d" % [int(maxf(hp, 0.0)), int(max_hp)]
	draw_string(f, Vector2(PAD, PAD + 56.0), hp_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.85, 0.85))
	var tw := f.get_string_size(hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	_draw_heart(Vector2(PAD + tw + 9.0, PAD + 51.0), 6.0, Color(0.93, 0.26, 0.33))

	var y := PAD + 76.0
	for entry in lines:
		var text: String = entry[0]
		var c: Color = entry[1]
		if text != "":
			draw_string(f, Vector2(PAD, y), text,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 14, c)
		y += 19.0

	draw_string(f, Vector2(PAD, h - 6.0), "tap elsewhere to close",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.45, 0.45, 0.45))
