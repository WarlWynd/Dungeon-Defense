extends Node

## Player settings that persist between runs, saved to user:// (NOT the project
## folder — survives moves and OneDrive churn).

const PATH := "user://settings.cfg"

## Trap-location count is PER BOARD. Each board remembers its own number.
const TRAP_SLOTS_MIN := 3
const TRAP_SLOTS_MAX := 40
const TRAP_SLOTS_DEFAULT := 12

var _trap_slots: Dictionary = {}   ## board name -> int

signal changed()


func _ready() -> void:
	_load()


func get_trap_slots(board: String) -> int:
	return int(_trap_slots.get(board, TRAP_SLOTS_DEFAULT))


func set_trap_slots(board: String, n: int) -> void:
	var clamped: int = clampi(n, TRAP_SLOTS_MIN, TRAP_SLOTS_MAX)
	if get_trap_slots(board) == clamped:
		return
	_trap_slots[board] = clamped
	_save()
	changed.emit()


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	if not cf.has_section("trap_slots"):
		return
	for board in cf.get_section_keys("trap_slots"):
		_trap_slots[board] = clampi(
				int(cf.get_value("trap_slots", board, TRAP_SLOTS_DEFAULT)),
				TRAP_SLOTS_MIN, TRAP_SLOTS_MAX)


func _save() -> void:
	var cf := ConfigFile.new()
	for board in _trap_slots.keys():
		cf.set_value("trap_slots", board, _trap_slots[board])
	cf.save(PATH)
