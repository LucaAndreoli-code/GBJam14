extends DungeonInteractable

@export var tilemap: TileMapLayer

func _ready() -> void:
	if not tilemap:
		push_warning("Tilemap not set on key %s" % name)
		return
	# Already picked up before a digging run: the scene brought it back, GameState takes it away.
	if GameState.is_key_taken(get_level_key(), _get_tilemap_cell()):
		queue_free()

func interact(_player: PlayerDungeonController) -> void:
	if tilemap:
		GameState.add_taken_key(get_level_key(), _get_tilemap_cell())
	_player.add_key()
	AudioManager.play_sfx(AudioManager.key_pickup_sound)
	queue_free()

func _get_tilemap_cell() -> Vector2i:
	return tilemap.local_to_map(tilemap.to_local(global_position))
