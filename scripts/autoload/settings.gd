extends Node

## Player settings that persist between runs, saved to user:// (NOT the project
## folder — survives moves and OneDrive churn).

const PATH := "user://settings.cfg"

## Trap-location count is PER BOARD. Each board remembers its own number.
const TRAP_SLOTS_MIN := 3
const TRAP_SLOTS_MAX := 40
const TRAP_SLOTS_DEFAULT := 12

const SCHEME_DEFAULT := 0

var _trap_slots: Dictionary = {}   ## board name -> int
var _color_scheme: int = SCHEME_DEFAULT

signal changed()
signal color_scheme_changed(index: int)


func _ready() -> void:
	_load()


## The palette everything draws with. Board and HUD both read this, so a change
## here repaints the whole game.
func scheme() -> ColorScheme:
	return ColorScheme.get_scheme(_color_scheme)


func get_color_scheme() -> int:
	return _color_scheme


func set_color_scheme(index: int) -> void:
	var clamped: int = clampi(index, 0, ColorScheme.count() - 1)
	if clamped == _color_scheme:
		return
	_color_scheme = clamped
	_save()
	color_scheme_changed.emit(_color_scheme)
	changed.emit()


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
	## Saved by NAME. The old builds stored a raw list position, so a settings file
	## written before this change falls back to the index — otherwise reordering
	## ColorScheme._build() would silently move every existing player's palette.
	var saved_name := str(cf.get_value("display", "color_scheme_name", ""))
	var by_name := ColorScheme.index_of(saved_name) if saved_name != "" else -1
	if by_name >= 0:
		_color_scheme = by_name
	else:
		_color_scheme = clampi(
				int(cf.get_value("display", "color_scheme", SCHEME_DEFAULT)),
				0, ColorScheme.count() - 1)
	if not cf.has_section("trap_slots"):
		return
	for board in cf.get_section_keys("trap_slots"):
		_trap_slots[board] = clampi(
				int(cf.get_value("trap_slots", board, TRAP_SLOTS_DEFAULT)),
				TRAP_SLOTS_MIN, TRAP_SLOTS_MAX)


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("display", "color_scheme_name", ColorScheme.get_scheme(_color_scheme).display_name)
	for board in _trap_slots.keys():
		cf.set_value("trap_slots", board, _trap_slots[board])
	cf.save(PATH)
