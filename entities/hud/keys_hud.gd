class_name KeysHUD
extends Control

const KEY_TEXTURE: Texture2D = preload("res://assets/sprites/ui/keys_count_icon.png")
const SIZE: Vector2 = Vector2(48.0, 16.0)
const POSITION: Vector2 = Vector2(44.0, 128.0)

var _label: Label

func _ready() -> void:
	name = "KeysHUD"
	size = SIZE
	position = POSITION
	_build_ui()
	SignalBus.keys_changed.connect(_on_keys_changed)

func _on_keys_changed(amount: int) -> void:
	_label.text = "%02d" % amount

func _build_ui():
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", -1)
	var icon := TextureRect.new()
	icon.texture = KEY_TEXTURE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.add_child(icon)
	_label = Label.new()
	_label.add_theme_font_override("font", GameState.get_title_font())
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Palette.SRC_DARKEST)
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label.text = "%02d" % GameState.get_keys()
	container.add_child(_label)
	add_child(container)
