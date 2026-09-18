class_name PointsHUD
extends Control

const UI_ICONS_SHEET: Texture2D = preload("res://assets/sprites/ui/ui_icons.png")
const CROWN_TEXTURE_REGION: Rect2 = Rect2(0.0, 40.0, 16.0, 16.0)
const SIZE: Vector2 = Vector2(64.0, 16.0)
const POSITION: Vector2 = Vector2(84.0, 128.0)

var _label: Label

func _ready() -> void:
	name = "PointsHUD"
	size = SIZE
	position = POSITION
	_build_ui()
	#SignalBus.keys_changed.connect(_on_keys_changed)

func _build_ui():
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 2)
	var icon := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = UI_ICONS_SHEET
	atlas.region = CROWN_TEXTURE_REGION
	icon.texture = atlas
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.add_child(icon)
	_label = Label.new()
	_label.add_theme_font_override("font", GameState.get_title_font())
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Palette.darkest)
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label.text = "%03d:%03d" % [0, 999]
	container.add_child(_label)
	add_child(container)
