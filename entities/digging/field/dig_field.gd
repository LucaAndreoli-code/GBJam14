class_name DigField
extends TileMapLayer

## The diggable terrain of the digging minigame.
## Owns every pixel -> cell conversion, so nothing else needs to know the tile size.

## Emits after a carve actually removed something, with the cells that were removed
signal cells_carved(cells: Array[Vector2i])

## Neighbours probed to build the tile mask, in bit order: N, E, S, W
const NEIGHBOURS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)
]

## Dirt variant to use for every neighbour mask.
## Bits: N = 1, E = 2, S = 4, W = 8; a set bit means that neighbour has been dug out.
## Every tile in the set already carries its dithered border on the open sides, so the
## mask indexes the atlas directly and no terrain set is needed.
const MASK_TO_ATLAS := {
	0: Vector2i(0, 0),   # no open side, solid dirt
	1: Vector2i(2, 0),   # N
	2: Vector2i(1, 0),   # E
	3: Vector2i(1, 1),   # N E
	4: Vector2i(4, 0),   # S
	5: Vector2i(3, 2),   # N S
	6: Vector2i(1, 2),   # E S
	7: Vector2i(3, 1),   # N E S
	8: Vector2i(3, 0),   # W
	9: Vector2i(0, 1),   # N W
	10: Vector2i(2, 2),  # E W
	11: Vector2i(2, 1),  # N E W
	12: Vector2i(0, 2),  # S W
	13: Vector2i(5, 1),  # N S W
	14: Vector2i(4, 1),  # E S W
	15: Vector2i(5, 0),  # all four, an isolated pillar
}

## Cells filled with dirt on ready
@export var field_rect: Rect2i = Rect2i(0, 4, 20, 14)
## Cells of unbreakable bedrock to keep on each side of the field.
## 0 means the whole field can be dug, including the outermost cells: what keeps the
## player on screen is DigPlayer's viewport clamp, not a solid frame.
@export var diggable_inset: int = 0
## Atlas source holding the dirt tiles
@export var source_id: int = 0

func _ready() -> void:
	fill()

## Fills the whole field_rect with dirt, clearing whatever was painted in the editor.
## Every cell starts fully enclosed - outside the field counts as wall - so they all
## take mask 0 and no refresh pass is needed here.
func fill() -> void:
	clear()
	for y in range(field_rect.position.y, field_rect.end.y):
		for x in range(field_rect.position.x, field_rect.end.x):
			set_cell(Vector2i(x, y), source_id, MASK_TO_ATLAS[0])

## Returns the sub-rect of the field that carving is allowed to touch.
## Anything outside it stays solid forever.
func get_diggable_rect() -> Rect2i:
	return field_rect.grow(-diggable_inset)

## Returns true when the cell still holds a tile
func is_solid(cell: Vector2i) -> bool:
	return get_cell_source_id(cell) != -1

## Converts a rect in this node's local space into the cells it overlaps
func rect_to_cells(local_rect: Rect2) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	# end - one pixel, or a rect ending exactly on a cell boundary grabs an extra row/column
	var top_left := local_to_map(local_rect.position)
	var bottom_right := local_to_map(local_rect.end - Vector2.ONE * 0.001)
	for y in range(top_left.y, bottom_right.y + 1):
		for x in range(top_left.x, bottom_right.x + 1):
			cells.append(Vector2i(x, y))
	return cells

## Returns true when any cell under the rect is still solid, without carving it
func has_solid_in(local_rect: Rect2) -> bool:
	var diggable := get_diggable_rect()
	for cell in rect_to_cells(local_rect):
		if is_solid(cell) and diggable.has_point(cell):
			return true
	return false

## Removes every diggable solid cell under the rect, then repaints the surviving
## neighbours so the tunnel gets its dithered border.
## Returns the removed cells and emits cells_carved when there is at least one.
func carve(local_rect: Rect2) -> Array[Vector2i]:
	var removed: Array[Vector2i] = []
	var diggable := get_diggable_rect()
	for cell in rect_to_cells(local_rect):
		if not diggable.has_point(cell):
			continue
		if not is_solid(cell):
			continue
		erase_cell(cell)
		removed.append(cell)
	if removed.is_empty():
		return removed
	# Collected and repainted in two passes, after every erase: the player's probe takes
	# two or three cells at once, and refreshing inside the erase loop would read a
	# half-carved field and bake the wrong border into the cells dug this same frame.
	var dirty := {}
	for cell in removed:
		for offset in NEIGHBOURS:
			dirty[cell + offset] = true
	for cell in dirty:
		_refresh(cell)
	cells_carved.emit(removed)
	return removed

## Converts a cell to the position of its top-left corner, in this node's local space
func cell_to_local_origin(cell: Vector2i) -> Vector2:
	return Vector2(cell * tile_set.tile_size)

## Converts a cell to the position of its top-left corner, in global space
func cell_to_global_origin(cell: Vector2i) -> Vector2:
	return to_global(cell_to_local_origin(cell))

## Converts a global position to the cell holding it
func global_to_cell(global_pos: Vector2) -> Vector2i:
	return local_to_map(to_local(global_pos))

## Size of one cell, in px. Nothing outside has to reach into the tile set for it.
func get_cell_size() -> Vector2i:
	return tile_set.tile_size

# Outside the field counts as wall, so the dirt reads as continuing past the screen
# instead of framing the playable area with a border.
func _is_wall(cell: Vector2i) -> bool:
	return not field_rect.has_point(cell) or is_solid(cell)

func _neighbour_mask(cell: Vector2i) -> int:
	var mask := 0
	for i in NEIGHBOURS.size():
		if not _is_wall(cell + NEIGHBOURS[i]):
			mask |= 1 << i
	return mask

# Repaints a cell with the variant matching its neighbours.
# Already carved cells must not come back, hence the guard.
func _refresh(cell: Vector2i) -> void:
	if not is_solid(cell):
		return
	set_cell(cell, source_id, MASK_TO_ATLAS[_neighbour_mask(cell)])
