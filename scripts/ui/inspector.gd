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

var _target: Node2D = null
var _priority_btn: Button

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


func _on_priority_pressed() -> void:
	var trap := _target as Trap
	if trap == null:
		return
	trap.cycle_targeting()
	queue_redraw()


func show_unit(unit: Node2D) -> void:
	_target = unit
	visible = unit != null

	## Only turrets choose a target. Area traps hit everything in range anyway.
	var trap := unit as Trap
	var is_turret := trap != null and trap.data.kind == TrapData.Kind.TURRET
	_priority_btn.visible = is_turret
	queue_redraw()


func clear() -> void:
	_target = null
	visible = false
	_priority_btn.visible = false


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
		lines.append(["Carrying %d of your gold" % h.carried_gold,
				Color(1.0, 0.84, 0.25)])
	elif h.data.greed > 0:
		lines.append(["Will steal %d" % h.data.greed, Color(0.75, 0.68, 0.4)])

	## What's on the corpse.
	lines.append(["Plunder: %d gold if it dies here" % h.data.bounty,
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
		lines.append(["Charms thieves into returning gold",
				Color(1.0, 0.55, 0.8)])
	if m.data.pursue_thieves_first:
		lines.append(["Hunts whoever carries your gold",
				Color(0.8, 0.9, 0.8)])

	lines.append(["", Color.WHITE])
	lines.append(["Hits for %d every %.1fs" % [int(m.data.damage),
			m.data.attack_rate], Color(0.7, 0.85, 0.7)])
	lines.append(["Stays while hoard > %d%%"
			% int(m.data.allure_desert * 100.0), Color(0.75, 0.75, 0.6)])
	return lines


## The trap card. Its whole reason for existing is the priority button at the
## top — everything below it is context for that one decision.
func _draw_trap_card(t: Trap) -> void:
	var f := ThemeDB.fallback_font
	var d := t.data
	var is_turret := d.kind == TrapData.Kind.TURRET

	## Leave room for the button when it's showing.
	var top := 56.0 if is_turret else 8.0
	var h := top + 96.0

	draw_rect(Rect2(Vector2.ZERO, Vector2(W, h)), Color(0.06, 0.05, 0.04, 0.92))
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, h)), Color(d.color, 0.75), false, 2.0)

	if is_turret:
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

	draw_rect(Rect2(Vector2.ZERO, Vector2(W, h)), Color(0.06, 0.05, 0.04, 0.92))
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, h)), Color(col, 0.7), false, 2.0)

	draw_circle(Vector2(PAD + 9.0, PAD + 10.0), 8.0, col)
	draw_string(f, Vector2(PAD + 24.0, PAD + 16.0), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 19, col)

	# Live HP bar — the whole reason to tap a unit mid-fight.
	var pct := clampf(hp / max_hp, 0.0, 1.0)
	var bar := Vector2(PAD, PAD + 28.0)
	var bw := W - PAD * 2.0
	draw_rect(Rect2(bar, Vector2(bw, 12.0)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(bar, Vector2(bw * pct, 12.0)), hp_col)
	draw_string(f, Vector2(PAD, PAD + 56.0),
			"%d / %d HP" % [int(maxf(hp, 0.0)), int(max_hp)],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.85, 0.85))

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
