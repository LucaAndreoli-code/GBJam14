class_name TorchTimer
extends RefCounted

class Data:
	var duration: int = 0
	var countdown: int = 0

signal torch_ended()

var _duration: int = 0
var _countdown_timer: int = 0

func _init() -> void:
	var game_torch := GameState.get_torch()
	_duration = game_torch.duration
	_countdown_timer = game_torch.countdown
	SignalBus.game_second_tick.connect(_on_game_second_tick)
	SignalBus.torch_refill.connect(_on_refill)

func get_remaining_duration() -> int:
	return _countdown_timer

func get_light_value() -> float:
	return clamp(float(_countdown_timer) / float(_duration), 0.0, 1.0)

func _on_game_second_tick(_game_seconds: int) -> void:
	if _countdown_timer == 0:
		return
	elif _countdown_timer > 0:
		_countdown_timer -= 1
	var light_value := get_light_value()
	SignalBus.torch_tick.emit(_countdown_timer, light_value)
	print("Torch update: %d/%d => %f" % [_countdown_timer, _duration, light_value])
	if _countdown_timer == 0:
		torch_ended.emit()
	_update_game_state()

func _on_refill(source: Node2D) -> void:
	if source is PlayerDungeonController:
		_countdown_timer = _duration
		_update_game_state()

func _update_game_state() -> void:
	var torch_data := Data.new()
	torch_data.duration = _duration
	torch_data.countdown = _countdown_timer
	GameState.set_torch(torch_data)
