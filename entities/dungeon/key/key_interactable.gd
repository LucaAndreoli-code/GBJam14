extends DungeonInteractable

func interact(_player: PlayerDungeonController) -> void:
	_player.add_key()
	queue_free()
