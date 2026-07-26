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
signal upgrade_requested(trap: Node2D)

var _target: Node2D = null
var _priority_btn: Button
var _sell_btn: Button
var _upgrade_btn: Button

## Last label written on the upgrade button, so _process can keep it current
## without rebuilding the row every frame.
var _upgrade_text: String = ""

const W := 268.0
const PAD := 12.0

## Upgrade sits left of Sell on one row: two buttons, one strip, and the card
## stays short enough for the panel it lives in.
const UPGRADE_FRAC := 0.54

## Type sizes, gathered here because they're what decides whether a line fits.
## Everything on a card is now WRAPPED to the card's inner width rather than
## drawn as one long line, so an over-long stat can't run off the edge — but
## wrapping trades width for height, so the sizes are kept modest to stop a card
## growing taller than the space it has.
const TITLE_SIZE := 16
const LEVEL_SIZE := 12
const STAT_SIZE := 13
const PREVIEW_SIZE := 12
const FLAVOR_SIZE := 11
const LINE_SIZE := 13          ## hero / minion card body lines

const PRIORITY_H := 34.0
const BUTTON_H := 30.0
const BLOCK_GAP := 3.0         ## between wrapped text blocks
const BOTTOM_PAD := 8.0

## The panel's bottom edge is parked this far above the window bottom (set in
## hud.gd). The card grows UPWARD from there, and the control is resized to match
## it — a fixed-height panel is what was clipping the taller cards.
const PANEL_BOTTOM := 72.0


func _ready() -> void:
	## The card itself ignores clicks, but the priority button must not.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	## TARGETING PRIORITY. The player cannot move a turret, but they can tell
	## it who matters — this button is the entire answer to "the healer stands
	## at the back and my traps will never shoot her".
	_priority_btn = Button.new()
	_priority_btn.custom_minimum_size = Vector2(W - PAD * 2.0, PRIORITY_H)
	_priority_btn.add_theme_font_size_override("font_size", STAT_SIZE)
	_priority_btn.position = Vector2(PAD, 8)
	_priority_btn.visible = false
	_priority_btn.pressed.connect(_on_priority_pressed)
	add_child(_priority_btn)

	## Sell sits on every trap card (not just turrets). A dedicated button rather
	## than a step in the targeting cycle, so cycling priority can't sell by
	## accident. Position is set per-card in show_unit.
	_sell_btn = Button.new()
	_sell_btn.visible = false
	_sell_btn.pressed.connect(_on_sell_pressed)
	add_child(_sell_btn)

	## UPGRADE. Build slots are scarce and Gold isn't, so making the trap you
	## already own better is the answer when there is nowhere left to build.
	_upgrade_btn = Button.new()
	_upgrade_btn.visible = false
	_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	add_child(_upgrade_btn)


func _on_priority_pressed() -> void:
	var trap := _target as Trap
	if trap == null:
		return
	trap.cycle_targeting()
	queue_redraw()


func _on_sell_pressed() -> void:
	if _target is Trap:
		sell_requested.emit(_target)


func _on_upgrade_pressed() -> void:
	if _target is Trap:
		upgrade_requested.emit(_target)


## Fill a gold button with "<text>" and a coin glyph instead of the word "Gold".
## Content rides inside the button (mouse ignored) so the whole thing stays one
## tap target; rebuilt whenever the number on it changes.
func _build_gold_content(btn: Button, text: String, with_coin: bool = true) -> void:
	for c in btn.get_children():
		c.queue_free()
	btn.text = ""

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	if with_coin:
		var coin := Control.new()
		coin.custom_minimum_size = Vector2(15, 16)
		coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.draw.connect(_draw_sell_coin.bind(coin))
		row.add_child(coin)


## Keep the upgrade button reading the truth: the next level's price, or MAX,
## and greyed out while the vault can't cover it. Called every frame the card is
## up (the hoard changes under the player mid-wave), but only rebuilds the row
## when the words actually change.
func _refresh_upgrade_btn(t: Trap) -> void:
	if not t.can_upgrade():
		if _upgrade_text != "max":
			_upgrade_text = "max"
			_build_gold_content(_upgrade_btn, "MAX Lv %d" % Trap.MAX_LEVEL, false)
		_upgrade_btn.disabled = true
		return
	var cost := t.next_upgrade_cost()
	var want := "Lv %d   %d" % [t.level + 1, cost]
	if want != _upgrade_text:
		_upgrade_text = want
		_build_gold_content(_upgrade_btn, want)
	_upgrade_btn.disabled = not EconomySystem.can_afford(cost)


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

	## Only a trap that can actually be re-targeted gets the button — the Dart
	## Launcher never can, and the Crossbow can't until Lv 2.
	var trap := unit as Trap
	_priority_btn.visible = trap != null and trap.can_retarget()

	## Upgrade + Sell share the bottom strip of any trap card (whose height
	## _trap_card_height mirrors what _draw_trap_card lays out).
	if trap != null:
		var strip := W - PAD * 2.0
		var up_w := floorf(strip * UPGRADE_FRAC) - 4.0
		var y: float = _trap_card_layout(trap)["height"] - BUTTON_H - BOTTOM_PAD

		_upgrade_text = ""            ## force a rebuild for this trap
		_refresh_upgrade_btn(trap)
		_upgrade_btn.custom_minimum_size = Vector2(up_w, BUTTON_H)
		_upgrade_btn.size = Vector2(up_w, BUTTON_H)
		_upgrade_btn.position = Vector2(PAD, y)
		_upgrade_btn.visible = true

		var sell_w := strip - up_w - 8.0
		_build_gold_content(_sell_btn, "Sell  +%d" % trap.sell_value())
		_sell_btn.custom_minimum_size = Vector2(sell_w, BUTTON_H)
		_sell_btn.size = Vector2(sell_w, BUTTON_H)
		_sell_btn.position = Vector2(PAD + up_w + 8.0, y)
		_sell_btn.visible = true
	else:
		_sell_btn.visible = false
		_upgrade_btn.visible = false
	_fit_panel()
	queue_redraw()


## The refund and the upgrade price both move when a trap levels up, so re-run
## the same layout the card was built with.
func refresh_trap_buttons() -> void:
	if _target is Trap:
		show_unit(_target)


func clear() -> void:
	_target = null
	visible = false
	_priority_btn.visible = false
	_sell_btn.visible = false
	_upgrade_btn.visible = false


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
	## Gold moves while the card is open, so the upgrade price has to stay honest
	## about whether it's affordable right now.
	if _target is Trap:
		_refresh_upgrade_btn(_target as Trap)
	## A live card changes length as the unit does — a hero picks up gold, a
	## minion's pack thins — so the panel is re-fitted rather than fixed at open.
	_fit_panel()
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
			lines.append(["Heading for your vault", Settings.scheme().text])
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
			int(h.effective_purity() * 100.0)], Settings.scheme().dim])

	if h.data.damage > 0.0:
		lines.append(["Hits your minions for %d" % int(h.data.damage),
				Color(0.9, 0.6, 0.5)])
	else:
		lines.append(["Does not fight", Settings.scheme().dim])

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
	## Only the AUTO units are held by the hoard at all; the bought and earned ones
	## are yours for good, and telling the player they might leave would be a lie.
	if m.data.acquire_mode == "auto":
		lines.append(["Stays while the hoard is over %d Gold"
				% int(m.data.allure_desert), Settings.scheme().dim])
	else:
		lines.append(["Yours for good — never deserts", Settings.scheme().dim])
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


## THE CARD'S CHROME FOLLOWS THE PALETTE. Panel and border were fixed near-black
## and the unit's own colour, which left the card looking identical in every
## scheme — and unreadable in the light one, where dark text was being drawn on a
## black card. The unit's colour still identifies it, through the dot and the
## name; the box around it belongs to the theme, and the accent border matches
## the dungeon board's outline (see Board.BOARD_BORDER_ALPHA).
func _draw_card_panel(rect: Rect2, s: ColorScheme) -> void:
	_draw_rounded_panel(rect, Color(s.panel, 0.94), Color(s.accent, 0.75), 2.0, 10)


## Every text block on the trap card, in order. The layout measures this list and
## the drawing walks the same list, so a line can't be sized one way and painted
## another — which is exactly how the card came to be laid out for one line of
## flavour while drawing two.
func _trap_card_blocks(t: Trap) -> Array:
	var d := t.data
	var blocks := []
	var stat_col := _trap_stat_color(d)
	for line in _trap_stat_lines(d, t.level):
		blocks.append({"text": line, "size": STAT_SIZE, "color": stat_col})
	## A turret that WILL be able to choose, but can't yet, has to say so — an
	## absent button otherwise just looks like the card failed to draw one.
	if d.kind == TrapData.Kind.TURRET and not d.fixed_targeting and not t.can_retarget():
		blocks.append({"text": "Shoots %s — picks its own target at Lv %d" % [
					Trap.targeting_name(t.targeting).to_lower(), d.targeting_level],
				"size": PREVIEW_SIZE, "color": Settings.scheme().dim})
	## WHAT THE MONEY BUYS. The upgrade button shows a price; this shows the thing
	## being bought, in the same words as the line above it.
	if t.can_upgrade():
		var next_lines := _trap_stat_lines(d, t.level + 1)
		if not next_lines.is_empty():
			## Green stays fixed, deliberately: like the win/loss banner it encodes a
			## MEANING — "pay and this improves" — which shouldn't change sense
			## because the player picked a different palette.
			blocks.append({"text": "Lv %d:  %s" % [t.level + 1, next_lines[0]],
					"size": PREVIEW_SIZE, "color": Color(0.45, 0.85, 0.55)})
	if d.flavor != "":
		blocks.append({"text": d.flavor, "size": FLAVOR_SIZE,
				"color": Settings.scheme().dim})
	return blocks


## ONE layout for the trap card, measured once and used by the drawing, the
## button placement AND the panel's own height.
##
## Nothing here can be a constant: the flavour wraps to one line or three
## depending on the trap, auras carry two stat lines where turrets carry one, and
## the next-level preview disappears at Lv 5.
func _trap_card_layout(t: Trap) -> Dictionary:
	var f := ThemeDB.fallback_font
	var d := t.data
	var has_priority: bool = t.can_retarget()
	## Turrets reserve the top strip for the priority button.
	var top := (PRIORITY_H + 16.0) if has_priority else 8.0
	var body_w := W - PAD * 2.0

	## Walk the blocks in "top of line" space; draw_multiline_string wants a
	## BASELINE, so each block records its own top plus that size's ascent.
	var cursor := top + 28.0
	var placed := []
	for b in _trap_card_blocks(t):
		var size: int = b["size"]
		var bh: float = f.get_multiline_string_size(b["text"],
				HORIZONTAL_ALIGNMENT_LEFT, body_w, size).y
		placed.append({"text": b["text"], "size": size, "color": b["color"],
				"baseline": cursor + f.get_ascent(size)})
		cursor += bh + BLOCK_GAP

	return {
		"has_priority": has_priority,
		"top": top,
		"body_w": body_w,
		"blocks": placed,
		"height": cursor + 8.0 + BUTTON_H + BOTTOM_PAD,
	}


## Resize the panel to whatever card is showing. The control is anchored to the
## bottom, so moving its top edge grows the card upward into empty space instead
## of letting it run off the bottom of its own rect.
func _fit_panel() -> void:
	var h := _card_height()
	if h > 0.0:
		offset_top = -(h + PANEL_BOTTOM)


func _card_height() -> float:
	if _target == null or not is_instance_valid(_target):
		return 0.0
	var trap := _target as Trap
	if trap != null:
		return _trap_card_layout(trap)["height"]
	var hero := _target as Hero
	if hero != null:
		return _unit_card_height(_hero_lines(hero))
	var minion := _target as Minion
	if minion != null:
		return _unit_card_height(_minion_lines(minion))
	return 0.0


## Body text is the palette's text colour whatever the trap does — the kind of
## stat is already said in the words ("ROT:", "Slows by"), so it doesn't need a
## colour of its own, and three fixed pastels ignored the scheme entirely.
func _trap_stat_color(_d: TrapData) -> Color:
	return Settings.scheme().text


## The trap's numbers AT A GIVEN LEVEL — one function, used for both the live
## line and the next-level preview, so the two can never disagree about how
## levels scale.
func _trap_stat_lines(d: TrapData, lvl: int) -> Array:
	var out := []
	if d.damage > 0.0:
		out.append("%d %s damage every %.2fs" % [
				int(round(Trap.damage_at(d, lvl))), d.damage_type,
				Trap.fire_rate_at(d, lvl)])
	elif d.weaken_heal_cut > 0.0:
		out.append("ROT: +%d%% damage taken" % int(Trap.rot_bonus_at(d, lvl) * 100.0))
		out.append("ROT: heals cut by %d%%" % int(Trap.heal_cut_at(d, lvl) * 100.0))
	elif d.slow_amount > 0.0:
		out.append("Slows by %d%%" % int(Trap.slow_at(d, lvl) * 100.0))
	return out


## The trap card. Its whole reason for existing is the priority button at the
## top — everything below it is context for that one decision, and the Upgrade
## and Sell buttons at the very bottom.
func _draw_trap_card(t: Trap) -> void:
	var f := ThemeDB.fallback_font
	var d := t.data
	var lay := _trap_card_layout(t)
	var has_priority: bool = lay["has_priority"]
	var top: float = lay["top"]
	var h: float = lay["height"]
	var body_w: float = lay["body_w"]

	var s: ColorScheme = Settings.scheme()
	_draw_card_panel(Rect2(Vector2.ZERO, Vector2(W, h)), s)

	if has_priority:
		_priority_btn.text = "Target: %s  (tap to change)" % Trap.targeting_name(
				t.targeting)

	## Level is right-aligned on the title row, so measure it first and give the
	## name whatever width is left — "Explosive Turret" and "Lv 1/5" together are
	## wider than the card, and the name is the half that can be trimmed.
	var lvl_text := "Lv %d/%d" % [t.level, Trap.MAX_LEVEL]
	var lvl_col := s.accent if t.level > 1 else s.dim
	var lw := f.get_string_size(lvl_text, HORIZONTAL_ALIGNMENT_LEFT, -1, LEVEL_SIZE).x
	draw_string(f, Vector2(W - PAD - lw, top + 14.0), lvl_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, LEVEL_SIZE, lvl_col)

	draw_circle(Vector2(PAD + 7.0, top + 9.0), 6.0, d.color)
	draw_string(f, Vector2(PAD + 19.0, top + 14.0), d.display_name,
			HORIZONTAL_ALIGNMENT_LEFT, body_w - lw - 26.0, TITLE_SIZE, d.color)

	## Every block wrapped to the card's inner width — none of this text is a
	## length we control, and the stat lines grow as a trap levels.
	for b in lay["blocks"]:
		f.draw_multiline_string(get_canvas_item(), Vector2(PAD, b["baseline"]),
				b["text"], HORIZONTAL_ALIGNMENT_LEFT, body_w, b["size"], -1, b["color"])


## Where the hero/minion card's body starts — below the title row and the HP bar.
const UNIT_BODY_TOP := 76.0


## Same measure-then-draw contract as the trap card: every body line is wrapped
## to the card width, so the height depends on how many lines that WRAPS to, not
## on how many entries were passed in. "HEALING 5.6 HP/sec — KILL HER FIRST" is
## wider than the card on its own.
func _unit_card_height(lines: Array) -> float:
	var f := ThemeDB.fallback_font
	var body_w := W - PAD * 2.0
	var h := PAD + UNIT_BODY_TOP
	for entry in lines:
		var text: String = entry[0]
		if text == "":
			h += float(LINE_SIZE) * 0.6      ## a blank entry is a spacer
			continue
		h += f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
				body_w, LINE_SIZE).y + BLOCK_GAP
	return h + 18.0                          ## room for the "tap to close" line


func _draw_card(lines: Array, title: String, col: Color, hp: float,
		max_hp: float, hp_col: Color) -> void:
	var f := ThemeDB.fallback_font
	var body_w := W - PAD * 2.0
	var h := _unit_card_height(lines)
	var s: ColorScheme = Settings.scheme()

	_draw_card_panel(Rect2(Vector2.ZERO, Vector2(W, h)), s)

	draw_circle(Vector2(PAD + 9.0, PAD + 10.0), 8.0, col)
	draw_string(f, Vector2(PAD + 24.0, PAD + 16.0), title,
			HORIZONTAL_ALIGNMENT_LEFT, body_w - 24.0, 17, col)

	# Live HP bar — the whole reason to tap a unit mid-fight.
	var pct := clampf(hp / max_hp, 0.0, 1.0)
	var bar := Vector2(PAD, PAD + 28.0)
	var bw := W - PAD * 2.0
	## Empty track derived from the palette's text colour, so it's a dark trough on
	## a dark card and a light one on Sandstone. The FILL keeps its own colour —
	## red for a raider, green for one of yours — because that's what it means.
	draw_rect(Rect2(bar, Vector2(bw, 12.0)), Color(s.text, 0.18))
	draw_rect(Rect2(bar, Vector2(bw * pct, 12.0)), hp_col)
	## Counter reads "42 / 42 ♥" — the heart replaces the "HP" label.
	var hp_text := "%d / %d" % [int(maxf(hp, 0.0)), int(max_hp)]
	draw_string(f, Vector2(PAD, PAD + 56.0), hp_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, s.text)
	var tw := f.get_string_size(hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	_draw_heart(Vector2(PAD + tw + 9.0, PAD + 51.0), 6.0, Color(0.93, 0.26, 0.33))

	## Walked exactly as _unit_card_height measures it, so the panel it sized can
	## always hold what's painted here.
	var y := PAD + UNIT_BODY_TOP
	for entry in lines:
		var text: String = entry[0]
		var c: Color = entry[1]
		if text == "":
			y += float(LINE_SIZE) * 0.6
			continue
		var bh: float = f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
				body_w, LINE_SIZE).y
		f.draw_multiline_string(get_canvas_item(), Vector2(PAD, y + f.get_ascent(LINE_SIZE)),
				text, HORIZONTAL_ALIGNMENT_LEFT, body_w, LINE_SIZE, -1, c)
		y += bh + BLOCK_GAP

	draw_string(f, Vector2(PAD, h - 6.0), "tap elsewhere to close",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, s.dim)
