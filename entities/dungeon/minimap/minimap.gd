class_name  Minimap
extends Node2D

enum DoorSize {
	RIGHT = 1,
	DOWN = 2
}

const SIZE: Vector2 = Vector2(32.0, 16.0)
const POSITION: Vector2 = Vector2(126.0, 128.0)
const FRAME: Rect2 = Rect2(0, 1.0, 31.0, 15.0)
const ROOM_ORIGIN: Vector2i = Vector2i(0, 1)
const ROOM_TILES: Vector2i = Vector2i(10, 7)
const CELL_SIZE: Vector2i = Vector2i(4, 4)
const GAP_TILES: Vector2i = Vector2i(2, 2)
const ROOM_PERIOD: Vector2i = ROOM_TILES + GAP_TILES
const COLOR_ROOM: Color = Palette.SRC_DARKEST
const COLOR_TORCH: Color = Palette.SRC_LIGHT
const COLOR_PLAYER: Color = Palette.SRC_LIGHTEST
const COLOR_BG: Color = Palette.SRC_DARK

var _level: TileMapLayer
var _player: PlayerDungeonController
var _data := MinimapUtils.Data.new()

func _init(level: TileMapLayer, player: PlayerDungeonController) -> void:
	_level = level
	_player = player

func _ready() -> void:
	var minimap_data := GameState.get_minimap()
	if minimap_data.empty:
		_build_data_layer()
	else:
		_data = minimap_data

func _build_data_layer() -> void:
	var right_count := {}
	var down_count := {}
	for cell in _level.get_used_cells():
		var c: Vector2i = cell - ROOM_ORIGIN
		var room_pos := Vector2i((Vector2(c) / Vector2(ROOM_PERIOD)).floor())
		var local: Vector2i = c - room_pos * ROOM_PERIOD
		if local.x >= ROOM_TILES.x or local.y >= ROOM_TILES.y:
			continue
		var tile_data := _level.get_cell_tile_data(cell)
		if not tile_data:
			continue
		if not tile_data.get_custom_data("walkable") and not tile_data.get_custom_data("locked_door"):
			continue
		if not _data.rooms.has(room_pos):
			_data.rooms[room_pos] = 0
		if local.x == ROOM_TILES.x - 1:
			right_count[room_pos] = right_count.get(room_pos, 0) + 1
		if local.y == ROOM_TILES.y - 1:
			down_count[room_pos] = down_count.get(room_pos, 0) + 1
	for room in _data.rooms:
		var r: int = right_count.get(room, 0)
		var d: int = down_count.get(room, 0)
		if r > ROOM_TILES.y / 2.0: _data.rooms[room] |= MinimapUtils.Link.OPEN_RIGHT
		elif r > 0: _data.rooms[room] |= MinimapUtils.Link.DOOR_RIGHT
		if d > ROOM_TILES.x / 2.0: _data.rooms[room] |= MinimapUtils.Link.OPEN_DOWN
		elif d > 0: _data.rooms[room] |= MinimapUtils.Link.DOOR_DOWN
	for torch in get_tree().get_nodes_in_group(Groups.LEVEL_TORCHES):
		var rr := MinimapUtils.get_room_of(_level, torch.global_position, ROOM_ORIGIN, GAP_TILES, ROOM_PERIOD)
		_data.torches[rr] = true
	GameState.set_minimap(_data)

func _process(_delta: float) -> void:
	var current_room := MinimapUtils.get_room_of(_level, _player.global_position, ROOM_ORIGIN, GAP_TILES, ROOM_PERIOD)
	if current_room != _data.current_room:
		_data.current_room = current_room
		_data.visited[current_room] = true
