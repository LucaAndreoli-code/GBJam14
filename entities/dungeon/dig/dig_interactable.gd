class_name DigInteractable
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
	if GameState.is_interactable_dug(_get_tilemap_cell()):
		_update_tile()
		queue_free()

## The pit is only worth entering with a lit torch: at zero the spot stops answering, and
## the A prompt goes off with it, see PlayerDungeonController._toggle_interact_hud().
func can_interact(_player: PlayerDungeonController) -> bool:
	return GameState.get_torch().countdown > 0

## Asked by DungeonManager to know whether the level has any digging left.
func is_dug() -> bool:
	if not tilemap:
		return false
	return GameState.is_interactable_dug(_get_tilemap_cell())

func interact(_player: PlayerDungeonController) -> void:
	if not tilemap or not scene_root:
		return
	if _is_busy:
		return
	_is_busy = true
	GameState.add_dug_interactable(_get_tilemap_cell())
	scene_root.start_digging_minigame()

func _update_tile() -> void:
	var cell := _get_tilemap_cell()
	tilemap.set_cell(cell, TILESET_SOURCE_ID, TILESET_ATLAS_COORDS)

func _get_tilemap_cell() -> Vector2i:
	return tilemap.local_to_map(tilemap.to_local(global_position))
