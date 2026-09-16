extends DungeonInteractable

@export var light_radius: float = 10.0
@export var is_sprite_visible: bool = true

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if not is_sprite_visible and _sprite:
		_sprite.visible = false

func get_light_radius() -> float:
	return light_radius

func interact(_player: PlayerDungeonController) -> void:
	_player.pick_torch()
	queue_free()
