class_name DigHUD
extends Control

## Status strip of the digging minigame: the treasure counter up in the top right corner,
## plus the scanner icon, which drains when the sonar fires and colors back in from the
## bottom as it recharges.
## Built with .new() and reparented into the hud_container group by the level, the same
## way DungeonManager mounts the minimap. It therefore lives outside GameWorld, so the
## visibility shader never touches it, and it draws over BottomRect because the HUD node
## comes after it in main.tscn.

## The whole screen: both widgets sit on the surface band up top.
const SIZE: Vector2 = Vector2(160.0, 144.0)
const POSITION: Vector2 = Vector2.ZERO

## On the surface band, which the entrance art paints in the darkest shade: the icon
## reads against it without a backing plate.
const ICON_POSITION: Vector2 = Vector2(3.0, 2.0)
## Same shared sheet the dungeon HUDs pull from, see torch_hud.gd and points_hud.gd
const UI_ICONS_SHEET: Texture2D = preload("res://assets/sprites/ui/ui_icons.png")
const ICON_REGION: Rect2 = Rect2(0.0, 32.0, 16.0, 24.0)
const CHARGE_SHADER: Shader = preload("res://shaders/hud_charge.gdshader")

## Top right corner: the counter is right aligned inside this box, so the text keeps its
## edge when the collected count grows a digit.
const COUNTER_SIZE: Vector2 = Vector2(40.0, 10.0)
const COUNTER_POSITION: Vector2 = Vector2(SIZE.x - COUNTER_SIZE.x - 5.0, 5.0)
const COUNTER_FONT_SIZE: int = 8

## Source shade, not a display color: the palette shader indexes on the red channel. The
## surface band the counter sits on is painted in the darkest shade, so the text takes the
## lightest one to read against it.
const COUNTER_COLOR: Color = Palette.SRC_LIGHTEST

var _collected: int = 0
var _target: int = 0
var _charge: float = 1.0
var _icon: TextureRect
var _counter: Label

func _ready() -> void:
	name = "DigHUD"
	size = SIZE
	position = POSITION
	# Keyboard and joypad only, and a full screen Control would otherwise eat the mouse
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_icon()
	_build_counter()

# The icon is its own node rather than a draw_texture() call: the charge shader is a
# material, and a material on this Control would recolor the counter along with it.
func _build_icon() -> void:
	var charge_material := ShaderMaterial.new()
	charge_material.shader = CHARGE_SHADER
	# The icon is a region of the sheet, so the shader's UV spans that region rather than
	# 0..1: it needs the span to place the fill level on the icon's own rows.
	var sheet_height := UI_ICONS_SHEET.get_size().y
	charge_material.set_shader_parameter("region_v_min", ICON_REGION.position.y / sheet_height)
	charge_material.set_shader_parameter("region_v_size", ICON_REGION.size.y / sheet_height)
	var atlas := AtlasTexture.new()
	atlas.atlas = UI_ICONS_SHEET
	atlas.region = ICON_REGION
	_icon = TextureRect.new()
	_icon.name = "SonarCharge"
	_icon.texture = atlas
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.position = ICON_POSITION
	# 1:1 with the region, so the shader's fill level lands exactly on rows of pixels
	_icon.size = ICON_REGION.size
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.material = charge_material
	add_child(_icon)
	_apply_charge()

# Same recipe as TorchHUD: the font comes from GameState, which main.gd fills in before
# any level mounts, so a Label built this late already has it.
func _build_counter() -> void:
	_counter = Label.new()
	_counter.name = "TreasureCounter"
	_counter.position = COUNTER_POSITION
	_counter.size = COUNTER_SIZE
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_counter.add_theme_font_override("font", GameState.get_title_font())
	_counter.add_theme_font_size_override("font_size", COUNTER_FONT_SIZE)
	_counter.add_theme_color_override("font_color", COUNTER_COLOR)
	add_child(_counter)
	_update_counter_text()

## Sets how many treasures are in hand out of how many were actually buried
func set_progress(collected: int, target: int) -> void:
	if collected == _collected and target == _target:
		return
	_collected = collected
	_target = target
	_update_counter_text()

func _update_counter_text() -> void:
	_counter.text = "%d/%d" % [_collected, _target]

## 1 right after a ping, 0 once the sonar is usable again
func set_cooldown_ratio(ratio: float) -> void:
	# Quantized to the row of pixels the fill would actually reach: the level pushes this
	# every frame, and rewriting the uniform for a step too small to see is wasted work.
	var rows := ICON_REGION.size.y
	var charge := roundf((1.0 - clampf(ratio, 0.0, 1.0)) * rows) / rows
	if is_equal_approx(charge, _charge):
		return
	_charge = charge
	_apply_charge()

func _apply_charge() -> void:
	(_icon.material as ShaderMaterial).set_shader_parameter("charge", _charge)
