extends Control

const SIZE: Vector2 = Vector2(160.0, 132.0)
const POSITION: Vector2 = Vector2(0.0, 12.0)
const CELL_SIZE: Vector2i = Vector2i(4, 4)
const GAP_TILES: Vector2i = Vector2i(2, 2)
const COLOR_ROOM: Color = Palette.SRC_DARK
const COLOR_TORCH: Color = Palette.SRC_LIGHT
const COLOR_PLAYER: Color = Palette.SRC_LIGHTEST

@onready var _container: Control = $Container

var _map_container: Control
var _parent_payload: Dictionary
var _map_data: MinimapUtils.Data = MinimapUtils.Data.new()
var _radius := Vector2i(999, 999)

func _ready() -> void:
	Palette.switch_to_palette("gray_shades")
	SceneManager.get_main_scene().toggle_bottom_bar(false)
	_map_container = Control.new()
	_map_container.name = "MapHUD"
	_map_container.size = SIZE
	_map_container.position = POSITION
	_container.add_child(_map_container)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("btn_b"):
		_exit()
		return

func _draw() -> void:
	var minimap_data := GameState.get_minimap()
	var rooms = minimap_data.rooms
	var visited = minimap_data.visited
	var torches = minimap_data.torches
	var current_room = minimap_data.current_room
	var inner := CELL_SIZE - Vector2i.ONE
	for cell in visited:
		if not MinimapUtils.is_drawn(rooms, visited, current_room, cell, _radius, CELL_SIZE, SIZE):
			continue
		var pos := MinimapUtils.get_cell_pos(current_room, cell, CELL_SIZE, SIZE)
		draw_rect(Rect2(pos, inner), COLOR_ROOM)
		var links: int = rooms[cell]
		if MinimapUtils.is_drawn(rooms, visited, current_room, cell + Vector2i.RIGHT, _radius, CELL_SIZE, SIZE):
			if links & MinimapUtils.Link.OPEN_RIGHT:
				draw_rect(Rect2(pos + Vector2i(inner.x, 0), Vector2i(1, inner.y)), COLOR_ROOM)
			elif links & MinimapUtils.Link.DOOR_RIGHT:
				draw_rect(Rect2(pos + Vector2i(inner.x, 1), Vector2i(1, 1)), COLOR_ROOM)
		if MinimapUtils.is_drawn(rooms, visited, current_room, cell + Vector2i.DOWN, _radius, CELL_SIZE, SIZE):
			if links & MinimapUtils.Link.OPEN_DOWN:
				draw_rect(Rect2(pos + Vector2i(0, inner.y), Vector2i(inner.x, 1)), COLOR_ROOM)
			elif links & MinimapUtils.Link.DOOR_DOWN:
				draw_rect(Rect2(pos + Vector2i(1, inner.y), Vector2i(1, 1)), COLOR_ROOM)
		if cell == current_room:
			draw_rect(Rect2(pos + Vector2i(1, 1), Vector2i(1, 1)), COLOR_PLAYER)
		elif torches.has(cell):
			draw_rect(Rect2(pos + Vector2i(1, 1), Vector2i(1, 1)), COLOR_TORCH)

func on_scene_entered(payload: Dictionary) -> void:
	_parent_payload = payload

func _exit() -> void:
	SceneManager.go_to(_parent_payload.get("scene_path"), _parent_payload)
