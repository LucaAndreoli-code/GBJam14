class_name  TorchHUD
extends Control

const UI_ICONS_SHEET: Texture2D = preload("res://assets/sprites/ui/ui_icons.png")
const TORCH_TEXTURE_REGION: Rect2 = Rect2(16.0, 40.0, 16.0, 16.0)
const TORCH_OFF_TEXTURE_REGION: Rect2 = Rect2(32.0, 40.0, 16.0, 16.0)
const SIZE: Vector2 = Vector2(40.0, 16.0)
const POSITION: Vector2 = Vector2(0.0, 128.0)

var _container: HBoxContainer
var _label: Label
var _icon: TextureRect

func _init() -> void:
	_build_ui()

func _ready() -> void:
	name = "TorchHUD"
	size = SIZE
	position = POSITION
	SignalBus.torch_tick.connect(_on_torch_tick)

func _on_torch_tick(remaining: int, _light_value: float) -> void:
	_update_label_text(remaining)
	var atlas := AtlasTexture.new()
	atlas.atlas = UI_ICONS_SHEET
	atlas.region = TORCH_OFF_TEXTURE_REGION if remaining <= 0 else TORCH_TEXTURE_REGION
	_icon.texture = atlas

func _build_ui() -> void:
	_container = HBoxContainer.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.add_theme_constant_override("separation", 0)
	_icon = TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = UI_ICONS_SHEET
	atlas.region = TORCH_TEXTURE_REGION
	_icon.texture = atlas
	_icon.stretch_mode = TextureRect.STRETCH_KEEP
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_make_label()
	_container.add_child(_icon)
	_container.add_child(_label)
	add_child(_container)

func _make_label() -> void:
	_label = Label.new()
	_label.add_theme_font_override("font", GameState.get_title_font())
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Palette.darkest)
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_update_label_text(-1)

func _update_label_text(seconds: int) -> void:
	if seconds == -1:
		_label.text = "---"
	else:
		_label.text = "%03d" % clampi(seconds, 0, 999)
