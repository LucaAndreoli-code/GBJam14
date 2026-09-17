class_name DungeonManager
extends Node2D

const MINIGAME_SCENE_PATH: String = "res://scenes/minigames/digging/digging_minigame.tscn"
const MAP_SCENE_PATH: String = "res://scenes/game/map.tscn"
const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/game/pause_menu.tscn")

@export var torch_duration_seconds: int = 120
@export var gameover_duration_seconds: int = 60
## Treasures this dungeon still has to give up, handed to the digging minigame as the exact
## set to bury. Temporary: the list belongs in the global state once the inventory owns it,
## see start_digging_minigame(). Left empty, the minigame falls back on its own export.
@export var minigame_treasures: Array[TreasureInfo] = []

@onready var _level_tilemap: TileMapLayer = $DungeonTilemap
@onready var _player: PlayerDungeonController = $PlayerDungeon
@onready var _camera: CameraDungeon = $Camera2D

var _hud_container: Control
var _torch: TorchTimer
var _minimap: Minimap

var _pause_menu: Node
var _torch_hud: TorchHUD
var _keys_hud: KeysHUD
var _points_hud: PointsHUD

var _is_gameover_mode: bool = false
var _gameover_timer: int = 0
var _is_input_enabled: bool = true

func _ready() -> void:
	Palette.switch_to_palette("main")
	_setup_torch()
	_player.set_dungeon_tilemap(_level_tilemap)
	_minimap = Minimap.new(_level_tilemap, _player)
	add_child(_minimap)
	_hud_container = get_tree().get_first_node_in_group(Groups.HUD_CONTAINER) as Control
	_torch_hud = TorchHUD.new()
	_keys_hud = KeysHUD.new()
	_points_hud = PointsHUD.new()
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
	elif event.is_action_pressed("btn_start"):
		_open_pause_menu()

func _exit_tree() -> void:
	if is_instance_valid(_pause_menu):
		_pause_menu.queue_free()
	if is_instance_valid(_torch_hud):
		_torch_hud.queue_free()
	if is_instance_valid(_keys_hud):
		_keys_hud.queue_free()
	if is_instance_valid(_points_hud):
		_points_hud.queue_free()

func on_scene_entered(payload: Dictionary) -> void:
	# TODO: payload["collected_treasures"] holds the TreasureInfo the digging run brought
	#       home. The inventory that has to bank them lives on another branch, so for now
	#       they are simply dropped.
	if payload.has("player_position"):
		_player.global_position = payload.get("player_position", Vector2.ZERO)
		_camera.snap_to_player()
	SceneManager.get_main_scene().toggle_bottom_bar(true)
	SignalBus.visibility_shader_toggled.emit(true)

func start_digging_minigame() -> void:
	SignalBus.visibility_shader_toggled.emit(false)
	var payload := {
		"scene_path": scene_file_path,
		"player_position": _player.global_position,
		# TODO: read the not-yet-found treasures off GameState once the inventory owns them,
		#       instead of the list hand-filled on this node
		"treasures": minigame_treasures
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

func _setup_torch() -> void:
	var game_torch := GameState.get_torch()
	if game_torch.duration == 0:
		var torch_data := TorchTimer.Data.new()
		torch_data.duration = torch_duration_seconds
		torch_data.countdown = torch_duration_seconds
		GameState.set_torch(torch_data)

func _init_hud() -> void:
	if _hud_container:
		_pause_menu = PAUSE_MENU_SCENE.instantiate()
		_pause_menu.visible = false
		_hud_container.add_child(_pause_menu)
		_hud_container.add_child(_torch_hud)
		_hud_container.add_child(_keys_hud)
		_hud_container.add_child(_points_hud)

func _tick_gameover_timer() -> void:
	if not _is_gameover_mode:
		return
	if _gameover_timer > 0:
		_gameover_timer -= 1
	print("Game update: %d seconds from gameover" % _gameover_timer)

func _open_map() -> void:
	SignalBus.visibility_shader_toggled.emit(false)
	var payload := {
		"scene_path": scene_file_path,
		"player_position": _player.global_position
	}
	SceneManager.go_to(MAP_SCENE_PATH, payload)

func _open_pause_menu() -> void:
	if _pause_menu:
		GameState.set_paused(true)
		_pause_menu.visible = true
