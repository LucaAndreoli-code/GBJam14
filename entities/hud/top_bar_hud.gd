class_name  TopBarHUD
extends Control

const UI_BTN_ICONS_SHEET: Texture2D = preload("res://assets/sprites/ui/ui_navigation_buttons.png")
const UI_ICONS_SHEET: Texture2D = preload("res://assets/sprites/ui/ui_icons.png")
const START_TEXTURE_REGION: Rect2 = Rect2(24.0, 0.0, 23.0, 8.0)
const SELECT_TEXTURE_REGION: Rect2 = Rect2(48.0, 0.0, 24.0, 8.0)
const MENU_TEXTURE_REGION: Rect2 = Rect2(0.0, 0.0, 16.0, 16.0)
const MAP_TEXTURE_REGION: Rect2 = Rect2(16.0, 0.0, 16.0, 16.0)
const SIZE: Vector2 = Vector2(50.0, 16.0)
const POSITION: Vector2 = Vector2(110.0, 0.0)

var _container: HBoxContainer

func _init() -> void:
	_build_ui()

func _ready() -> void:
	name = "TopBarHUD"
	size = SIZE
	position = POSITION

func _build_ui() -> void:
	_container = HBoxContainer.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.add_theme_constant_override("separation", 2)
	var menu_icon := _make_icon(MENU_TEXTURE_REGION, START_TEXTURE_REGION)
	var map_icon := _make_icon(MAP_TEXTURE_REGION, SELECT_TEXTURE_REGION)
	_container.add_child(menu_icon)
	_container.add_child(map_icon)
	add_child(_container)

func _make_icon(rect: Rect2, btn_rect: Rect2) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.size = Vector2(24.0, 12.0)
	container.add_theme_constant_override("separation", -4)
	var icon := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = UI_ICONS_SHEET
	atlas.region = rect
	icon.texture = atlas
	icon.stretch_mode = TextureRect.STRETCH_KEEP
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var btn_icon := TextureRect.new()
	var btn_atlas := AtlasTexture.new()
	btn_atlas.atlas = UI_BTN_ICONS_SHEET
	btn_atlas.region = btn_rect
	btn_icon.texture = btn_atlas
	btn_icon.stretch_mode = TextureRect.STRETCH_KEEP
	btn_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	btn_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.add_child(icon)
	container.add_child(btn_icon)
	return container
