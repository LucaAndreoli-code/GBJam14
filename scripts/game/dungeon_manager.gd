extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SignalBus.torch_tick.connect(_on_torch_tick)

func _on_torch_tick(remaining: int, _light_value: float) -> void:
	if remaining <= 0:
		GameState.set_torch_ended(true)
