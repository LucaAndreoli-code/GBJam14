extends DungeonInteractable

const TILESET_SOURCE_ID: int = 1
const TILESET_ATLAS_COORDS: Vector2i = Vector2i(3, 3)

@export var scene_root: DungeonManager
@export var tilemap: TileMapLayer

var _is_busy: bool = false

func _ready() -> void:
	if not tilemap:
		push_warning("Tilemap not set on interactable %s" % name)
	if not scene_root:
		push_warning("Scene root node not set on interactable %s" % name)

func interact(_player: PlayerDungeonController) -> void:
	if not tilemap or not scene_root:
		return
	if _is_busy:
		return
	_is_busy = true
	scene_root.start_digging_minigame()

func _update_tile() -> void:
	var cell := tilemap.local_to_map(tilemap.to_local(global_position))
	tilemap.set_cell(cell, TILESET_SOURCE_ID, TILESET_ATLAS_COORDS)
