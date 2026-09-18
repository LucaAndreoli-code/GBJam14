class_name DigTorch
extends AnimatedSprite2D

## The digging minigame's torch: the only light source of the scene.
## The radius read by DigSurface shrinks with the torch countdown.

## Radius of the inner band, in pixels, on a full torch. The wall band is only 32px tall, so the
## outer band (2x this) is what draws the halo across it.
@export var torch_light_radius: float = 20.0
## Floor of the radius: the light never drops below this fraction
@export var torch_light_min_value: float = 0.25
## Multipliers of the inner radius, the same contract the dungeon torches use, see
## torch_interactable.gd. DigSurface ignores them and keeps its own, they are here so the full
## screen pass reads a complete source.
@export var light_central_radius_ratio: float = 1.15
@export var light_outer_radius_ratio: float = 2.0

var _light_value: float = 1.0

func _ready() -> void:
	# Read once as well as listening: the signal only fires on a change
	_light_value = _read_light_value()
	SignalBus.torch_tick.connect(_on_torch_tick)

## Called every frame by DigSurface, see dig_surface.gd. Same duck-typed contract as the dungeon's
## ScreenVisibilityManager, so this stays a valid source if the full screen pass is ever used here:
## the inner radius first, then the two band multipliers.
func get_light_radius() -> Vector3:
	var radius: float = torch_light_radius * clamp(_light_value, torch_light_min_value, 1.0)
	return Vector3(radius, light_central_radius_ratio, light_outer_radius_ratio)

func _on_torch_tick(_remaining: int, light_value: float) -> void:
	_light_value = light_value

# TorchTimer.Data only carries the raw numbers, so the ratio is rebuilt here. The guard
# covers the scene being run on its own, before anything seeded GameState.
func _read_light_value() -> float:
	var torch := GameState.get_torch()
	if torch.duration <= 0:
		return 1.0
	return clamp(float(torch.countdown) / float(torch.duration), 0.0, 1.0)
