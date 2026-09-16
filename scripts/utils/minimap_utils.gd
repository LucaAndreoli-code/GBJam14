class_name MinimapUtils

enum Link { 
	DOOR_RIGHT = 1 << 0, 
	DOOR_DOWN = 1 << 1, 
	OPEN_RIGHT = 1 << 2, 
	OPEN_DOWN = 1 << 3 
}

static func get_cell_pos(
	current_room: Vector2i, \
	cell: Vector2i, \
	cell_size: Vector2i, \
	map_size: Vector2) -> Vector2i:
	var inner := cell_size - Vector2i.ONE
	return (Vector2i(map_size) - inner) / 2 + (cell - current_room) * cell_size

static func is_drawn(
	data: Dictionary, \
	visited: Dictionary, \
	current_room: Vector2i, \
	cell: Vector2i, \
	radius: Vector2i, \
	cell_size: Vector2i, \
	map_size: Vector2) -> bool:
	if not (visited.has(cell) and data.has(cell)):
		return false
	var d := (cell - current_room).abs()
	if d.x > radius.x or d.y > radius.y:
		return false
	var cell_pos := get_cell_pos(current_room, cell, cell_size, map_size)
	return Rect2(Vector2.ZERO, map_size).encloses(Rect2(cell_pos, cell_size - Vector2i.ONE))

static func get_room_of(
	tilemap: TileMapLayer, \
	global_pos: Vector2, \
	room_origin: Vector2i, \
	gap_tiles: Vector2i, \
	room_period: Vector2i) -> Vector2i:
	var tile_size := tilemap.tile_set.tile_size
	var p := tilemap.to_local(global_pos) - Vector2(room_origin * tile_size)
	p += Vector2(gap_tiles * tile_size) / 2.0
	return Vector2i((p / Vector2(room_period * tile_size)).floor())
