class_name  TorchHUD
extends Control

const TORCH_SHEET: Texture2D = preload("res://assets/sprites/ui/torch_timer_icon.png")
const SIZE: Vector2 = Vector2(48.0, 16.0)
const POSITION: Vector2 = Vector2(0.0, 128.0)

var _container: HBoxContainer
var _label: Label

func _init() -> void:
	_build_ui()

func _ready() -> void:
	name = "TorchHUD"
	size = SIZE
	position = POSITION
	SignalBus.torch_tick.connect(_on_torch_tick)

func _on_torch_tick(remaining: int, _light_value: float) -> void:
	_update_label_text(remaining)

func _build_ui() -> void:
	_container = HBoxContainer.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.add_theme_constant_override("separation", 0)
	var icon := TextureRect.new()
	icon.texture = TORCH_SHEET
	icon.stretch_mode = TextureRect.STRETCH_KEEP
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_make_label()
	_container.add_child(icon)
	_container.add_child(_label)
	add_child(_container)

func _make_label() -> void:
	_label = Label.new()
	_label.add_theme_font_override("font", GameState.get_title_font())
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color.BLACK)
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_update_label_text(-1)

func _update_label_text(seconds: int) -> void:
	if seconds == -1:
		_label.text = "---"
	else:
		_label.text = "%03d" % clampi(seconds, 0, 999)
