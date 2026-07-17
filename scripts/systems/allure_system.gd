extends Node
class_name AllureSystem

## ALLURE — your gold CALLS monsters. A big pile draws them out of the dark; you
## don't buy minions, you attract them by being rich, and they leave when poor.
## Guardrails prevent a death-spiral: evaluated only between waves, hysteresis
## buffer, telegraphed desertion, and a safety-net tier that never fully leaves.

signal roster_changed()

var _spawn_points: Array[Vector2] = []
var _active: Dictionary = {}      ## minion id -> Array[Minion]
var _bases: Dictionary = {}       ## minion id -> int (post index they started at)
var _container: Node2D
var _wave: int = 0                 ## current wave index, drives "earn" unlocks


func setup(container: Node2D, spawn_points: Array[Vector2]) -> void:
	_container = container
	_spawn_points = spawn_points


## Tell the system which wave we're on and let any newly-earned Anti-Heroes
## unlock and walk out. Called at the start of every build phase.
func advance_to_wave(w: int) -> void:
	_wave = w
	_unlock_earned()
	refresh_arrivals()


## Which minions WOULD be present at a hypothetical hoard fraction. Pure — the
## HUD uses it to preview what a purchase costs BEFORE you commit.
func roster_at(fraction: float) -> Array[String]:
	var out: Array[String] = []
	for key in GameData.minions.keys():
		var id: String = key
		var d: MinionData = GameData.minions[id]
		var keep: bool
		if _is_present(id):
			keep = _should_keep(id, d, fraction)
		else:
			keep = _should_arrive(id, d, fraction)
		if keep:
			out.append(id)
	return out


## Called BETWEEN WAVES only (level start + the moment the last hero falls).
## Deserts the too-expensive, arrives the newly-affordable, heals survivors,
## and replaces the dead. Never mid-wave.
func refresh_roster() -> void:
	_unlock_earned()
	var frac := EconomySystem.hoard_fraction()
	for key in GameData.minions.keys():
		var id: String = key
		var d: MinionData = GameData.minions[id]
		if _is_present(id):
			if _should_keep(id, d, frac):
				_set_restless(id, false)
				_mend(id, d)
				_reinforce(id, d)
			else:
				_desert(id, d)
		else:
			if _should_arrive(id, d, frac):
				_arrive(id, d)
	roster_changed.emit()


## Arrivals ONLY — safe to call mid-wave. Brings out any minion that is absent
## but now affordable (hoard >= its arrive threshold). Deliberately does NOT
## desert, mend, or reinforce: a growing pile should attract help the instant it
## grows, but LOSING minions stays between-wave (see refresh_roster) so the
## restless telegraph and anti-death-spiral guardrails are preserved.
func refresh_arrivals() -> void:
	if _container == null or not is_instance_valid(_container):
		return
	var frac := EconomySystem.hoard_fraction()
	var changed := false
	for key in GameData.minions.keys():
		var id: String = key
		var d: MinionData = GameData.minions[id]
		if _is_present(id):
			continue
		if _should_arrive(id, d, frac):
			_arrive(id, d)
			changed = true
	if changed:
		roster_changed.emit()


## Acquisition rules. AUTO units (the Succubus) are drawn purely by the size of
## the hoard. BUY/EARN units are present once UNLOCKED (bought with souls/gems in
## the store, or earned by progression) and then never leave on their own.
func _should_arrive(id: String, d: MinionData, frac: float) -> bool:
	if d.acquire_mode == "auto":
		return frac >= d.allure_arrive
	return Bank.is_unlocked(id)


func _should_keep(id: String, d: MinionData, frac: float) -> bool:
	if d.acquire_mode == "auto":
		return frac >= d.allure_desert
	return Bank.is_unlocked(id)


## Permanently unlock any "earn" Anti-Hero whose wave has been reached.
func _unlock_earned() -> void:
	for key in GameData.minions.keys():
		var id: String = key
		var d: MinionData = GameData.minions[id]
		if d.acquire_mode == "earn" and not Bank.is_unlocked(id) and _wave >= d.unlock_wave:
			Bank.unlock(id)


func _mend(id: String, d: MinionData) -> void:
	_prune(id)
	if not _active.has(id):
		return
	var list: Array = _active[id]
	for m in list:
		if not is_instance_valid(m):
			continue
		var minion := m as Minion
		if minion != null and minion.hp < d.max_hp:
			minion.hp = d.max_hp
			minion.queue_redraw()


func _reinforce(id: String, d: MinionData) -> void:
	_prune(id)
	if not _active.has(id):
		return
	var list: Array = _active[id]
	var missing: int = d.count - list.size()
	if missing <= 0:
		return
	var taken := {}
	for m in list:
		var minion := m as Minion
		if minion != null:
			taken[minion.pack_index] = true
	var base: int = _bases.get(id, 0)
	var added := 0
	for i in d.count:
		if taken.has(i):
			continue
		var m := Minion.new()
		m.setup(d, _pick_spawn(base + i))
		m.pack_index = i
		m.pack_size = d.count
		m.add_to_group("minions")
		_container.add_child(m)
		list.append(m)
		added += 1
	_active[id] = list
	if added > 0:
		EventBus.minion_reinforced.emit(d, added)


## Telegraph who's about to leave, during the build window.
func update_restless_flags() -> void:
	var frac := EconomySystem.hoard_fraction()
	for key in _active.keys():
		var id: String = key
		var d: MinionData = GameData.minions[id]
		var leaving: bool = d.acquire_mode == "auto" and frac < d.allure_desert
		_set_restless(id, leaving)
		if leaving:
			EventBus.minion_restless.emit(d)
	roster_changed.emit()


## Prune freed minions. CHECK is_instance_valid FIRST on the raw reference — a
## cast to Minion on a freed object throws before the guard can help.
func _prune(id: String) -> void:
	if not _active.has(id):
		return
	var list: Array = _active[id]
	var alive: Array = []
	for m in list:
		if is_instance_valid(m):
			alive.append(m)
	if alive.is_empty():
		_active.erase(id)
	else:
		_active[id] = alive


func _prune_all() -> void:
	for key in _active.keys():
		var id: String = key
		_prune(id)


func _is_present(id: String) -> bool:
	_prune(id)
	if not _active.has(id):
		return false
	var list: Array = _active[id]
	return not list.is_empty()


func active_ids() -> Array:
	_prune_all()
	var out := []
	for key in _active.keys():
		var id: String = key
		if _is_present(id):
			out.append(id)
	return out


func is_restless(id: String) -> bool:
	_prune(id)
	if not _active.has(id):
		return false
	var list: Array = _active[id]
	for m in list:
		if not is_instance_valid(m):
			continue
		var minion := m as Minion
		if minion != null and minion.restless:
			return true
	return false


func clear() -> void:
	for key in _active.keys():
		var id: String = key
		var list: Array = _active[id]
		for m in list:
			if not is_instance_valid(m):
				continue
			var minion := m as Minion
			if minion != null:
				minion.queue_free()
	_active.clear()


func _arrive(id: String, d: MinionData) -> void:
	var start := _posted_count()
	_bases[id] = start
	var list: Array = []
	for i in d.count:
		var m := Minion.new()
		m.setup(d, _pick_spawn(start + i))
		m.pack_index = i
		m.pack_size = d.count
		m.add_to_group("minions")
		_container.add_child(m)
		list.append(m)
	_active[id] = list
	EventBus.minion_arrived.emit(d)


func _posted_count() -> int:
	_prune_all()
	var n := 0
	for key in _active.keys():
		var id: String = key
		var list: Array = _active[id]
		n += list.size()
	return n


func _desert(id: String, d: MinionData) -> void:
	if not _active.has(id):
		return
	var list: Array = _active[id]
	for m in list:
		if not is_instance_valid(m):
			continue
		var minion := m as Minion
		if minion != null:
			minion.queue_free()
	_active.erase(id)
	_bases.erase(id)
	EventBus.minion_deserted.emit(d)


func _set_restless(id: String, value: bool) -> void:
	_prune(id)
	if not _active.has(id):
		return
	var list: Array = _active[id]
	for m in list:
		if not is_instance_valid(m):
			continue
		var minion := m as Minion
		if minion != null:
			minion.restless = value
			minion.queue_redraw()


func _pick_spawn(i: int) -> Vector2:
	if _spawn_points.is_empty():
		return Vector2.ZERO
	var n := _spawn_points.size()
	var base: Vector2 = _spawn_points[i % n]
	var ring := i / n
	if ring == 0:
		return base
	var angle := TAU * float(i % n) / float(n) + float(ring) * 0.7
	return base + Vector2(cos(angle), sin(angle)) * (26.0 * float(ring))
