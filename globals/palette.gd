extends Node

## Emits everytime the active palette is changed
signal palette_changed(colors: Array[Color])

# Source colors, DON'T CHANGE!
# They're used to understand how to replace colors when switching palettes
const SRC_LIGHTEST := Color(1.0, 1.0, 1.0)
const SRC_LIGHT := Color(2.0 / 3.0, 2.0 / 3.0, 2.0 / 3.0)
const SRC_DARK := Color(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0)
const SRC_DARKEST := Color(0.0, 0.0, 0.0)

# Active palette colors
# They're loaded at runtime using .gpl files
var lightest := Color.from_rgba8(155, 188, 15)
var light := Color.from_rgba8(139, 172, 15)
var dark := Color.from_rgba8(48, 98, 48)
var darkest := Color.from_rgba8(15, 56, 15)

# Currently loaded .gpl files
var _loaded: Dictionary = {}

# On ready it sets the clear color and load palettes from folder
func _ready() -> void:
	RenderingServer.set_default_clear_color(SRC_DARKEST)
	_load_gpl_files_from_folder("res://assets/palettes")

## Returns the active palette colors as an indexed array.
## The order is from lightest to darkest
func get_active_palette() -> Array[Color]:
	return [lightest, light, dark, darkest]

## Returns all the loaded palettes' names
func get_all_palette_names() -> Array[String]:
	return _loaded.keys()

## Switches to a loaded palette, using it's name.
## The name must be the filename of a palette under the palettes' folder (without ".gpl")
func switch_to_palette(palette_name: String) -> bool:
	if not _loaded.has(palette_name):
		push_error("Trying to switch to an unloaded palette: %s" % palette_name)
		return false
	var palette: Array[Color] = _loaded[palette_name]
	lightest = palette[0]
	light = palette[1]
	dark = palette[2]
	darkest = palette[3]
	palette_changed.emit(get_active_palette())
	return true

func _load_gpl_files_from_folder(dir_path: String) -> void:
	_loaded.clear()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("Unable to find provided palettes' folder at path: %s" % dir_path)
		return
	for filename in dir.get_files():
		if filename.get_extension().to_lower() != "gpl":
			continue
		var colors := _parse_gpl_file(dir_path.path_join(filename))
		if colors.size() == 4:
			_loaded[filename.get_basename()] = colors

func _parse_gpl_file(file_path: String) -> Array[Color]:
	var out: Array[Color] = []
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		push_error("Unable to open palette file: %s" % file_path)
		return out
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var line_parts := line.replace("\t", " ").split(" ", false)
		# Skips heading lines
		if line_parts.size() < 3 or not line_parts[0].is_valid_int():
			continue
		var r := line_parts[0].to_int()
		var g := line_parts[1].to_int()
		var b := line_parts[2].to_int()
		out.append(Color.from_rgba8(r, g, b))
	f.close()
	if out.size() != 4:
		push_warning("Loaded %d colors instead of 4 from palette file: %s" % [out.size(), file_path])
		return out
	for i in 3:
		if out[i].get_luminance() <= out[i + 1].get_luminance():
			push_warning("Loaded unordered shades from palette file: %s" % file_path)
			break
	return out
