extends Node

var _seed: int = 0
var _torch_ended: bool = false
var _paused: bool = false

func get_seed() -> int:
	if _seed == 0:
		set_seed(randi_range(1, UINT32_MAX))
		push_warning("Seed not set, generated %d instead" % _seed)
	return _seed

func set_seed(value: int) -> void:
	_seed = value
	seed(_seed)

func is_torch_ended() -> bool:
	return _torch_ended

func set_torch_ended(value: bool) -> void:
	if _torch_ended == value:
		return
	_torch_ended = value
	SignalBus.torch_ended.emit(_torch_ended)

func is_paused() -> bool:
	return _paused

func set_paused(value: bool) -> void:
	if _paused == value:
		return
	_paused = value
	SignalBus.game_paused.emit(_paused)
