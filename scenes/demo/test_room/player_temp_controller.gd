extends CharacterBody2D

const SPEED = 32.0

@export var torch_duration_seconds: int = 240
@export var torch_light_radius: float = 40.0
@export var player_light_max_diameter: float = 20.0

@onready var _player_light: Sprite2D = $LightSprite

var _torch: TorchManager

func _ready() -> void:
	_torch = TorchManager.new(torch_duration_seconds)

func _process(delta: float) -> void:
	_torch.tick(delta)
	_scale_player_light()

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("dpad_left", "dpad_right", "dpad_up", "dpad_down")
	if direction:
		velocity = direction * SPEED
	else:
		velocity = Vector2.ZERO
	move_and_slide()

func get_light_radius() -> float:
	return torch_light_radius * _torch.get_light_value()

func _scale_player_light() -> void:
	var d: int = int(round(player_light_max_diameter * _torch.get_light_value()))
	d -= d % 2
	var s := d / float(_player_light.texture.get_width())
	_player_light.scale = Vector2(s, s)
