extends Control

const CELL_SIZE: Vector2i = Vector2i(9, 9)
const CELL_SCENE: PackedScene = preload("res://scenes/ui/minimap_cell.tscn")

@onready var _view: Control = $Container/MapContainer/View
@onready var _scroll: Control = $Container/MapContainer/View/Scroll

var _parent_payload: Dictionary
var _cells: Dictionary = {}
var _current_room: Vector2i

func _ready() -> void:
	SceneManager.get_main_scene().toggle_bottom_bar(false)
	_view.resized.connect(_recenter)
	_build()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("btn_b"):
		_exit()
		return

func on_scene_entered(payload: Dictionary) -> void:
	_parent_payload = payload

func _build() -> void:
	for cell_node in _cells.values():
		cell_node.queue_free()
	_cells.clear()
	var data := GameState.get_minimap()
	_current_room = data.current_room
	for cell in data.visited:
		var node: MinimapCell = CELL_SCENE.instantiate()
		node.position = Vector2(cell * CELL_SIZE)
		_scroll.add_child(node)
		node.setup(
			data.rooms[cell],
			data.visited.has(cell + Vector2i.RIGHT),
			data.visited.has(cell + Vector2i.DOWN),
			cell == _current_room,
			data.torches.has(cell),
			CELL_SIZE,
			Vector2i(2, 2)
		)
		_cells[cell] = node
	_recenter()

func _recenter() -> void:
	var target := Vector2(_current_room * CELL_SIZE) + Vector2(CELL_SIZE) * 0.5
	_scroll.position = (_view.size * 0.5 - target).floor()

func _exit() -> void:
	SceneManager.go_to(_parent_payload.get("scene_path"), _parent_payload)
