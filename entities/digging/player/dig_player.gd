class_name DigPlayer
extends CharacterBody2D

## Dig Dug style digger: four directions, one axis at a time, no gravity.
## Carves the terrain a couple of pixels ahead of itself, so the ground gives way
## right before the body would collide with it.

enum Axis { X, Y }

## Lane grid the body aligns to on the axis it is not moving along.
## Keeping the center on a multiple of this is what keeps tunnels exactly 2 cells wide.
const LANE := 8.0

## The DigField this player digs through
@export var field: DigField
## Movement speed inside an already dug tunnel, in px/s
@export var speed_free: float = 40.0
## Movement speed while breaking new terrain, in px/s
@export var speed_dig: float = 22.0
## How fast the body slides back onto its lane, in px/s
@export var snap_speed: float = 60.0
## How far ahead of the body the terrain is carved, in px.
## Small on purpose: the tunnel should end at the player, not run ahead of it.
@export var dig_reach: float = 2.0
## How far ahead the player looks to decide it is digging rather than walking, in px.
## One full cell, or the slowdown would only last the single frame that breaks a cell:
## after that the carve probe sits inside terrain it already cleared.
@export var dig_look_ahead: float = 8.0
## Size of the collision body. Smaller than the 16x16 sprite so it clears a 16px tunnel.
@export var body_size: Vector2 = Vector2(14, 14)
## Half the visual footprint, kept inside the viewport on every side.
## Every terrain cell is diggable, so this clamp is the only thing holding the player
## on screen. 8 keeps the whole 16x16 sprite visible and leaves the center on the lane grid.
@export var bounds_margin: Vector2 = Vector2(8, 8)

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _debris: CPUParticles2D = $Debris

var _last_axis: Axis = Axis.X
var _is_digging: bool = false
var _is_input_enabled: bool = true

func _ready() -> void:
	if field == null:
		push_error("DigPlayer has no DigField assigned")
		set_physics_process(false)
		return
	# Read once as well as listening: the signal only fires on a change, so a player
	# spawned while input is already off would never hear about it.
	_is_input_enabled = GameState.is_input_enabled()
	SignalBus.input_enabled.connect(_on_input_enabled)

## Returns true while the player is breaking new terrain rather than walking a tunnel
func is_digging() -> bool:
	return _is_digging

## The rect the collision body covers right now, in global space
func get_body_rect() -> Rect2:
	return Rect2(global_position - body_size * 0.5, body_size)

func _physics_process(delta: float) -> void:
	var dir := _read_direction() if _is_input_enabled else Vector2i.ZERO
	_is_digging = false
	if dir != Vector2i.ZERO:
		_is_digging = field.has_solid_in(_probe_rect(dir, dig_look_ahead))
		if not field.carve(_probe_rect(dir, dig_reach)).is_empty():
			_burst_debris(dir)
		_apply_lane_snap(dir, delta)
	velocity = Vector2(dir) * (speed_dig if _is_digging else speed_free)
	_update_animation(dir)
	move_and_slide()
	_clamp_to_viewport()

func _on_input_enabled(is_enabled: bool) -> void:
	_is_input_enabled = is_enabled

# Reads the dpad and collapses it to a single axis.
# When both axes are held the one pressed most recently wins, so turning a corner
# while still holding the old direction feels immediate.
func _read_direction() -> Vector2i:
	var x := int(Input.is_action_pressed("dpad_right")) - int(Input.is_action_pressed("dpad_left"))
	var y := int(Input.is_action_pressed("dpad_down")) - int(Input.is_action_pressed("dpad_up"))
	if x != 0 and y != 0:
		if Input.is_action_just_pressed("dpad_up") or Input.is_action_just_pressed("dpad_down"):
			_last_axis = Axis.Y
		elif Input.is_action_just_pressed("dpad_left") or Input.is_action_just_pressed("dpad_right"):
			_last_axis = Axis.X
		if _last_axis == Axis.X:
			y = 0
		else:
			x = 0
	elif x != 0:
		_last_axis = Axis.X
	elif y != 0:
		_last_axis = Axis.Y
	return Vector2i(x, y)

# The body rect grown by `reach` px on the side it is moving towards, in field local space.
# The axis perpendicular to the movement is quantized to the lane grid instead of using
# the live position: the body may still be sliding onto its lane, and probing from the
# unsnapped position would eat a third row of cells and widen the tunnel.
func _probe_rect(dir: Vector2i, reach: float) -> Rect2:
	var center := field.to_local(global_position)
	if dir.x != 0:
		center.y = snappedf(center.y, LANE)
	else:
		center.x = snappedf(center.x, LANE)
	var rect := Rect2(center - body_size * 0.5, body_size)
	if dir.x > 0:
		rect.size.x += reach
	elif dir.x < 0:
		rect.position.x -= reach
		rect.size.x += reach
	elif dir.y > 0:
		rect.size.y += reach
	elif dir.y < 0:
		rect.position.y -= reach
		rect.size.y += reach
	return rect

# Slides the body back onto the lane grid along the axis it is not moving on
func _apply_lane_snap(dir: Vector2i, delta: float) -> void:
	var step := snap_speed * delta
	var local := field.to_local(global_position)
	if dir.x != 0:
		local.y = move_toward(local.y, snappedf(local.y, LANE), step)
	else:
		local.x = move_toward(local.x, snappedf(local.x, LANE), step)
	global_position = field.to_global(local)

# Throws a puff of dirt out of the hole that was just broken. Driven by carve()
# actually removing a cell rather than by a timer, so it fires once per broken cell
# and stays silent while the player walks an already dug tunnel.
func _burst_debris(dir: Vector2i) -> void:
	_debris.position = Vector2(dir) * body_size * 0.5
	_debris.direction = -Vector2(dir)
	_debris.restart()

# Front frames for every direction but up, which shows the back of the digger.
# flip_h is only touched on a horizontal move so the sprite keeps facing the way it
# last walked while standing still.
func _update_animation(dir: Vector2i) -> void:
	if dir.y < 0:
		_sprite.play("up")
	elif dir == Vector2i.ZERO:
		_sprite.play("idle")
	elif dir.x < 0:
		_sprite.play("dig_left")
	elif dir.x > 0:
		_sprite.play("dig_right")
	#if dir.x != 0:
		#_sprite.flip_h = dir.x < 0

# Holds the player inside the screen. Both margins are multiples of the lane grid, so
# a clamped player stays aligned and keeps digging 2 cell wide tunnels along the edge.
func _clamp_to_viewport() -> void:
	var limits := get_viewport_rect().grow_individual(
		-bounds_margin.x, -bounds_margin.y, -bounds_margin.x, -bounds_margin.y)
	global_position.x = clampf(global_position.x, limits.position.x, limits.end.x)
	global_position.y = clampf(global_position.y, limits.position.y, limits.end.y)
