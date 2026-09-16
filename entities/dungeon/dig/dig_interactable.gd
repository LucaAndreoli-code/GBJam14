extends DungeonInteractable

const MINIGAME_SCENE: Resource = preload("res://scenes/demo/scene_manager/scene_manager_1.tscn")
const TILESET_SOURCE_ID: int = 1
const TILESET_ATLAS_COORDS: Vector2i = Vector2i(3, 3)

@export var scene_root: Node2D
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
	SignalBus.visibility_shader_toggled.emit(false)
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	var minigame: Node = MINIGAME_SCENE.instantiate()
	layer.add_child(minigame)
	scene_root.add_child(layer)
	# TODO: await sul minigame
	#await minigame.finished
	layer.queue_free()
	_is_busy = false
	_update_tile()
	queue_free()

func _update_tile() -> void:
	var cell := tilemap.local_to_map(tilemap.to_local(global_position))
	tilemap.set_cell(cell, TILESET_SOURCE_ID, TILESET_ATLAS_COORDS)
