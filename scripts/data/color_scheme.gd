extends RefCounted
class_name ColorScheme

## A named palette the player picks in Settings > Appearance. Each scheme is
## authored as five base colors; everything else (button states, text, tunnel
## edges, vault trim) is derived from those so a new scheme stays coherent
## without hand-tuning fifteen values.
##
## To add a scheme: append one _derive() line to _build(). Nothing else needs
## to change — the Appearance tab reads whatever is in the list.

## --- UI ---
var display_name: String
var accent: Color          ## titles, gold text, highlights, selected tabs
var text: Color            ## body text and drawn button glyphs
var dim: Color             ## secondary/disabled text
var panel: Color           ## modal + panel background
var button: Color
var button_hover: Color
var button_pressed: Color

## --- Dungeon ---
var stone: Color           ## wall texture tint
var stone_dark: Color      ## flat fill when the stone texture is missing
var floor_col: Color       ## corridor / path floor
var floor_edge: Color      ## dark outline around the corridor
var floor_worn: Color      ## lighter tread down the middle
var vault_trim: Color
var entrance: Color

static var _all: Array = []


static func all() -> Array:
	if _all.is_empty():
		_all = _build()
	return _all


static func count() -> int:
	return all().size()


static func get_scheme(index: int) -> ColorScheme:
	var list := all()
	return list[clampi(index, 0, list.size() - 1)]


static func _build() -> Array:
	return [
		#        name             accent                      stone                       floor                       panel
		_derive("Obsidian",      Color(0.85, 0.87, 0.92), Color(0.34, 0.34, 0.36), Color(0.24, 0.24, 0.26), Color(0.10, 0.10, 0.11)),
		_derive("Dungeon Ember", Color(1.00, 0.85, 0.25), Color(0.42, 0.42, 0.46), Color(0.33, 0.29, 0.24), Color(0.13, 0.12, 0.13)),
		_derive("Crypt Moss",    Color(0.62, 0.86, 0.42), Color(0.36, 0.42, 0.36), Color(0.26, 0.31, 0.24), Color(0.10, 0.14, 0.11)),
		_derive("Frostbite",     Color(0.55, 0.85, 1.00), Color(0.40, 0.46, 0.55), Color(0.28, 0.34, 0.42), Color(0.09, 0.12, 0.17)),
		_derive("Blood Moon",    Color(1.00, 0.35, 0.32), Color(0.44, 0.34, 0.34), Color(0.32, 0.22, 0.22), Color(0.15, 0.08, 0.09)),
		_derive("Void Bloom",    Color(0.78, 0.52, 1.00), Color(0.40, 0.36, 0.50), Color(0.28, 0.24, 0.36), Color(0.12, 0.09, 0.17)),
		_derive("Sandstone",     Color(0.72, 0.42, 0.12), Color(0.80, 0.72, 0.56), Color(0.70, 0.60, 0.44), Color(0.88, 0.83, 0.72)),
		_derive("Toxic Vein",    Color(0.70, 1.00, 0.20), Color(0.30, 0.34, 0.28), Color(0.22, 0.26, 0.20), Color(0.07, 0.10, 0.07)),
	]


## Settings persists the player's pick by NAME, not by position, so reordering
## this list can never silently hand someone a different palette.
static func index_of(nm: String) -> int:
	var list := all()
	for i in list.size():
		if list[i].display_name == nm:
			return i
	return -1


## Text flips to near-black on a light panel (Sandstone), so a pale scheme stays
## readable without a second set of hand-picked values.
static func _derive(nm: String, accent_c: Color, stone_c: Color, floor_c: Color, panel_c: Color) -> ColorScheme:
	var s := ColorScheme.new()
	s.display_name = nm
	s.accent = accent_c
	s.panel = panel_c
	s.stone = stone_c
	s.floor_col = floor_c

	var light_ui: bool = panel_c.get_luminance() > 0.45
	s.text = Color(0.09, 0.08, 0.07) if light_ui else Color(0.93, 0.92, 0.90)
	s.dim = s.text.lerp(panel_c, 0.45)
	s.button = panel_c.lerp(Color.BLACK if light_ui else Color.WHITE, 0.12)
	s.button_hover = s.button.lerp(accent_c, 0.35)
	s.button_pressed = accent_c.darkened(0.25)

	s.stone_dark = stone_c.darkened(0.60)
	s.floor_edge = floor_c.darkened(0.78)
	s.floor_edge.a = 0.9
	s.floor_worn = floor_c.lightened(0.14)
	s.floor_worn.a = 0.55
	s.vault_trim = accent_c.darkened(0.40)
	s.entrance = Color(0.55, 0.20, 0.20).lerp(accent_c, 0.25)
	return s
