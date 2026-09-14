class_name PlayerDungeonController
extends CharacterBody2D

enum Axis { NONE, X, Y }

const CORNER_CORRECTION := 3.0

@export var movement_speed: float = 30.0
@export var torch_light_radius: float = 40.0
@export var player_light_max_diameter: float = 20.0
@export var torch_light_min_value: float = 0.25

@onready var _player_light: Sprite2D = $InnerLightSprite
@onready var _interact_area: Area2D = $InteractArea

var _torch_light_value: float = 1.0
var _last_axis: Axis = Axis.NONE
var _can_move: bool = true
var _is_input_enabled: bool = true

func _ready() -> void:
	SignalBus.input_enabled.connect(_on_input_enabled)
	SignalBus.torch_tick.connect(_on_torch_tick)

func _process(_delta: float) -> void:
	_scale_player_light()

func _physics_process(delta: float) -> void:
	if not _can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var input := _get_directional_input().normalized()
	if input == Vector2.ZERO:
		velocity = Vector2.ZERO
	else:
		velocity = input * movement_speed
	if _is_blocked(input, delta):
		_try_corner_correction(input, delta)
	move_and_slide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("dpad_left") or event.is_action_pressed("dpad_right"):
		_last_axis = Axis.X
	elif event.is_action_pressed("dpad_up") or event.is_action_pressed("dpad_down"):
		_last_axis = Axis.Y

func _unhandled_input(event: InputEvent) -> void:
	if not _is_input_enabled:
		return
	if event.is_action_pressed("btn_a"):
		var o := _get_closest_interactable_object()
		if o != null:
			o.interact(self)

func get_light_radius() -> float:
	return torch_light_radius * clamp(_torch_light_value, torch_light_min_value, 1.0)

func pick_torch() -> void:
	SignalBus.torch_refill.emit(self)

func _on_input_enabled(is_enabled: bool) -> void:
	_is_input_enabled = is_enabled
	_can_move = _is_input_enabled

func _on_torch_tick(_remaining: int, light_value: float) -> void:
	_torch_light_value = light_value

func _get_directional_input() -> Vector2:
	var input := Vector2(
		Input.get_action_strength("dpad_right") - Input.get_action_strength("dpad_left"),
		Input.get_action_strength("dpad_down") - Input.get_action_strength("dpad_up"),
	)
	if input.x != 0.0 and input.y != 0.0:
		if _last_axis == Axis.Y:
			input.x = 0.0
		else:
			input.y = 0.0
	return input

func _is_blocked(direction: Vector2, delta: float) -> bool:
	return test_move(global_transform, direction * movement_speed * delta)

func _try_corner_correction(direction: Vector2, delta: float) -> void:
	var perpendicular := Vector2(direction.y, direction.x).abs()
	var step := direction * movement_speed * delta
	for offset in [1.0, -1.0]:
		for amount in range(1, int(CORNER_CORRECTION) + 1):
			var nudge: Vector2 = perpendicular * offset * amount
			if not test_move(global_transform.translated(nudge), step):
				global_position += nudge
				return

func _scale_player_light() -> void:
	var d: int = int(round(player_light_max_diameter * _torch_light_value))
	d -= d % 2
	var s := d / float(_player_light.texture.get_width())
	_player_light.scale = Vector2(s, s)

func _get_closest_interactable_object() -> Interactable:
	var best: Interactable = null
	var best_d := INF
	for a in _interact_area.get_overlapping_areas():
		if a is not Interactable:
			continue
		if not (a as Interactable).can_interact(self):
			continue
		var d := global_position.distance_squared_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best
