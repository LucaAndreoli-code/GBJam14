class_name TorchManager
extends RefCounted

var _duration: int = 0
var _countdown_timer: int = 0

func _init(duration: int) -> void:
	assert(duration > 0, "Torch's system received zero as duration in seconds, which will produce division by zero")
	_duration = duration
	_countdown_timer = duration
	SignalBus.game_second_tick.connect(_on_game_second_tick)
	SignalBus.torch_refill.connect(_on_refill)

func get_light_value() -> float:
	return clamp(float(_countdown_timer) / float(_duration), 0.0, 1.0)

func _on_game_second_tick(_game_seconds: int) -> void:
	if _countdown_timer > 0:
		_countdown_timer -= 1
	var light_value := get_light_value()
	SignalBus.torch_tick.emit(_countdown_timer, light_value)
	print("Torch update: %d/%d => %f" % [_countdown_timer, _duration, light_value])

func _on_refill(source: Node2D) -> void:
	if source is PlayerDungeonController:
		_countdown_timer = _duration
