class_name TorchManager
extends RefCounted

var _duration: int = 0
var _tick: float = 0.0
var _timer: int = 0
var _enabled: bool = true

func _init(duration: int) -> void:
	assert(duration > 0, "Torch's system received zero as duration in seconds, which will produce division by zero")
	_duration = duration
	_timer = duration
	SignalBus.game_paused.connect(_on_game_paused)

func get_light_value() -> float:
	return clamp(float(_timer) / float(_duration), 0.0, 1.0)

func tick(delta: float) -> void:
	if not _enabled:
		return
	_tick += delta
	if _tick >= 1.0:
		_do_tick()

func refill(target_p: float = 1.0) -> void:
	_timer = round(_duration * target_p)

func _do_tick() -> void:
	_tick -= 1.0
	if _timer > 0:
		_timer -= 1
	var light_value := get_light_value()
	SignalBus.torch_tick.emit(_timer, light_value)
	print("Torch tick: %f (%d/%d)" % [light_value, _timer, _duration])

func _on_game_paused(is_paused: bool) -> void:
	_enabled = !is_paused
