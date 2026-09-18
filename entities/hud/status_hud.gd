class_name StatusHUD
extends Control

## The bottom strip shared by every scene played inside a dungeon run: torch countdown, keys and
## points. Every child feeds off GameState and SignalBus alone, so the set works wherever it is
## mounted - the dungeon scene and the digging minigame both hang it off the hud_container group.

var _torch: TorchHUD
var _keys: KeysHUD
var _points: PointsHUD

func _init() -> void:
	_torch = TorchHUD.new()
	_keys = KeysHUD.new()
	_points = PointsHUD.new()

func _ready() -> void:
	name = "StatusHUD"
	# Full rect on purpose: the three children place themselves at absolute coordinates inside
	# the bottom strip, see their POSITION consts.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_torch)
	add_child(_keys)
	add_child(_points)
