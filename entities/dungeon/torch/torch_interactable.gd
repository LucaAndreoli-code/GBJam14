extends DungeonInteractable

@export var light_radius: float = 10.0
@export var light_central_radius_ratio: float = 1.15
@export var light_outer_radius_ratio: float = 2.0
@export var is_sprite_visible: bool = true
## Off for decorative torches that only exist to light a room. A scenery torch that can be picked
## up would now stay gone for the rest of the run, see _ready().
@export var is_pickable: bool = true
@export var tilemap: TileMapLayer

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if not tilemap:
		push_warning("Tilemap not set on torch %s" % name)
	elif GameState.is_torch_taken(get_level_key(), _get_tilemap_cell()):
		# Already picked up before a digging run: the scene brought it back, GameState takes it away.
		# queue_free() only lands at the end of the frame and screen_visibility_manager.gd reads the
		# group every frame, so leave the group now or the dead torch lights one more frame.
		remove_from_group(Groups.LIGHT_SOURCES)
		queue_free()
		return
	if not is_sprite_visible and _sprite:
		_sprite.visible = false

func can_interact(_player: PlayerDungeonController) -> bool:
	return is_pickable

func get_light_radius() -> Vector3:
	return Vector3(light_radius, light_central_radius_ratio, light_outer_radius_ratio)

func interact(_player: PlayerDungeonController) -> void:
	if tilemap:
		GameState.add_taken_torch(get_level_key(), _get_tilemap_cell())
	_player.pick_torch()
	queue_free()

func _get_tilemap_cell() -> Vector2i:
	return tilemap.local_to_map(tilemap.to_local(global_position))
