class_name DungeonManager
extends Node2D

const MINIGAME_SCENE_PATH: String = "res://scenes/minigames/digging/digging_minigame.tscn"
const MAP_SCENE_PATH: String = "res://scenes/game/map.tscn"
const GAMEOVER_SCENE_PATH: String = "res://scenes/game/gameover_success.tscn"
const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/game/pause_menu.tscn")
const TEXT_BOX_SCENE: PackedScene = preload("res://scenes/ui/gb_text_box.tscn")
# Clear of the bottom bar at y 128: the box is 52px tall.
const TEXT_BOX_POSITION := Vector2(0.0, 76.0)
const EXIT_TILE_DATA_LAYER: String = "dungeon_entrance"
const OPENED_TILE_DATA_LAYER: String = "opened_tile"
const LOCKED_TILE_DATA_LAYER: String = "locked_door"

@export var level_minimum_points: int = 100
@export var level_target_points: int = 250
@export var torch_duration_seconds: int = 120
@export var gameover_duration_seconds: int = 60
@export var minigame_session_min_treasures: int = 4
@export var minigame_session_max_treasures: int = 4
@export var available_treasures: Array[TreasureInfo] = []

@onready var _level_tilemap: TileMapLayer = $DungeonTilemap
@onready var _player: PlayerDungeonController = $PlayerDungeon
@onready var _camera: CameraDungeon = $Camera2D

var _hud_container: Control
var _torch: TorchTimer
var _gameover: GameoverTimer
var _minimap: Minimap

var _pause_menu: Node
var _status_hud: StatusHUD
var _text_box: GBTextBox

var _exit_cells: Array[Vector2i] = []

var _is_input_enabled: bool = true

func _ready() -> void:
	GameState.get_seed()
	_setup_treasures()
	_setup_torch()
	_setup_gameover()
	_player.set_dungeon_tilemap(_level_tilemap)
	_find_exit_cells()
	_reapply_opened_doors()
	_minimap = Minimap.new(_level_tilemap, _player)
	add_child(_minimap)
	_hud_container = get_tree().get_first_node_in_group(Groups.HUD_CONTAINER) as Control
	_torch = TorchTimer.new()
	# Built before the broadcast below: the zero it pushes out is what arms a countdown
	# entered on a dead torch, see GameoverTimer._on_torch_tick().
	_gameover = GameoverTimer.new()
	SignalBus.input_enabled.connect(_on_input_enabled)
	SignalBus.points_changed.connect(_on_points_changed)
	SignalBus.dialogue_requested.connect(_on_dialogue_requested)
	_init_hud()
	_torch.broadcast()
	_gameover.broadcast()
	SignalBus.gameover_triggered.connect(_on_gameover_triggered)
	SignalBus.exit_door_crossed.connect(_on_exit_door_crossed)

func _unhandled_input(event: InputEvent) -> void:
	if not _is_input_enabled:
		return
	if event.is_action_pressed("btn_select"):
		_open_map()

func _exit_tree() -> void:
	if is_instance_valid(_pause_menu):
		_pause_menu.queue_free()
	if is_instance_valid(_status_hud):
		_status_hud.queue_free()
	if is_instance_valid(_text_box):
		_text_box.queue_free()

func on_scene_entered(payload: Dictionary) -> void:
	AudioManager.play_music(AudioManager.leveltheme)
	if payload.has("player_position"):
		_player.global_position = payload.get("player_position", Vector2.ZERO)
		_camera.snap_to_player()
	SceneManager.get_main_scene().toggle_bottom_bar(true)
	SignalBus.visibility_shader_toggled.emit(true)
	# Moved here because in _ready it renders dialogue box when shader has
	# not already been set up
	await get_tree().create_timer(0.5).timeout
	_refresh_exit_door()

func start_digging_minigame() -> void:
	AudioManager.play_music(AudioManager.minigametheme)
	
	SignalBus.visibility_shader_toggled.emit(false)
	var treasure_count := randi_range(minigame_session_min_treasures, minigame_session_max_treasures)
	var minigame_treasures := GameState.get_treasures_pool()
	if minigame_treasures.size() < treasure_count:
		treasure_count = minigame_treasures.size()
	var session_treasures: Array[TreasureInfo] = []
	for i in range(treasure_count):
		session_treasures.append(minigame_treasures.pop_back())
	var payload := {
		"scene_path": scene_file_path,
		"player_position": _player.global_position,
		"treasures": session_treasures
	}
	SceneManager.go_to(MINIGAME_SCENE_PATH, payload)

func _on_input_enabled(is_enabled: bool) -> void:
	_is_input_enabled = is_enabled

func _on_points_changed(_collected: int, _total: int) -> void:
	_refresh_exit_door()

# The box lives in main.tscn's HUD, outside this scene, so the dungeon drives it through the bus
# instead of the sign reaching for it.
func _on_dialogue_requested(lines: PackedStringArray) -> void:
	if _text_box == null or _text_box.is_open():
		return
	GameState.set_paused(true)
	GameState.set_input_enabled(false)
	_text_box.show_dialogue(lines)

func _on_dialogue_finished() -> void:
	GameState.set_paused(false)
	GameState.set_input_enabled(true)

func _on_gameover_triggered() -> void:
	var payload := {
		"scene_path": scene_file_path,
		"is_gameover": true
	}
	SceneManager.go_to(GAMEOVER_SCENE_PATH, payload)

func _on_exit_door_crossed() -> void:
	var payload := {
		"scene_path": scene_file_path,
		"is_gameover": false
	}
	SceneManager.go_to(GAMEOVER_SCENE_PATH, payload)

# The exit is authored as the alternative tile of the entrance door, so the cells are looked up by
# tile data instead of by a hardcoded coordinate.
func _find_exit_cells() -> void:
	_exit_cells.clear()
	for cell in _level_tilemap.get_used_cells():
		var data := _level_tilemap.get_cell_tile_data(cell)
		if data and data.get_custom_data(EXIT_TILE_DATA_LAYER):
			_exit_cells.append(cell)
	if _exit_cells.is_empty():
		push_warning("No exit door found for this level!")

# Re-run on every dungeon entry: the conditions live in GameState, so a door unlocked before a
# digging run is still unlocked after it. GameState is what keeps the signal to a single emit.
func _refresh_exit_door() -> void:
	if not GameState.is_exit_door_opened():
		if not _is_exit_unlocked():
			return
		var lines: PackedStringArray = ["You feel a draft on your back... a door must have opened somewhere."]
		SignalBus.dialogue_requested.emit(lines)
		GameState.set_exit_door_opened()
	_open_exit_cells()

func _is_exit_unlocked() -> bool:
	if GameState.get_collected_points() >= level_minimum_points:
		return true
	return _are_all_digging_spots_dug()

# A spot that is already dug frees itself in its own _ready(), but queue_free() only lands at the
# end of the frame, so the group still holds it while this runs: ask the spot, don't count nodes.
func _are_all_digging_spots_dug() -> bool:
	var spots := get_tree().get_nodes_in_group(Groups.LEVEL_DIGGING_SPOTS)
	if spots.is_empty():
		return false
	for spot in spots:
		if not (spot as DigInteractable).is_dug():
			return false
	return true

# Key doors are tiles, not nodes, so the reload brings them back locked. Idempotent the same way
# _open_exit_cells() is: a cell that no longer reads as locked has already been swapped.
func _reapply_opened_doors() -> void:
	for cell in GameState.get_opened_doors(scene_file_path):
		var data := _level_tilemap.get_cell_tile_data(cell)
		if data == null or not data.get_custom_data(LOCKED_TILE_DATA_LAYER):
			continue
		var opened_tile: Vector2i = data.get_custom_data(OPENED_TILE_DATA_LAYER)
		if opened_tile == Vector2i.ZERO:
			push_warning("Locked door at %s has no opened_tile set" % cell)
			continue
		_level_tilemap.set_cell(cell, _level_tilemap.get_cell_source_id(cell), opened_tile)

# Idempotent: a cell that no longer reads as an exit has already been swapped.
func _open_exit_cells() -> void:
	for cell in _exit_cells:
		var data := _level_tilemap.get_cell_tile_data(cell)
		if data == null or not data.get_custom_data(EXIT_TILE_DATA_LAYER):
			continue
		var opened_tile: Vector2i = data.get_custom_data(OPENED_TILE_DATA_LAYER)
		if opened_tile == Vector2i.ZERO:
			push_warning("Exit door at %s has no opened_tile set" % cell)
			continue
		_level_tilemap.set_cell(cell, _level_tilemap.get_cell_source_id(cell), opened_tile)

func _setup_treasures() -> void:
	if GameState.is_treasures_pool_generated():
		return
	var digging_spots_count := get_tree().get_node_count_in_group(Groups.LEVEL_DIGGING_SPOTS)
	if digging_spots_count <= 0:
		push_warning("No digging spots found for this level!")
		return
	var composition := TreasureUtils.pick_composition(
		level_target_points, \
		digging_spots_count, \
		minigame_session_min_treasures, \
		minigame_session_max_treasures)
	if composition.size() == 0:
		push_warning("Failed to pick a composition")
		push_warning("Digging spots: %d" % digging_spots_count)
		push_warning("Target points: %d" % level_target_points)
		return
	var minigame_treasures := GameState.get_treasures_pool()
	minigame_treasures.clear()
	for kind in composition.keys():
		var availables := available_treasures.filter(func(t): return t.kind == kind)
		for i in range(composition[kind]):
			var pick: TreasureInfo = availables[randi_range(0, availables.size() - 1)]
			minigame_treasures.append(pick)
	minigame_treasures.shuffle()
	GameState.set_treasures_pool(minigame_treasures)

func _setup_torch() -> void:
	var game_torch := GameState.get_torch()
	if game_torch.duration == 0:
		var torch_data := TorchTimer.Data.new()
		torch_data.duration = torch_duration_seconds
		torch_data.countdown = torch_duration_seconds
		GameState.set_torch(torch_data)

# Mirrors _setup_torch(): the countdown is owned by GameState so it survives the pit, and
# whoever gets to an empty one first seeds it.
func _setup_gameover() -> void:
	var data := GameState.get_gameover()
	if data.duration == 0:
		var gameover_data := GameoverTimer.Data.new()
		gameover_data.duration = gameover_duration_seconds
		gameover_data.countdown = gameover_duration_seconds
		GameState.set_gameover(gameover_data)

func _init_hud() -> void:
	if _hud_container:
		_status_hud = StatusHUD.new()
		_hud_container.add_child(_status_hud)
		# Mounted last, so the paused screen covers the HUD instead of being drawn under it.
		# The menu hides itself and owns the btn_start / btn_b toggle, see pause_manager.gd.
		_pause_menu = PAUSE_MENU_SCENE.instantiate()
		(_pause_menu as PauseMenuManager).setup(scene_file_path, _player)
		_hud_container.add_child(_pause_menu)
		# Mounted after the pause menu on purpose: _unhandled_input walks the tree bottom-up, so
		# the box gets btn_a first and swallows it while it is open.
		_text_box = TEXT_BOX_SCENE.instantiate()
		_text_box.position = TEXT_BOX_POSITION
		_hud_container.add_child(_text_box)
		_text_box.dialogue_finished.connect(_on_dialogue_finished)

func _open_map() -> void:
	var payload := {
			"scene_path": scene_file_path,
		"player_position": _player.global_position
	}
	SceneManager.go_to(MAP_SCENE_PATH, payload)
