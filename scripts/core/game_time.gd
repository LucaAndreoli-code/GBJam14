class_name GameTime
extends Node2D

const TICK_INTERVAL := 1.0

var _game_time: float = 0.0
var _game_seconds: int = 0
var _last_tick_time: float = 0.0

func _process(delta: float) -> void:
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

func get_game_time() -> float:
	return _game_time

func set_game_time(value: float) -> void:
	if _game_time != value:
		_game_seconds = int(value)
		_game_time = value
		_last_tick_time = value
