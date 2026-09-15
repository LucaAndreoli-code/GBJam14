class_name DiggingMinigame
extends Node2D

## Root of the digging minigame: spawns the buried treasures, reveals them as the
## terrain is carved, and counts what the player brings home.

## Emits on every pickup, with the running total and the target
signal treasure_collected(total: int, target: int)
## Emits when the last treasure is picked up
signal all_treasures_collected()

const TREASURE_SCENE := preload("res://scenes/minigames/digging/treasure.tscn")

# Attempts per region before giving up on placing that treasure
const PLACEMENT_ATTEMPTS := 24

## How many treasures to bury
@export var treasure_count: int = 4
## Relative odds of each Treasure.Kind
@export var kind_weights: Dictionary = {
	Treasure.Kind.SMALL: 3,
	Treasure.Kind.MEDIUM: 2,
	Treasure.Kind.BIG: 1,
}
## Empty cells kept between two treasures, so a single tunnel rarely uncovers both
@export var min_gap: int = 1
## Cells around the player's starting position that stay treasure free
@export var start_pocket_radius: int = 2

@onready var _field: DigField = $DigField
@onready var _player: DigPlayer = $DigPlayer
@onready var _treasures_root: Node2D = $Treasures

var _rng := RandomNumberGenerator.new()
var _buried: Array[Treasure] = []
var _reserved: Array[Rect2i] = []
var _collected: int = 0

func _ready() -> void:
	# DigField.fill() already ran: children are readied before their parent
	_rng.seed = GameState.get_seed()
	_field.cells_carved.connect(_on_cells_carved)
	_open_start_pocket()
	_reserve_start_pocket()
	_spawn_treasures()

## Called by SceneManager when this scene is entered, see scene_manager.gd
func on_scene_entered(payload: Dictionary) -> void:
	var incoming_seed: int = payload.get("seed", 0)
	if incoming_seed != 0:
		GameState.set_seed(incoming_seed)

## Returns how many treasures the player has picked up so far
func get_collected_count() -> int:
	return _collected

# The player spawns inside the dirt, so clear the cells under its body first or
# move_and_slide() would spend the first frames shoving it out of solid tiles.
func _open_start_pocket() -> void:
	var center := _field.to_local(_player.global_position)
	_field.carve(Rect2(center - _player.body_size * 0.5, _player.body_size))

func _reserve_start_pocket() -> void:
	var start_cell := _field.local_to_map(_field.to_local(_player.global_position))
	_reserved.append(Rect2i(start_cell, Vector2i.ONE).grow(start_pocket_radius))

# Splits the diggable area into a grid of regions, one per treasure, and drops a treasure
# somewhere inside each. The board asks for "randomly, but distributed": a flat uniform
# draw clumps them, and clumped treasures make the run swing on a single lucky tunnel.
func _spawn_treasures() -> void:
	var diggable := _field.get_diggable_rect()
	var columns := int(ceil(sqrt(float(treasure_count))))
	var rows := int(ceil(float(treasure_count) / float(columns)))
	for i in treasure_count:
		var region := _region_at(diggable, i % columns, i / columns, columns, rows)
		var kind := _pick_kind()
		var footprint := Treasure.footprint_for(kind, _rng)
		var origin_cell: Variant = _find_spot(region, diggable, footprint)
		if origin_cell == null:
			push_warning("Could not place treasure %d of %d" % [i + 1, treasure_count])
			continue
		_place_treasure(kind, origin_cell as Vector2i, footprint)

func _region_at(area: Rect2i, column: int, row: int, columns: int, rows: int) -> Rect2i:
	var cell_w := area.size.x / columns
	var cell_h := area.size.y / rows
	return Rect2i(
		area.position.x + column * cell_w,
		area.position.y + row * cell_h,
		cell_w,
		cell_h
	)

# Returns the top-left cell of a free footprint inside the region, or null when the
# region is too cramped. The footprint is kept fully inside `diggable` so no treasure
# can end up under the unbreakable border.
func _find_spot(region: Rect2i, diggable: Rect2i, footprint: Vector2i) -> Variant:
	for _attempt in PLACEMENT_ATTEMPTS:
		var max_x := region.end.x - footprint.x
		var max_y := region.end.y - footprint.y
		if max_x < region.position.x or max_y < region.position.y:
			return null
		var candidate := Vector2i(
			_rng.randi_range(region.position.x, max_x),
			_rng.randi_range(region.position.y, max_y)
		)
		var used := Rect2i(candidate, footprint)
		if not diggable.encloses(used):
			continue
		if _overlaps_reserved(used):
			continue
		_reserved.append(used.grow(min_gap))
		return candidate
	return null

func _overlaps_reserved(used: Rect2i) -> bool:
	for taken in _reserved:
		if taken.intersects(used):
			return true
	return false

func _place_treasure(kind: Treasure.Kind, origin_cell: Vector2i, footprint: Vector2i) -> void:
	var cells: Array[Vector2i] = []
	for y in footprint.y:
		for x in footprint.x:
			cells.append(origin_cell + Vector2i(x, y))
	var treasure: Treasure = TREASURE_SCENE.instantiate()
	# Added before setup(): setup() touches @onready children
	_treasures_root.add_child(treasure)
	var world_origin := _field.to_global(_field.cell_to_local_origin(origin_cell))
	treasure.setup(kind, cells, _treasures_root.to_local(world_origin), _field.tile_set.tile_size)
	treasure.collected.connect(_on_treasure_collected)
	_buried.append(treasure)

func _pick_kind() -> Treasure.Kind:
	var total := 0
	for weight in kind_weights.values():
		total += int(weight)
	if total <= 0:
		return Treasure.Kind.SMALL
	var roll := _rng.randi_range(1, total)
	for kind in kind_weights:
		roll -= int(kind_weights[kind])
		if roll <= 0:
			return kind
	return Treasure.Kind.SMALL

func _on_cells_carved(cells: Array[Vector2i]) -> void:
	var still_buried: Array[Treasure] = []
	for treasure in _buried:
		if _shares_cell(treasure.get_cells(), cells):
			treasure.reveal()
		else:
			still_buried.append(treasure)
	_buried = still_buried

func _shares_cell(a: Array[Vector2i], b: Array[Vector2i]) -> bool:
	for cell in a:
		if cell in b:
			return true
	return false

func _on_treasure_collected(treasure: Treasure) -> void:
	_buried.erase(treasure)
	_collected += 1
	treasure_collected.emit(_collected, treasure_count)
	if _collected >= treasure_count:
		all_treasures_collected.emit()
