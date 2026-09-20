extends DungeonInteractable

func interact(_player: PlayerDungeonController) -> void:
	_player.add_key()
	AudioManager.play_sfx(AudioManager.key_pickup_sound)
	queue_free()
