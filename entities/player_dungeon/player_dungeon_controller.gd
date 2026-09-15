class_name PlayerDungeonController
extends CharacterBody2D

const SPEED = 32.0

@export var torch_light_radius: float = 40.0
@export var player_light_max_diameter: float = 20.0
@export var torch_light_min_value: float = 0.25

@onready var _player_light: Sprite2D = $InnerLightSprite
@onready var _interact_area: Area2D = $InteractArea

var _torch_light_value: float = 1.0

func _ready() -> void:
	SignalBus.torch_tick.connect(_on_torch_tick)

func _process(_delta: float) -> void:
	_scale_player_light()

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("dpad_left", "dpad_right", "dpad_up", "dpad_down")
	if direction != Vector2.ZERO:
		velocity = direction * SPEED
	else:
		velocity = Vector2.ZERO
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("btn_a"):
		var o := _get_closest_interactable_object()
		if o != null:
			o.interact(self)

func get_light_radius() -> float:
	return torch_light_radius * clamp(_torch_light_value, torch_light_min_value, 1.0)

func pick_torch() -> void:
	SignalBus.torch_refill.emit(self)

func _on_torch_tick(_remaining: int, light_value: float) -> void:
	_torch_light_value = light_value

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
