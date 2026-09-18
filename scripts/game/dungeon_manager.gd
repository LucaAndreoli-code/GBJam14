class_name DungeonManager
extends Node2D

const MINIGAME_SCENE_PATH: String = "res://scenes/minigames/digging/digging_minigame.tscn"
const MAP_SCENE_PATH: String = "res://scenes/game/map.tscn"
const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/game/pause_menu.tscn")

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
var _minimap: Minimap

var _pause_menu: Node
var _status_hud: StatusHUD

var _is_gameover_mode: bool = false
var _gameover_timer: int = 0
var _is_input_enabled: bool = true

func _ready() -> void:
	Palette.switch_to_palette("main")
	GameState.get_seed()
	_setup_treasures()
	_setup_torch()
	_player.set_dungeon_tilemap(_level_tilemap)
	_minimap = Minimap.new(_level_tilemap, _player)
	add_child(_minimap)
	_hud_container = get_tree().get_first_node_in_group(Groups.HUD_CONTAINER) as Control
	_torch = TorchTimer.new()
	_torch.torch_ended.connect(_on_torch_ended)
	SignalBus.game_second_tick.connect(_on_game_second_tick)
	SignalBus.input_enabled.connect(_on_input_enabled)
	SignalBus.torch_refill.connect(_on_torch_refill)
	_init_hud()

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

func on_scene_entered(payload: Dictionary) -> void:
	if payload.has("player_position"):
		_player.global_position = payload.get("player_position", Vector2.ZERO)
		_camera.snap_to_player()
	if payload.has("collected_treasures"):
		GameState.add_treasures_to_collection(payload.get("collected_treasures", {}))
	SceneManager.get_main_scene().toggle_bottom_bar(true)
	SignalBus.visibility_shader_toggled.emit(true)

func start_digging_minigame() -> void:
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

func _on_game_second_tick(_game_seconds: int) -> void:
	_tick_gameover_timer()

func _on_input_enabled(is_enabled: bool) -> void:
	_is_input_enabled = is_enabled

func _on_torch_refill(_source: Node2D) -> void:
	if _is_gameover_mode:
		_is_gameover_mode = false

func _on_torch_ended() -> void:
	_gameover_timer = gameover_duration_seconds
	_is_gameover_mode = true

func _setup_treasures() -> void:
	if GameState.is_treasures_pool_generated():
		return
	var digging_spots_count := get_tree().get_node_count_in_group(Groups.LEVEL_DIGGING_SPOTS)
	if digging_spots_count <= 0:
		push_warning("No digging spots found for this level!")
		return
	var treasures_count := randi_range( \
		minigame_session_min_treasures * digging_spots_count, \
		minigame_session_max_treasures * digging_spots_count)
	var composition := TreasureUtils.pick_composition(treasures_count, level_target_points)
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

func _init_hud() -> void:
	if _hud_container:
		_status_hud = StatusHUD.new()
		_hud_container.add_child(_status_hud)
		# Mounted last, so the paused screen covers the HUD instead of being drawn under it.
		# The menu hides itself and owns the btn_start / btn_b toggle, see pause_manager.gd.
		_pause_menu = PAUSE_MENU_SCENE.instantiate()
		(_pause_menu as PauseMenuManager).setup(scene_file_path, _player)
		_hud_container.add_child(_pause_menu)

func _tick_gameover_timer() -> void:
	if not _is_gameover_mode:
		return
	if _gameover_timer > 0:
		_gameover_timer -= 1
	print("Game update: %d seconds from gameover" % _gameover_timer)

func _open_map() -> void:
	var payload := {
			"scene_path": scene_file_path,
		"player_position": _player.global_position
	}
	SceneManager.go_to(MAP_SCENE_PATH, payload)
