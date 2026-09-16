class_name DigHUD
extends Control

## Status strip of the digging minigame: one pip per treasure to find, plus the scanner
## icon, which drains when the sonar fires and colors back in from the bottom as it
## recharges.
## Built with .new() and reparented into the hud_container group by the level, the same
## way DungeonManager mounts the minimap. It therefore lives outside GameWorld, so the
## visibility shader never touches it, and it draws over BottomRect because the HUD node
## comes after it in main.tscn.

## The whole screen: the icon sits on the surface band up top, the pips on the bottom strip.
const SIZE: Vector2 = Vector2(160.0, 144.0)
const POSITION: Vector2 = Vector2.ZERO

## Top-left corner of the pip row, on the bottom strip. The right half of that strip is
## where the dungeon keeps its minimap, so the two modes can share main.tscn.
const PIP_ORIGIN: Vector2 = Vector2(3.0, 134.0)
## One pip per treasure, plus the gap that follows it
const PIP_SIZE: Vector2 = Vector2(5.0, 5.0)
const PIP_GAP: float = 2.0

## On the surface band, which the entrance art paints in the darkest shade: the icon
## reads against it without a backing plate.
const ICON_POSITION: Vector2 = Vector2(1.0, 0.0)
const ICON_TEXTURE: Texture2D = preload("res://assets/sprites/demo/scanner.png")
const CHARGE_SHADER: Shader = preload("res://shaders/hud_charge.gdshader")

## Source shades, not display colors: the palette shader indexes on the red channel.
## BottomRect is left at its default white, which resolves to the lightest shade, so the
## strip has to be drawn in the two dark ones to read against it.
const COLOR_ON: Color = Palette.SRC_DARKEST
const COLOR_OFF: Color = Palette.SRC_DARK

var _collected: int = 0
var _target: int = 0
var _charge: float = 1.0
var _icon: TextureRect

func _ready() -> void:
	name = "DigHUD"
	size = SIZE
	position = POSITION
	# Keyboard and joypad only, and a full screen Control would otherwise eat the mouse
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_icon()

# The icon is its own node rather than a draw_texture() call: the charge shader is a
# material, and a material on this Control would recolor the pips along with it.
func _build_icon() -> void:
	var charge_material := ShaderMaterial.new()
	charge_material.shader = CHARGE_SHADER
	_icon = TextureRect.new()
	_icon.name = "SonarCharge"
	_icon.texture = ICON_TEXTURE
	_icon.position = ICON_POSITION
	# 1:1 with the texture, so the shader's UV.y lands exactly on rows of pixels
	_icon.size = ICON_TEXTURE.get_size()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.material = charge_material
	add_child(_icon)
	_apply_charge()

## Sets how many treasures are in hand out of how many were actually buried
func set_progress(collected: int, target: int) -> void:
	if collected == _collected and target == _target:
		return
	_collected = collected
	_target = target
	queue_redraw()

## 1 right after a ping, 0 once the sonar is usable again
func set_cooldown_ratio(ratio: float) -> void:
	# Quantized to the row of pixels the fill would actually reach: the level pushes this
	# every frame, and rewriting the uniform for a step too small to see is wasted work.
	var rows := float(ICON_TEXTURE.get_height())
	var charge := roundf((1.0 - clampf(ratio, 0.0, 1.0)) * rows) / rows
	if is_equal_approx(charge, _charge):
		return
	_charge = charge
	_apply_charge()

func _apply_charge() -> void:
	(_icon.material as ShaderMaterial).set_shader_parameter("charge", _charge)

func _draw() -> void:
	for i in _target:
		var origin := PIP_ORIGIN + Vector2(i * (PIP_SIZE.x + PIP_GAP), 0.0)
		if i < _collected:
			draw_rect(Rect2(origin, PIP_SIZE), COLOR_ON)
		else:
			draw_rect(Rect2(origin, PIP_SIZE), COLOR_OFF, false, 1.0)
