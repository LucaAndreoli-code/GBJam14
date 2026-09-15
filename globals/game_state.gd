extends Node

var _seed: int = 0
var _paused: bool = false

func get_seed() -> int:
	if _seed == 0:
		set_seed(randi_range(1, UINT32_MAX))
		push_warning("Seed not set, generated %d instead" % _seed)
	return _seed

func set_seed(value: int) -> void:
	_seed = value
	seed(_seed)

func is_paused() -> bool:
	return _paused

func set_paused(value: bool) -> void:
	if _paused == value:
		return
	_paused = value
	SignalBus.game_paused.emit(_paused)
