extends Node2D

const TICK_INTERVAL := 1.0

@export var torch_duration_seconds: int = 240

var _game_time: float = 0.0
var _game_seconds: int = 0
var _last_tick_time: float = 0.0
var _torch: TorchManager

func _ready() -> void:
	_torch = TorchManager.new(torch_duration_seconds)

func _process(delta: float) -> void:
	_update_game_tick(delta)

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
