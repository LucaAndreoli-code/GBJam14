extends Node2D

const TICK_INTERVAL := 1.0

@export var torch_duration_seconds: int = 120
@export var gameover_duration_seconds: int = 60

@onready var _level_tilemap: TileMapLayer = $DungeonTilemap
@onready var _player: PlayerDungeonController = $PlayerDungeon
@onready var _inventory: CanvasLayer = $InventoryLayer

var _hud_container: Control
var _torch: TorchManager

var _minimap_hud: MinimapHUD
var _torch_hud: TorchHUD

var _game_time: float = 0.0
var _game_seconds: int = 0
var _last_tick_time: float = 0.0
var _is_gameover_mode: bool = false
var _gameover_timer: int = 0
var _is_input_enabled: bool = true
var _is_inventory_opened: bool = false

func _ready() -> void:
	_hud_container = get_tree().get_first_node_in_group(Groups.HUD_CONTAINER) as Control
	_minimap_hud = MinimapHUD.new(_level_tilemap, _player)
	_torch = TorchManager.new(torch_duration_seconds)
	_torch.torch_ended.connect(_on_torch_ended)
	_torch_hud = TorchHUD.new(_torch.get_remaining_duration())
	SignalBus.input_enabled.connect(_on_input_enabled)
	SignalBus.torch_refill.connect(_on_torch_refill)
	_init_hud()

func _process(delta: float) -> void:
	_update_game_tick(delta)

func _unhandled_input(event: InputEvent) -> void:
	if not _is_input_enabled:
		return
	if event.is_action_pressed("btn_b"):
		if _is_inventory_opened:
			SignalBus.visibility_shader_toggled.emit(true)
			_inventory.visible = false
			_minimap_hud.visible = true
			GameState.set_paused(false)
			_is_inventory_opened = false
	if event.is_action_pressed("btn_select"):
		SignalBus.visibility_shader_toggled.emit(false)
		_minimap_hud.visible = false
		_inventory.visible = true
		GameState.set_paused(true)
		_is_inventory_opened = true

func _on_input_enabled(is_enabled: bool) -> void:
	_is_input_enabled = is_enabled

func _on_torch_refill(_source: Node2D) -> void:
	if _is_gameover_mode:
		_is_gameover_mode = false

func _on_torch_ended() -> void:
	_gameover_timer = gameover_duration_seconds
	_is_gameover_mode = true

func _init_hud() -> void:
	if _inventory:
		_inventory.visible = false
	if _hud_container:
		_hud_container.add_child(_torch_hud)
		_hud_container.add_child(_minimap_hud)

func _update_game_tick(delta: float) -> void:
	if GameState.is_paused():
		return
	_game_time += delta
	SignalBus.game_tick.emit(delta, _game_time)
	var local_delta := _game_time - _last_tick_time
	if local_delta > TICK_INTERVAL:
		_game_seconds += 1
		_last_tick_time = _game_time - (local_delta - TICK_INTERVAL)
		print("Game update: %d seconds elapsed" % _game_seconds)
		SignalBus.game_second_tick.emit(_game_seconds)
		_tick_gameover_timer()

func _tick_gameover_timer() -> void:
	if not _is_gameover_mode:
		return
	if _gameover_timer > 0:
		_gameover_timer -= 1
	print("Game update: %d seconds from gameover" % _gameover_timer)
