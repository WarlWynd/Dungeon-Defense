extends Node
class_name AllureSystem

## ALLURE — your gold CALLS monsters. A big pile draws them out of the dark; you
## don't buy minions, you attract them by being rich, and they leave when poor.
## Guardrails prevent a death-spiral: evaluated only between waves, hysteresis
## buffer, telegraphed desertion, and a safety-net tier that never fully leaves.

signal roster_changed()

const SAFETY_NET_ID := "goblin_pack"

var _spawn_points: Array[Vector2] = []
var _active: Dictionary = {}      ## minion id -> Array[Minion]
var _bases: Dictionary = {}       ## minion id -> int (post index they started at)
var _container: Node2D


func setup(container: Node2D, spawn_points: Array[Vector2]) -> void:
	_container = container
	_spawn_points = spawn_points


## Which minions WOULD be present at a hypothetical hoard fraction. Pure — the
## HUD uses it to preview what a purchase costs BEFORE you commit.
func roster_at(fraction: float) -> Array[String]:
	var out: Array[String] = []
	for key in GameData.minions.keys():
		var id: String = key
		var d: MinionData = GameData.minions[id]
		var present: bool = _is_present(id)
		var keep: bool
		if present:
			keep = (fraction >= d.allure_desert) or (id == SAFETY_NET_ID)
		else:
			keep = fraction >= d.allure_arrive
		if keep:
			out.append(id)
	return out


## Called BETWEEN WAVES only (level start + the moment the last hero falls).
## Deserts the too-expensive, arrives the newly-affordable, heals survivors,
## and replaces the dead. Never mid-wave.
func refresh_roster() -> void:
	var frac := EconomySystem.hoard_fraction()
	for key in GameData.minions.keys():
		var id: String = key
		var d: MinionData = GameData.minions[id]
		var present: bool = _is_present(id)
		if present:
			if frac < d.allure_desert and id != SAFETY_NET_ID:
				_desert(id, d)
			else:
				_set_restless(id, false)
				_mend(id, d)
				_reinforce(id, d)
		else:
			if frac >= d.allure_arrive or id == SAFETY_NET_ID:
				_arrive(id, d)
	roster_changed.emit()


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
		var leaving: bool = frac < d.allure_desert and id != SAFETY_NET_ID
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
