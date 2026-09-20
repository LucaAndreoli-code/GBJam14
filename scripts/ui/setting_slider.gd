class_name SettingSlider
extends Control

const ICONS_TEXTURE: Texture2D = preload("res://assets/sprites/ui/settings_slider_ui.png")
const EMPTY_CELL_REGION: Rect2 = Rect2(0.0, 0.0, 8.0, 8.0)
const FULL_CELL_REGION: Rect2 = Rect2(8.0, 0.0, 8.0, 8.0)

@onready var _empty_cell: TextureRect = $Templates/EmptyCell
@onready var _full_cell: TextureRect = $Templates/FullCell

@export var min_value: float = 0.0
@export var max_value: float = 999.0
@export var initial_value: float = 0.0
@export var steps_count: int = 5

var _step_index: int = 0
var _cells: Array[TextureRect] = []

func _ready() -> void:
	set_value(initial_value)
	_build_ui()

func get_value() -> float:
	return min_value + (max_value - min_value) * _step_index / steps_count

func set_value(value: float) -> void:
	var temp := inverse_lerp(min_value, max_value, value)
	_step_index = clampi(roundi(temp * steps_count), 0, steps_count)
	_refresh_ui()

func increase_value(steps: int = 1) -> void:
	var step_increase_value: float = max_value / steps_count
	var value := get_value()
	set_value(value + (step_increase_value * steps))

func decrease_value(steps: int = 1) -> void:
	var step_increase_value: float = max_value / steps_count
	var value := get_value()
	set_value(value - (step_increase_value * steps))

func _build_ui() -> void:
	for c in _cells:
		c.queue_free()
	_cells.clear()
	size = Vector2(8.0 * steps_count, 8.0)
	for i in range(1, steps_count + 1):
		var cell = _empty_cell.duplicate()
		cell.visible = true
		_cells.append(cell)
		add_child(cell)

func _refresh_ui() -> void:
	for i in range(_cells.size()):
		var cell := _cells[i]
		var atlas := AtlasTexture.new()
		atlas.atlas = ICONS_TEXTURE
		atlas.region = FULL_CELL_REGION if i < _step_index else EMPTY_CELL_REGION 
		cell.texture = atlas
