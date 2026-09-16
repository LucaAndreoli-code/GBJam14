class_name  MinimapHUD
extends Control

enum DoorSize {
	RIGHT = 1,
	DOWN = 2
}

enum Link { 
	DOOR_RIGHT = 1 << 0, 
	DOOR_DOWN = 1 << 1, 
	OPEN_RIGHT = 1 << 2, 
	OPEN_DOWN = 1 << 3 
}

const SIZE: Vector2 = Vector2(32.0, 16.0)
const POSITION: Vector2 = Vector2(128.0, 128.0)
const ROOM_ORIGIN: Vector2i = Vector2i(0, 1)
const ROOM_TILES: Vector2i = Vector2i(10, 7)
const CELL_SIZE: Vector2i = Vector2i(4, 4)
const GAP_TILES: Vector2i = Vector2i(2, 2)
const ROOM_PERIOD: Vector2i = ROOM_TILES + GAP_TILES
const COLOR_ROOM: Color = Palette.SRC_DARKEST
const COLOR_TORCH: Color = Palette.SRC_LIGHT
const COLOR_PLAYER: Color = Palette.SRC_LIGHTEST

var _level: TileMapLayer
var _player: PlayerDungeonController
var _data := {}
var _visited := {}
var _torches := {}
var _current_room := Vector2i(-999, -999)
var _offset := Vector2i.ZERO
var _radius := Vector2i(1, 1) # How many rooms to show adjacent the current
var _is_disabled: bool = false

func _init(level: TileMapLayer, player: PlayerDungeonController) -> void:
	_level = level
	_player = player

func _ready() -> void:
	name = "MinimapHUD"
	size = SIZE
	position = POSITION
	_build_data_layer()

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
		if not (tile_data and tile_data.get_custom_data("walkable")):
			continue
		if not _data.has(room_pos):
			_data[room_pos] = 0
		if local.x == ROOM_TILES.x - 1:
			right_count[room_pos] = right_count.get(room_pos, 0) + 1
		if local.y == ROOM_TILES.y - 1:
			down_count[room_pos] = down_count.get(room_pos, 0) + 1
	for room in _data:
		var r: int = right_count.get(room, 0)
		var d: int = down_count.get(room, 0)
		if r > ROOM_TILES.y / 2.0: _data[room] |= Link.OPEN_RIGHT
		elif r > 0: _data[room] |= Link.DOOR_RIGHT
		if d > ROOM_TILES.x / 2.0: _data[room] |= Link.OPEN_DOWN
		elif d > 0: _data[room] |= Link.DOOR_DOWN
	for torch in get_tree().get_nodes_in_group(Groups.LEVEL_TORCHES):
		_torches[_room_of(torch.global_position)] = true
	_compute_offset()

func _process(_delta: float) -> void:
	if _is_disabled:
		return
	var current_room := _room_of(_player.global_position)
	if current_room != _current_room:
		_current_room = current_room
		_visited[current_room] = true
		queue_redraw()

func _draw() -> void:
	var inner := CELL_SIZE - Vector2i.ONE
	for cell in _visited:
		if not _is_drawn(cell):
			continue
		var pos := _cell_pos(cell)
		draw_rect(Rect2(pos, inner), COLOR_ROOM)
		var links: int = _data[cell]
		if _is_drawn(cell + Vector2i.RIGHT):
			if links & Link.OPEN_RIGHT:
				draw_rect(Rect2(pos + Vector2i(inner.x, 0), Vector2i(1, inner.y)), COLOR_ROOM)
			elif links & Link.DOOR_RIGHT:
				draw_rect(Rect2(pos + Vector2i(inner.x, 1), Vector2i(1, 1)), COLOR_ROOM)
		if _is_drawn(cell + Vector2i.DOWN):
			if links & Link.OPEN_DOWN:
				draw_rect(Rect2(pos + Vector2i(0, inner.y), Vector2i(inner.x, 1)), COLOR_ROOM)
			elif links & Link.DOOR_DOWN:
				draw_rect(Rect2(pos + Vector2i(1, inner.y), Vector2i(1, 1)), COLOR_ROOM)
		if cell == _current_room:
			draw_rect(Rect2(pos + Vector2i(1, 1), Vector2i(1, 1)), COLOR_PLAYER)
		elif _torches.has(cell):
			draw_rect(Rect2(pos + Vector2i(1, 1), Vector2i(1, 1)), COLOR_TORCH)

func _compute_offset() -> void:
	var keys := _data.keys()
	var min_room: Vector2i = keys[0]
	var max_room: Vector2i = keys[0]
	for r in keys:
		min_room = min_room.min(r)
		max_room = max_room.max(r)
	var map_size := (max_room - min_room + Vector2i.ONE) * CELL_SIZE - Vector2i.ONE
	_offset = (Vector2i(SIZE) - map_size) / 2 - min_room * CELL_SIZE

func _cell_pos(cell: Vector2i) -> Vector2i:
	var inner := CELL_SIZE - Vector2i.ONE
	return (Vector2i(SIZE) - inner) / 2 + (cell - _current_room) * CELL_SIZE

func _is_drawn(cell: Vector2i) -> bool:
	if not (_visited.has(cell) and _data.has(cell)):
		return false
	var d := (cell - _current_room).abs()
	if d.x > _radius.x or d.y > _radius.y:
		return false
	return Rect2(Vector2.ZERO, SIZE).encloses(Rect2(_cell_pos(cell), CELL_SIZE - Vector2i.ONE))

func _room_of(global_pos: Vector2) -> Vector2i:
	var tile_size := _level.tile_set.tile_size
	var p := _level.to_local(global_pos) - Vector2(ROOM_ORIGIN * tile_size)
	p += Vector2(GAP_TILES * tile_size) / 2.0
	return Vector2i((p / Vector2(ROOM_PERIOD * tile_size)).floor())
