class_name GameTime
extends Node2D

class Data:
	var time: float = 0.0
	var seconds: int = 0
	var last_tick: float = 0.0
	
const TICK_INTERVAL := 1.0

var _game_time: float = 0.0
var _game_seconds: int = 0
var _last_tick_time: float = 0.0

func _ready() -> void:
	var game_time := GameState.get_time()
	if game_time:
		_game_time = game_time.time
		_game_seconds = game_time.seconds
		_last_tick_time = game_time.last_tick

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
	var time_data := Data.new()
	time_data.time = _game_time
	time_data.seconds = _game_seconds
	time_data.last_tick = _last_tick_time
	GameState.set_time(time_data)
