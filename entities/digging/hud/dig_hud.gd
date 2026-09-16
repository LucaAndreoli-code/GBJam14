class_name DigHUD
extends Control

## Status strip of the digging minigame: one pip per treasure to find, and a gauge that
## refills while the sonar cools down.
## Built with .new() and reparented into the hud_container group by the level, the same
## way DungeonManager mounts the minimap. It therefore lives outside GameWorld, so the
## visibility shader never touches it, and it draws over BottomRect because the HUD node
## comes after it in main.tscn.

## Left half of the bottom strip. The right half is where the dungeon keeps its minimap,
## so the two modes can share main.tscn without overlapping.
const SIZE: Vector2 = Vector2(96.0, 16.0)
const POSITION: Vector2 = Vector2(0.0, 128.0)

const PADDING: float = 3.0
## One pip per treasure, plus the gap that follows it
const PIP_SIZE: Vector2 = Vector2(5.0, 5.0)
const PIP_GAP: float = 2.0
const GAUGE_SIZE: Vector2 = Vector2(28.0, 5.0)

## Source shades, not display colors: the palette shader indexes on the red channel.
## BottomRect is left at its default white, which resolves to the lightest shade, so the
## strip has to be drawn in the two dark ones to read against it.
const COLOR_ON: Color = Palette.SRC_DARKEST
const COLOR_OFF: Color = Palette.SRC_DARK

var _collected: int = 0
var _target: int = 0
var _cooldown_ratio: float = 0.0

func _ready() -> void:
	name = "DigHUD"
	size = SIZE
	position = POSITION

## Sets how many treasures are in hand out of how many were actually buried
func set_progress(collected: int, target: int) -> void:
	if collected == _collected and target == _target:
		return
	_collected = collected
	_target = target
	queue_redraw()

## 1 right after a ping, 0 once the sonar is usable again
func set_cooldown_ratio(ratio: float) -> void:
	# Quantized to the pixel the gauge would actually fill: the level pushes this every
	# frame, and redrawing on a change too small to see is wasted work.
	var step := roundf(clampf(ratio, 0.0, 1.0) * GAUGE_SIZE.x) / GAUGE_SIZE.x
	if is_equal_approx(step, _cooldown_ratio):
		return
	_cooldown_ratio = step
	queue_redraw()

func _draw() -> void:
	var y := roundf((SIZE.y - PIP_SIZE.y) * 0.5)
	for i in _target:
		var origin := Vector2(PADDING + i * (PIP_SIZE.x + PIP_GAP), y)
		if i < _collected:
			draw_rect(Rect2(origin, PIP_SIZE), COLOR_ON)
		else:
			draw_rect(Rect2(origin, PIP_SIZE), COLOR_OFF, false, 1.0)
	_draw_sonar_gauge(Vector2(SIZE.x - PADDING - GAUGE_SIZE.x, y))

# Fills left to right as the sonar comes back up, so a full bar means "ready to ping".
func _draw_sonar_gauge(origin: Vector2) -> void:
	draw_rect(Rect2(origin, GAUGE_SIZE), COLOR_OFF, false, 1.0)
	var filled := roundf((1.0 - _cooldown_ratio) * (GAUGE_SIZE.x - 2.0))
	if filled <= 0.0:
		return
	draw_rect(Rect2(origin + Vector2.ONE, Vector2(filled, GAUGE_SIZE.y - 2.0)), COLOR_ON)
