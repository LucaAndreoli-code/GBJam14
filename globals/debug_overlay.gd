extends Node

# FPS + on-screen color counter. Debug builds only, F3 toggles it, starts hidden.
#
# Every SCAN_INTERVAL it grabs the root viewport image, after shaders/palette.gdshader
# ran, and counts unique colors. That image is exactly what the player sees, so nodes
# placed outside PaletteContainer, which skip the shader, get caught too.
# It hides itself for the capture: otherwise its own antialiased text adds tints and
# the overlay counts itself over the limit. That is the blink.
# Above MAX_COLORS the label turns red, plus one push_warning per regression.

const GAMEBOY_FONT := preload("res://assets/fonts/gameboysoft.ttf")

const MAX_COLORS := 4
const SCAN_INTERVAL := 0.5
const TOGGLE_ACTION := "debug_overlay_toggle"

var _layer: CanvasLayer = null
var _fps_label: Label = null
var _color_label: Label = null
var _enabled := false
var _scanning := false
var _elapsed := 0.0
var _color_count := -1

func _ready() -> void:
	if not OS.is_debug_build():
		return
	# Keeps reporting while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not InputMap.has_action(TOGGLE_ACTION):
		push_warning("DebugOverlay: missing input action '%s', toggle disabled" % TOGGLE_ACTION)
	_build_ui()

func _input(event: InputEvent) -> void:
	if _layer != null and event.is_action_pressed(TOGGLE_ACTION):
		set_overlay_visible(not _enabled)

func _process(delta: float) -> void:
	if not _enabled:
		return
	_fps_label.text = "FPS %d" % Engine.get_frames_per_second()
	_elapsed += delta
	if _elapsed < SCAN_INTERVAL or _scanning:
		return
	_elapsed = 0.0
	_scan_colors()

func is_overlay_visible() -> bool:
	return _enabled

func set_overlay_visible(value: bool) -> void:
	if _layer == null or _enabled == value:
		return
	_enabled = value
	_layer.visible = _enabled
	# Refreshes on the next frame instead of showing a stale count.
	_elapsed = SCAN_INTERVAL

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 128
	_layer.visible = false
	add_child(_layer)
	var box := VBoxContainer.new()
	box.position = Vector2(2, 1)
	box.add_theme_constant_override("separation", 0)
	_layer.add_child(box)
	_fps_label = _make_label()
	_color_label = _make_label()
	box.add_child(_fps_label)
	box.add_child(_color_label)
	_color_label.text = "COL --"

func _make_label() -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", GAMEBOY_FONT)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	return label

# Captures the whole visible frame and counts its unique colors.
# The overlay is hidden while capturing, otherwise its own text pixels (and the
# antialiased font edges) would be counted as on-screen colors. That costs a
# two-frame blink of the labels every SCAN_INTERVAL.
func _scan_colors() -> void:
	_scanning = true
	_layer.visible = false
	# Two waits, not one: frame_post_draw can fire for a frame that was already
	# submitted with the layer still in it, which makes the overlay count itself.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	_layer.visible = _enabled
	_scanning = false
	if image == null:
		_set_color_count(-1)
		return
	var seen: Dictionary = {}
	for y in image.get_height():
		for x in image.get_width():
			seen[image.get_pixel(x, y).to_rgba32()] = true
	_set_color_count(seen.size())

func _set_color_count(value: int) -> void:
	if _color_count == value:
		return
	var was_over := _color_count > MAX_COLORS
	_color_count = value
	if _color_count < 0:
		_color_label.text = "COL --"
		_color_label.modulate = Color.WHITE
		return
	_color_label.text = "COL %d/%d" % [_color_count, MAX_COLORS]
	var is_over := _color_count > MAX_COLORS
	_color_label.modulate = Color.RED if is_over else Color.WHITE
	if is_over and not was_over:
		push_warning("DebugOverlay: %d colors on screen, max is %d" % [_color_count, MAX_COLORS])
