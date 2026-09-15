class_name SonarRing
extends Node2D

## The expanding ring pair the sonar draws when it pings.
## Purely cosmetic and stateless as far as the game is concerned: DiggingMinigame reads
## get_wave_radius() to decide when the wave has reached a treasure, so the blink and the
## ring can never drift apart.

const PaletteScript := preload("res://globals/palette.gd")

## Source shade, not a display color: the palette shader indexes on the red channel.
const RING_COLOR := PaletteScript.SRC_LIGHTEST

## Segments per circle. 24 is plenty at this radius and keeps the polyline cheap.
const SEGMENTS := 24

## How far the wave travels, in px
@export var radius: float = 30.0
## How long the wave takes to reach `radius`, in seconds
@export var sweep_time: float = 0.8
## Distance between the leading ring and the one trailing it, in px
@export var trail_gap: float = 12.0

var _elapsed: float = 0.0
var _active: bool = false

func _ready() -> void:
	# Idle until something pings: the node costs nothing while the sonar is on cooldown
	set_process(false)

## Returns true while a sweep is running
func is_active() -> bool:
	return _active

## Radius the wave front has reached this frame, or -1 when no sweep is running
func get_wave_radius() -> float:
	if not _active:
		return -1.0
	return _elapsed / sweep_time * radius

## Restarts the sweep from the center
func ping() -> void:
	_elapsed = 0.0
	_active = true
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= sweep_time:
		_active = false
		set_process(false)
	queue_redraw()

func _draw() -> void:
	if not _active:
		return
	var front := get_wave_radius()
	_draw_ring(front)
	_draw_ring(front - trail_gap)

# Antialiasing off and width 1: a one pixel polyline, which the viewport's vertex snapping
# keeps on the pixel grid instead of smearing it over two rows.
func _draw_ring(r: float) -> void:
	if r <= 0.0:
		return
	draw_arc(Vector2.ZERO, r, 0.0, TAU, SEGMENTS, RING_COLOR, 1.0, false)
