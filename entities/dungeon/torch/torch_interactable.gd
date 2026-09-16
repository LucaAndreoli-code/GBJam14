extends DungeonInteractable

@export var light_radius: float = 10.0

func get_light_radius() -> float:
	return light_radius

func interact(_player: PlayerDungeonController) -> void:
	_player.pick_torch()
	queue_free()
