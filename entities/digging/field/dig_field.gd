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
	0: Vector2i(0, 0),	 # no open side, solid dirt
	1: Vector2i(2, 0),	 # N
	2: Vector2i(1, 0),	 # E
	3: Vector2i(1, 1),	 # N E
	4: Vector2i(4, 0),	 # S
	5: Vector2i(3, 2),	 # N S
	6: Vector2i(1, 2),	 # E S
	7: Vector2i(3, 1),	 # N E S
	8: Vector2i(3, 0),	 # W
	9: Vector2i(0, 1),	 # N W
	10: Vector2i(2, 2),	 # E W
	11: Vector2i(2, 1),	 # N E W
	12: Vector2i(0, 2),	 # S W
	13: Vector2i(5, 1),	 # N S W
	14: Vector2i(4, 1),	 # E S W
	15: Vector2i(5, 0),	 # all four, an isolated pillar
}

## The eight frame pieces, right half of the decor atlas. One cell thick, so a corner is
## a single tile carrying both of its sides.
const BORDER_TOP_LEFT := Vector2i(4, 0)
const BORDER_TOP := Vector2i(5, 0)
const BORDER_TOP_RIGHT := Vector2i(6, 0)
const BORDER_RIGHT := Vector2i(7, 0)
const BORDER_LEFT := Vector2i(4, 1)
const BORDER_BOTTOM_LEFT := Vector2i(5, 1)
const BORDER_BOTTOM := Vector2i(6, 1)
const BORDER_BOTTOM_RIGHT := Vector2i(7, 1)

## Solid dirt carrying debris, left half of the decor atlas. Every one of them is a drop in
## replacement for MASK_TO_ATLAS[0], so they only ever go on a fully enclosed cell.
const DEBRIS_ATLAS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
]

## Cells filled with dirt on ready
@export var field_rect: Rect2i = Rect2i(0, 4, 20, 14)
## Cells of unbreakable bedrock to keep on each side of the field.
## 0 means the whole field can be dug, including the outermost cells: what keeps the
## player on screen is DigPlayer's viewport clamp, not a solid frame.
@export var diggable_inset: int = 0
## Atlas source holding the dirt tiles
@export var source_id: int = 1
## Atlas source holding the frame pieces and the debris variants
@export var decor_source_id: int = 2
## Frames the field with the border tiles, one cell thick on every side. Decoration only:
## the ring is dug like any other dirt, and a cell loses its frame as soon as a tunnel
## opens next to it, see _refresh().
@export var draw_border: bool = true
## Columns of the top border painted as plain dirt, so the frame reads as having a hole
## where the player climbs in. First and last column, both included: they line up with the
## gap the surface colliders leave at x 72..88, see BoundingBoxes in digging_minigame.tscn.
@export var entry_columns: Vector2i = Vector2i(9, 10)
## Chance that a fully enclosed dirt cell takes one of the debris variants instead of the
## plain tile. Only mask 0 cells qualify: the debris tiles carry no dithered border.
@export_range(0.0, 1.0, 0.05) var debris_chance: float = 0.2

func _ready() -> void:
	# No RNG to hand over yet: the field is readied before the run knows its seed, and the
	# minigame fills it again from that seed, see DiggingMinigame._start_run().
	fill()

## Fills the whole field_rect, clearing whatever was painted in the editor: the outer ring
## takes the frame, everything else dirt, and a share of that dirt takes a debris variant.
## Every cell starts fully enclosed - outside the field counts as wall - so they all take
## mask 0 and no refresh pass is needed here.
## Pass the run's RNG to keep the scatter reproducible from the seed; without one the field
## scatters differently on every fill.
func fill(rng: RandomNumberGenerator = null) -> void:
	var scatter := rng
	if scatter == null:
		scatter = RandomNumberGenerator.new()
		scatter.randomize()
	clear()
	for y in range(field_rect.position.y, field_rect.end.y):
		for x in range(field_rect.position.x, field_rect.end.x):
			var cell := Vector2i(x, y)
			if _is_border(cell):
				set_cell(cell, decor_source_id, _border_atlas(cell))
			elif scatter.randf() < debris_chance:
				set_cell(cell, decor_source_id, DEBRIS_ATLAS[scatter.randi() % DEBRIS_ATLAS.size()])
			else:
				set_cell(cell, source_id, MASK_TO_ATLAS[0])

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

# True for the cells of the decorative frame: the outer ring of the field, minus the entry
# columns of the top row, which stay dirt so the frame reads as having a hole where the
# player digs in. The frame is decoration and nothing else - it is dug like any other cell.
func _is_border(cell: Vector2i) -> bool:
	if not draw_border:
		return false
	if not field_rect.has_point(cell):
		return false
	var on_top := cell.y == field_rect.position.y
	if on_top and cell.x >= entry_columns.x and cell.x <= entry_columns.y:
		return false
	return on_top \
		or cell.y == field_rect.end.y - 1 \
		or cell.x == field_rect.position.x \
		or cell.x == field_rect.end.x - 1

# Picks the frame piece from the sides the cell sits on. Corners first: they carry two
# sides at once, so asking for the edges before them would paint them flat.
func _border_atlas(cell: Vector2i) -> Vector2i:
	var on_left := cell.x == field_rect.position.x
	var on_right := cell.x == field_rect.end.x - 1
	if cell.y == field_rect.position.y:
		if on_left:
			return BORDER_TOP_LEFT
		return BORDER_TOP_RIGHT if on_right else BORDER_TOP
	if cell.y == field_rect.end.y - 1:
		if on_left:
			return BORDER_BOTTOM_LEFT
		return BORDER_BOTTOM_RIGHT if on_right else BORDER_BOTTOM
	return BORDER_LEFT if on_left else BORDER_RIGHT

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
# Frame and debris cells are repainted like any other: a cell only lands here once a
# tunnel has opened next to it, and neither of those tiles carries a dithered edge.
func _refresh(cell: Vector2i) -> void:
	if not is_solid(cell):
		return
	set_cell(cell, source_id, MASK_TO_ATLAS[_neighbour_mask(cell)])
