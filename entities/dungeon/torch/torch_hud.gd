class_name  TorchHUD
extends Control

const SIZE: Vector2 = Vector2(32.0, 16.0)
const POSITION: Vector2 = Vector2(0.0, 128.0)
const GAMEBOY_FONT := preload("res://assets/fonts/gameboysoft.ttf")

var _container: CenterContainer
var _label: Label

func _init(seconds: int) -> void:
	_build_ui()
	_update_label_text(seconds)

func _ready() -> void:
	name = "TorchHUD"
	size = SIZE
	position = POSITION
	SignalBus.torch_tick.connect(_on_torch_tick)

func _on_torch_tick(remaining: int, _light_value: float) -> void:
	_update_label_text(remaining)

func _build_ui() -> void:
	_container = CenterContainer.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_make_label()
	_container.add_child(_label)
	add_child(_container)

func _make_label() -> void:
	_label = Label.new()
	_label.add_theme_font_override("font", GAMEBOY_FONT)
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color.BLACK)

func _update_label_text(seconds: int) -> void:
	_label.text = "%d" % seconds
