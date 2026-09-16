class_name DiggingMinigame
extends Node2D

## Root of the digging minigame: spawns the buried treasures, reveals them as the
## terrain is carved, and counts what the player brings home.

## Emits on every pickup, with the running total and the target
signal treasure_collected(total: int, target: int)
## Emits when the last treasure is picked up
signal all_treasures_collected()
## Emits when the sonar fires, carrying the seconds until it is usable again
signal sonar_pinged(cooldown: float)

const TREASURE_SCENE := preload("res://entities/digging/treasure/treasure.tscn")

# Attempts per region before giving up on placing that treasure
const PLACEMENT_ATTEMPTS := 24

# Input action that fires the sonar
const SONAR_ACTION := "btn_a"

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
## How far the sonar reaches, in px. Roughly 5 cells at the default 8px tile.
@export var sonar_radius: float = 40.0
## Seconds between two usable scans
@export var sonar_cooldown: float = 4.0
## How long a treasure keeps blinking once the wave reaches it, in seconds
@export var sonar_flash_time: float = 1.5

@onready var _game_time: GameTime = $GameTime
@onready var _field: DigField = $DigField
@onready var _player: DigPlayer = $DigPlayer
@onready var _treasures_root: Node2D = $Treasures
@onready var _sonar_ring: SonarRing = $SonarRing

var _rng := RandomNumberGenerator.new()
var _buried: Array[Treasure] = []
var _reserved: Array[Rect2i] = []
var _collected: int = 0
var _sonar_left: float = 0.0
var _sonar_origin: Vector2 = Vector2.ZERO
var _sonar_pending: Array[Treasure] = []
var _is_input_enabled: bool = true
var _hud: DigHUD
var _started: bool = false
var _torch: TorchTimer
var _dungeon_payload: Dictionary

func _ready() -> void:
	# Read once as well as listening: the signal only fires on a change
	_is_input_enabled = GameState.is_input_enabled()
	SignalBus.input_enabled.connect(_on_input_enabled)
	_field.cells_carved.connect(_on_cells_carved)
	# DigField.fill() already ran: children are readied before their parent.
	# The pocket is carved here rather than with the layout below because it owes nothing
	# to the seed, and leaving it a frame late would let the player be shoved out of the
	# dirt it spawns in.
	_open_start_pocket()
	# One place to balance the reach: the ring only needs it to pace its sweep
	_sonar_ring.radius = sonar_radius
	_mount_hud()
	# Deferred so a scene entered without a payload still gets a layout: SceneManager calls
	# on_scene_entered() after _ready(), so generating here would burn a seed the caller is
	# about to replace. Whichever path runs first wins, the other is a no-op.
	_start_run.call_deferred()

# Builds the layout the seed describes. Guarded because both _ready() and
# on_scene_entered() ask for it and only the first one may run.
func _start_run() -> void:
	if _started:
		return
	_started = true
	_rng.seed = GameState.get_seed()
	_reserve_start_pocket()
	_spawn_treasures()

# The strip lives in main.tscn, outside this scene, so it is found by group rather
# than by path. Running the minigame on its own leaves the group empty, which is why
# every later call has to tolerate a null HUD.
func _mount_hud() -> void:
	var container := get_tree().get_first_node_in_group(Groups.HUD_CONTAINER) as Control
	if container == null:
		return
	_hud = DigHUD.new()
	container.add_child(_hud)
	_hud.set_progress(_collected, treasure_count)

func _process(delta: float) -> void:
	_sonar_left = maxf(_sonar_left - delta, 0.0)
	if _is_input_enabled and _sonar_left <= 0.0 and Input.is_action_just_pressed(SONAR_ACTION):
		_fire_sonar()
	_advance_sonar_wave()
	if _hud != null:
		_hud.set_cooldown_ratio(get_sonar_cooldown_ratio())

func _on_input_enabled(is_enabled: bool) -> void:
	_is_input_enabled = is_enabled

## Called by SceneManager when this scene is entered, see scene_manager.gd
func on_scene_entered(payload: Dictionary) -> void:
	var incoming_seed: int = payload.get("seed", 0)
	if incoming_seed != 0:
		GameState.set_seed(incoming_seed)
	_dungeon_payload = payload
	_start_run()

## Returns how many treasures the player has picked up so far
func get_collected_count() -> int:
	return _collected

## Returns true when the sonar can be fired again
func is_sonar_ready() -> bool:
	return _sonar_left <= 0.0

## 0 right when the sonar comes back up, 1 right after a ping. For a cooldown gauge.
func get_sonar_cooldown_ratio() -> float:
	if sonar_cooldown <= 0.0:
		return 0.0
	return _sonar_left / sonar_cooldown

# Sends the wave out from where the player stands right now. The origin is captured once
# and never follows the player: the ring is drawn from it and the treasure distances are
# measured against it, so walking away mid sweep cannot desync the two.
func _fire_sonar() -> void:
	_sonar_left = sonar_cooldown
	_sonar_origin = _player.global_position
	_sonar_ring.global_position = _sonar_origin
	_sonar_ring.ping()
	# Buried only: a revealed treasure is already on screen and a collected one is gone
	_sonar_pending.clear()
	for treasure in _buried:
		if treasure.global_position.distance_to(_sonar_origin) <= sonar_radius:
			_sonar_pending.append(treasure)
	sonar_pinged.emit(sonar_cooldown)

# Starts a treasure blinking on the frame the ring passes over it, rather than lighting
# every one of them at once, so the sweep reads as actually finding them.
func _advance_sonar_wave() -> void:
	if _sonar_pending.is_empty():
		return
	# -1 means the sweep is over: everything left is inside the radius by construction,
	# so flash it now instead of dropping it on a rounding error.
	var front := _sonar_ring.get_wave_radius()
	if front < 0.0:
		front = sonar_radius
	var still_waiting: Array[Treasure] = []
	for treasure in _sonar_pending:
		# A treasure revealed mid sweep can be collected and freed before the wave lands
		if not is_instance_valid(treasure):
			continue
		if treasure.global_position.distance_to(_sonar_origin) > front:
			still_waiting.append(treasure)
		else:
			treasure.flash(sonar_flash_time)
	_sonar_pending = still_waiting

# The player spawns inside the dirt, so clear the cells under its body first or
# move_and_slide() would spend the first frames shoving it out of solid tiles.
func _open_start_pocket() -> void:
	var body := _player.get_body_rect()
	_field.carve(Rect2(_field.to_local(body.position), body.size))

func _reserve_start_pocket() -> void:
	var start_cell := _field.global_to_cell(_player.global_position)
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
	var world_origin := _field.cell_to_global_origin(origin_cell)
	treasure.setup(kind, cells, _treasures_root.to_local(world_origin), _field.get_cell_size(), _rng)
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
	if _hud != null:
		_hud.set_progress(_collected, treasure_count)
	treasure_collected.emit(_collected, treasure_count)
	if _collected >= treasure_count:
		all_treasures_collected.emit()
		push_warning("All treasure collected")
		_swap_back_to_dungeon()

func _swap_back_to_dungeon() -> void:
	var scene_path: String = _dungeon_payload.get("scene_path", null)
	var player_pos: Vector2 = _dungeon_payload.get("player_position", Vector2.ZERO)
	var payload := {
		"player_position": player_pos
	}
	SceneManager.go_to(scene_path, payload)
