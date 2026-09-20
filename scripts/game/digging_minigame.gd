class_name DiggingMinigame
extends Node2D

## Root of the digging minigame: spawns the buried treasures, reveals them as the
## terrain is carved, and counts what the player brings home.

## Emits on every pickup, with what was picked up plus the running total and the target
signal treasure_collected(info: TreasureInfo, total: int, target: int)
## Emits when the last treasure is picked up
signal all_treasures_collected()
## Emits when the sonar fires, carrying the seconds until it is usable again
signal sonar_pinged(cooldown: float)

const TREASURE_SCENE := preload("res://entities/digging/treasure/treasure.tscn")
const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/game/pause_menu.tscn")
const CONFIRM_BOX_SCENE: PackedScene = preload("res://scenes/ui/gb_text_box.tscn")

# Clear of the bottom bar, which nothing switches off for the run: main.tscn keeps that
# strip at y 128, and the box is 48px tall.
const CONFIRM_BOX_POSITION := Vector2(0.0, 76.0)

# Attempts per region before giving up on placing that treasure
const PLACEMENT_ATTEMPTS := 24

# Input action that fires the sonar
const SONAR_ACTION := "btn_a"

## Treasures buried when the scene runs on its own. A run entered from the dungeon is handed
## its list in the payload and ignores this one.
@export var fallback_treasures: Array[TreasureInfo] = []
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
## Torch seconds used only when the minigame is entered without coming from the dungeon
@export var torch_duration_seconds: int = 120
## Gameover seconds used only when the minigame is entered without coming from the dungeon
@export var gameover_duration_seconds: int = 60

@onready var _game_time: GameTime = $GameTime
@onready var _field: DigField = $DigField
@onready var _player: DigPlayer = $DigPlayer
@onready var _treasures_root: Node2D = $Treasures
@onready var _sonar_ring: SonarRing = $SonarRing
@onready var _exit: DigExit = $ExitPoint

var _rng := RandomNumberGenerator.new()
var _run_treasures: Array[TreasureInfo] = []
var _collected_infos: Array[TreasureInfo] = []
var _buried: Array[Treasure] = []
var _reserved: Array[Rect2i] = []
var _collected: int = 0
var _sonar_left: float = 0.0
var _sonar_origin: Vector2 = Vector2.ZERO
var _sonar_pending: Array[Treasure] = []
var _is_input_enabled: bool = true
# The sonar polls Input, which knows nothing about the confirm box having eaten a press,
# so the btn_a that answers the exit question would ping on that same frame. The flag
# covers exactly that frame, see _process().
var _swallow_sonar_press: bool = false
var _hud: DigHUD
var _status_hud: StatusHUD
var _pause_menu: Node
var _confirm_box: GBTextBox
var _started: bool = false
# The run can ask to leave more than once: the last pickup waits out its flicker before
# swapping, and the exit stays walkable for those frames. Only the first ask counts.
var _leaving: bool = false
# Tells the two things the confirm box is used for apart: dialogue_finished fires for a
# question as well, and that path is owned by _on_leave_choice().
var _dialogue_open: bool = false
var _torch: TorchTimer
var _gameover: GameoverTimer
var _dungeon_payload: Dictionary

func _ready() -> void:
	# Read once as well as listening: the signal only fires on a change
	_is_input_enabled = GameState.is_input_enabled()
	SignalBus.input_enabled.connect(_on_input_enabled)
	SignalBus.dialogue_requested.connect(_on_dialogue_requested)
	SignalBus.game_paused.connect(_on_game_paused)
	_field.cells_carved.connect(_on_cells_carved)
	_exit.player_returned.connect(_on_player_returned)
	_exit.set_player(_player)
	# DigField.fill() already ran: children are readied before their parent.
	# The pocket is carved here rather than with the layout below because it owes nothing
	# to the seed, and leaving it a frame late would let the player be shoved out of the
	# dirt it spawns in.
	_open_start_pocket()
	# One place to balance the reach: the ring only needs it to pace its sweep
	_sonar_ring.radius = sonar_radius
	# The dungeon's TorchTimer died with the dungeon scene, so the countdown needs its own
	# owner here or it would freeze for the whole minigame. It resumes from GameState.
	_setup_torch()
	_setup_gameover()
	_torch = TorchTimer.new()
	_torch.torch_ended.connect(_on_torch_ended)
	# The gameover countdown keeps running down here: the torch can die with the exit
	# question up, and GameState is the only thing that carries it across the swap.
	_gameover = GameoverTimer.new()
	# The darkness here lives on the Surface sprite alone, see dig_surface.gd: the full screen
	# pass would swallow the dig field too, and that has to stay readable.
	SignalBus.visibility_shader_toggled.emit(false)
	_mount_hud()
	_torch.broadcast()
	_gameover.broadcast()
	# Deferred so a scene entered without a payload still gets a layout: SceneManager calls
	# on_scene_entered() after _ready(), so generating here would burn a seed the caller is
	# about to replace. Whichever path runs first wins, the other is a no-op.
	_start_run.call_deferred()
	
func _exit_tree() -> void:
	if is_instance_valid(_hud):
		_hud.queue_free()
	if is_instance_valid(_status_hud):
		_status_hud.queue_free()
	if is_instance_valid(_pause_menu):
		_pause_menu.queue_free()
	if is_instance_valid(_confirm_box):
		_confirm_box.queue_free()

# Builds the layout the seed describes. Guarded because both _ready() and
# on_scene_entered() ask for it and only the first one may run.
func _start_run() -> void:
	if _started:
		return
	_started = true
	_rng.seed = GameState.get_seed()
	# DigField filled itself on _ready(), before the seed was known: repainting here is what
	# makes the same seed scatter the same debris twice.
	_field.fill(_rng)
	# The refill put back the dirt the pocket had taken out
	_open_start_pocket()
	_resolve_treasures()
	_reserve_start_pocket()
	_spawn_treasures()
	# The HUD is mounted in _ready(), before the list is known, so it starts out on 0/0
	if _hud != null:
		_hud.set_progress(_collected, get_treasure_count())

# The run buries exactly what it is handed: the caller owns which treasures are still out
# there. The exported list is only what a standalone run falls back on.
func _resolve_treasures() -> void:
	var incoming: Array = _dungeon_payload.get("treasures", [])
	# assign() rather than =: what comes out of the payload is an untyped Array
	_run_treasures.assign(incoming if not incoming.is_empty() else fallback_treasures)
	if _run_treasures.is_empty():
		push_warning("Digging run started with no treasures")
	
# Seeds GameState when the scene is run on its own, so the light ratio has a duration to
# divide by. Mirrors DungeonManager._setup_torch(): whoever gets there first wins.
func _setup_torch() -> void:
	var game_torch := GameState.get_torch()
	if game_torch.duration == 0:
		var torch_data := TorchTimer.Data.new()
		torch_data.duration = torch_duration_seconds
		torch_data.countdown = torch_duration_seconds
		GameState.set_torch(torch_data)

# Mirrors DungeonManager._setup_gameover(): whoever gets there first wins.
func _setup_gameover() -> void:
	var data := GameState.get_gameover()
	if data.duration == 0:
		var gameover_data := GameoverTimer.Data.new()
		gameover_data.duration = gameover_duration_seconds
		gameover_data.countdown = gameover_duration_seconds
		GameState.set_gameover(gameover_data)

# The strip lives in main.tscn, outside this scene, so it is found by group rather
# than by path. Running the minigame on its own leaves the group empty, which is why
# every later call has to tolerate a null HUD.
func _mount_hud() -> void:
	var container := get_tree().get_first_node_in_group(Groups.HUD_CONTAINER) as Control
	if container == null:
		return
	_hud = DigHUD.new()
	container.add_child(_hud)
	_hud.set_progress(_collected, get_treasure_count())
	# The dungeon HUD died with the dungeon scene, so the run mounts its own copy: the torch
	# keeps burning down here and the player has to see it.
	_status_hud = StatusHUD.new(false)
	container.add_child(_status_hud)
	# Mounted last, so the paused screen covers everything else. The menu owns the
	# btn_start / btn_b toggle on its own, see pause_manager.gd.
	_pause_menu = PAUSE_MENU_SCENE.instantiate()
	container.add_child(_pause_menu)
	# No inventory halfway down a dig: the run never calls setup(), so the menu has neither a
	# player nor a scene to come back to, see PauseMenuManager._open_inventory().
	(_pause_menu as PauseMenuManager).set_action_disabled(&"_open_inventory", true)
	# After the pause menu on purpose: _unhandled_input walks the tree bottom up, so the
	# box sees btn_start first and can keep the paused screen off a live question.
	_confirm_box = CONFIRM_BOX_SCENE.instantiate()
	_confirm_box.position = CONFIRM_BOX_POSITION
	container.add_child(_confirm_box)
	_confirm_box.choice_made.connect(_on_leave_choice)
	# Same box serves the exit question and any plain dialogue, see _on_dialogue_requested()
	_confirm_box.dialogue_finished.connect(_on_dialogue_finished)

func _process(delta: float) -> void:
	_sonar_left = maxf(_sonar_left - delta, 0.0)
	var can_ping := _is_input_enabled and not _swallow_sonar_press and _sonar_left <= 0.0
	if can_ping and Input.is_action_just_pressed(SONAR_ACTION):
		_fire_sonar()
	# Cleared right here rather than deferred: the message queue can flush before _process
	# and would let the very press the flag exists for through.
	_swallow_sonar_press = false
	_advance_sonar_wave()
	if _hud != null:
		_hud.set_cooldown_ratio(get_sonar_cooldown_ratio())

func _on_input_enabled(is_enabled: bool) -> void:
	_is_input_enabled = is_enabled

# Resume is answered with btn_a, and the scene starts processing again on that very frame: the
# polled sonar would read the same press, exactly like it does after the exit question, see
# _on_leave_choice().
func _on_game_paused(is_paused: bool) -> void:
	if is_paused:
		return
	_swallow_sonar_press = true

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

## Returns how many treasures this run buried
func get_treasure_count() -> int:
	return _run_treasures.size()

## Returns the resources of the treasures picked up so far. Banking is not its job: every
## pickup goes straight into GameState, see _on_treasure_collected().
func get_collected_treasures() -> Array[TreasureInfo]:
	return _collected_infos

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
	var count := get_treasure_count()
	var columns := int(ceil(sqrt(float(count))))
	var rows := int(ceil(float(count) / float(columns)))
	for i in count:
		var info := _run_treasures[i]
		var region := _region_at(diggable, i % columns, i / columns, columns, rows)
		var footprint := Treasure.footprint_for(info.kind, _rng)
		var origin_cell: Variant = _find_spot(region, diggable, footprint)
		if origin_cell == null:
			push_warning("Could not place %s, treasure %d of %d" % [info.name, i + 1, count])
			continue
		_place_treasure(info, origin_cell as Vector2i, footprint)

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

func _place_treasure(info: TreasureInfo, origin_cell: Vector2i, footprint: Vector2i) -> void:
	var cells: Array[Vector2i] = []
	for y in footprint.y:
		for x in footprint.x:
			cells.append(origin_cell + Vector2i(x, y))
	var treasure: Treasure = TREASURE_SCENE.instantiate()
	# Added before setup(): setup() touches @onready children
	_treasures_root.add_child(treasure)
	var world_origin := _field.cell_to_global_origin(origin_cell)
	treasure.setup(info, cells, _treasures_root.to_local(world_origin), _field.get_cell_size())
	treasure.collected.connect(_on_treasure_collected)
	_buried.append(treasure)

# Every carve rechecks the treasures still buried - there are at most a handful of them,
# and the set of cells just removed is no longer enough on its own: what decides a reveal
# is whether the whole footprint is clear, not whether this carve touched it.
func _on_cells_carved(_cells: Array[Vector2i]) -> void:
	var still_buried: Array[Treasure] = []
	for treasure in _buried:
		if _is_dug_out(treasure):
			treasure.reveal()
		else:
			still_buried.append(treasure)
	_buried = still_buried

## A treasure only counts as dug out once every cell of its footprint is gone: a chest
## poking out of the dirt is a hint, not yet something to pick up.
func _is_dug_out(treasure: Treasure) -> bool:
	for cell in treasure.get_cells():
		if _field.is_solid(cell):
			return false
	return true

func _on_treasure_collected(treasure: Treasure) -> void:
	_buried.erase(treasure)
	_collected += 1
	var info := treasure.get_info()
	_collected_infos.append(info)
	# Banked on the spot rather than on the way out: the points strip is mounted down here too,
	# and the run has no way of losing what it already dug up.
	var banked: Array[TreasureInfo] = [info]
	GameState.add_treasures_to_collection(banked)
	if _hud != null:
		_hud.set_progress(_collected, get_treasure_count())
	treasure_collected.emit(info, _collected, get_treasure_count())
	if _collected >= get_treasure_count():
		all_treasures_collected.emit()
		# The swap pauses the whole tree, so starting it now would freeze the flicker on the
		# last treasure, the one pickup the player is most likely to be watching. Input goes
		# off meanwhile, and _swap_back_to_dungeon() puts it back.
		GameState.set_input_enabled(false)
		treasure.pickup_finished.connect(_swap_back_to_dungeon, CONNECT_ONE_SHOT)

# The only way out of the run: the pit has no other exit. Everything dug up means leaving
# on the spot; anything still buried gets the player asked first. Input goes off either
# way, so nobody walks around behind the question.
func _on_player_returned() -> void:
	GameState.set_input_enabled(false)
	if _collected >= get_treasure_count():
		_swap_back_to_dungeon()
		return
	# Null when the run found no HUD to mount into, see _mount_hud(): there is nothing to
	# ask with, so the exit stays as final as it was before the question existed.
	if _confirm_box == null:
		push_warning("Exit reached with %d/%d treasures" % [_collected, get_treasure_count()])
		_swap_back_to_dungeon()
		return
	var left := get_treasure_count() - _collected
	var subject := "treasure" if left == 1 else "treasures"
	_confirm_box.show_confirm(PackedStringArray([
		"You're leaving %d %s behind. Climb out anyway?" % [left, subject]
	]))

# The box lives in main.tscn's HUD, outside this scene, so the run drives it through the bus
# instead of the caller reaching for it. Mirrors DungeonManager._on_dialogue_requested().
func _on_dialogue_requested(lines: PackedStringArray) -> void:
	if _confirm_box == null or _confirm_box.is_open():
		return
	_dialogue_open = true
	GameState.set_input_enabled(false)
	# Nobody burns torch seconds reading. Both countdowns hang off GameTime's second tick,
	# see TorchTimer._on_game_second_tick() and GameoverTimer._on_game_second_tick(), so the
	# clock itself is what goes off - stopping only the torch would let the gameover run on.
	_game_time.set_process(false)
	_confirm_box.show_dialogue(lines)

func _on_dialogue_finished() -> void:
	# A closing question fires this too, and that one is answered by _on_leave_choice()
	if not _dialogue_open:
		return
	_dialogue_open = false
	_game_time.set_process(true)
	# The press that closed the box is spent, and the polled sonar is about to read it again
	_swallow_sonar_press = true
	GameState.set_input_enabled(true)

func _on_leave_choice(accepted: bool) -> void:
	# Either way the press that answered is spent, and gameplay is about to hear about it
	# again through the polled Input state
	_swallow_sonar_press = true
	# The torch can die with the question up: the run is already leaving, the answer is moot
	if _leaving:
		return
	if accepted:
		_swap_back_to_dungeon()
		return
	# Staying: the exit has to be walked out of and back into before it asks again
	_exit.rearm()
	GameState.set_input_enabled(true)

# No torch, no run: the pit goes dark and the player is put back in the dungeon with
# whatever they already dug up. Mirrors DungeonManager._on_torch_ended(), which is the only
# other listener TorchTimer has.
func _on_torch_ended() -> void:
	# The swap goes first, so _leaving is up before the question below is taken down: a
	# close() answers choice_made, and that answer must not rearm an exit the run is
	# already leaving through.
	_swap_back_to_dungeon()
	if _confirm_box != null and _confirm_box.is_open():
		_confirm_box.close()

func _swap_back_to_dungeon() -> void:
	if _leaving:
		return
	_leaving = true
	# GameState is an autoload and SceneManager never touches the input flag, so leaving it
	# off here would hand the dungeon a frozen player
	GameState.set_input_enabled(true)
	var scene_path: String = _dungeon_payload.get("scene_path", "")
	# Empty when the minigame is run on its own: there is no dungeon to go back to
	if scene_path.is_empty():
		push_warning("No dungeon to go back to: the minigame was entered without a payload")
		return
	var player_pos: Vector2 = _dungeon_payload.get("player_position", Vector2.ZERO)
	var payload := {
		"player_position": player_pos
	}
	SceneManager.go_to(scene_path, payload)
