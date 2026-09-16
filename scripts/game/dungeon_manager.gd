class_name DungeonManager
extends Node2D

const MINIGAME_SCENE_PATH: String = "res://scenes/minigames/digging/digging_minigame.tscn"
const MAP_SCENE_PATH: String = "res://scenes/game/map.tscn"
const PAUSE_MENU_SCENE_PATH: String = "res://scenes/game/pause.tscn"

@export var torch_duration_seconds: int = 120
@export var gameover_duration_seconds: int = 60

@onready var _game_time: GameTime = $GameTime
@onready var _level_tilemap: TileMapLayer = $DungeonTilemap
@onready var _player: PlayerDungeonController = $PlayerDungeon
@onready var _camera: CameraDungeon = $Camera2D

var _hud_container: Control
var _torch: TorchManager

var _minimap_hud: MinimapHUD
var _torch_hud: TorchHUD

var _is_gameover_mode: bool = false
var _gameover_timer: int = 0
var _is_input_enabled: bool = true

func _ready() -> void:
	_hud_container = get_tree().get_first_node_in_group(Groups.HUD_CONTAINER) as Control
	_minimap_hud = MinimapHUD.new(_level_tilemap, _player)
	_torch_hud = TorchHUD.new()
	_torch = TorchManager.new(torch_duration_seconds)
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
	elif event.is_action_pressed("btn_start"):
		_open_pause_menu()

func on_scene_entered(payload: Dictionary) -> void:
	var incoming_game_time: float = payload.get("game_time", 0.0)
	if incoming_game_time != 0.0:
		_game_time.set_game_time(incoming_game_time)
	var incoming_torch_duration: int = payload.get("torch_timer", 0)
	if incoming_torch_duration != 0:
		_torch = TorchManager.new(incoming_torch_duration)
	if payload.has("player_position"):
		_player.global_position = payload.get("player_position", Vector2.ZERO)
		_camera.snap_to_player()
	SceneManager.get_main_scene().toggle_bottom_bar(true)
	_minimap_hud.set_disabled(false)
	SignalBus.visibility_shader_toggled.emit(true)

func start_digging_minigame() -> void:
	SignalBus.visibility_shader_toggled.emit(false)
	_minimap_hud.set_disabled(true)
	var payload := {
		"game_time": _game_time.get_game_time(),
		"torch_timer": _torch.get_remaining_duration(),
		"scene_path": scene_file_path,
		"player_position": _player.global_position
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

func _init_hud() -> void:
	if _hud_container:
		_hud_container.add_child(_torch_hud)
		_hud_container.add_child(_minimap_hud)

func _tick_gameover_timer() -> void:
	if not _is_gameover_mode:
		return
	if _gameover_timer > 0:
		_gameover_timer -= 1
	print("Game update: %d seconds from gameover" % _gameover_timer)

func _open_map() -> void:
	SignalBus.visibility_shader_toggled.emit(false)
	_minimap_hud.set_disabled(true)
	var payload := {
		"game_time": _game_time.get_game_time(),
		"torch_timer": _torch.get_remaining_duration(),
		"scene_path": scene_file_path,
		"player_position": _player.global_position,
		"map_data": _minimap_hud.get_data_layer()
	}
	SceneManager.go_to(MAP_SCENE_PATH, payload)

func _open_pause_menu() -> void:
	SignalBus.visibility_shader_toggled.emit(false)
	_minimap_hud.set_disabled(true)
	var payload := {
		"game_time": _game_time.get_game_time(),
		"torch_timer": _torch.get_remaining_duration(),
		"scene_path": scene_file_path,
		"player_position": _player.global_position
	}
	SceneManager.go_to(PAUSE_MENU_SCENE_PATH, payload)
