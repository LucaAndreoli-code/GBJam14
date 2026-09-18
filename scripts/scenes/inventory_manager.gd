extends Node2D

const FRAME_NOT_SELECTED: Rect2i = Rect2i(0, 0, 24, 24)
const FRAME_SELECTED: Rect2i = Rect2i(24, 0, 24, 24)

@onready var _grid: GridContainer = $Container/GridContainer/Grid
@onready var _info_title: GBLabel = $Container/InfoTitleBar/TreasureTitle
@onready var _info_label: Label = $Container/Info/TreasureDesc

@export var grid_size: Vector2i = Vector2i(4, 3)
@export var cell_textures: Texture2D
@export var treasures: Array[TreasureInfo]

var _parent_payload: Dictionary
var _cell_selected: int = 0
var _treasures_count: Dictionary[int, int] = {
	#10: 1,
	#12: 2,
}

func _ready() -> void:
	SceneManager.get_main_scene().toggle_bottom_bar(false)
	if _grid:
		_init_grid()
		_refresh_grid()
		_cell_selected = 0
		_update_info()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("btn_b"):
		_exit()
		return
	var dx := 0
	var dy := 0
	if event.is_action_pressed("dpad_right"):
		dx = 1
	elif event.is_action_pressed("dpad_left"):
		dx = -1
	elif event.is_action_pressed("dpad_down"):
		dy = 1
	elif event.is_action_pressed("dpad_up"):
		dy = -1
	if dx == 0 and dy == 0:
		return
	get_viewport().set_input_as_handled()
	_move_grid_selection(dx, dy)

func on_scene_entered(payload: Dictionary) -> void:
	_parent_payload = payload

func _init_grid() -> void:
	_grid.columns = grid_size.x
	for child in _grid.get_children():
		child.queue_free()
	for i in grid_size.x * grid_size.y:
		var treasure := _get_treasure_by_order(_order_by_index(i))
		if treasure:
			_grid.add_child(_make_grid_cell(treasure))

func _get_treasure_by_order(order: int) -> TreasureInfo:
	var filtered := treasures.filter(func(t): return t.order == order)
	if filtered.size() == 1:
		return filtered[0]
	return null

func _make_grid_cell(treasure: TreasureInfo) -> Control:
	var cell := TextureRect.new()
	var cell_atlas := AtlasTexture.new()
	cell_atlas.atlas = cell_textures
	cell_atlas.region = FRAME_NOT_SELECTED
	cell.texture = cell_atlas
	cell.stretch_mode = TextureRect.STRETCH_SCALE
	cell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sub_cell := TextureRect.new()
	sub_cell.position = Vector2.ZERO
	sub_cell.texture = treasure.inventory_texture
	sub_cell.stretch_mode = TextureRect.STRETCH_SCALE
	sub_cell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cell.add_child(sub_cell)
	return cell

func _move_grid_selection(dx: int, dy: int) -> void:
	var count := _grid.get_child_count()
	if count == 0:
		return
	var x := _cell_selected % grid_size.x
	var y := _cell_selected / grid_size.x
	x = clampi(x + dx, 0, grid_size.x - 1)
	y = clampi(y + dy, 0, grid_size.y - 1)
	var index := y * grid_size.x + x
	if index >= count or index == _cell_selected:
		return
	_cell_selected = index
	_refresh_grid()
	_update_info()

func _refresh_grid() -> void:
	for i in _grid.get_child_count():
		var cell := _grid.get_child(i) as TextureRect
		(cell.texture as AtlasTexture).region = FRAME_SELECTED if _cell_selected == i else FRAME_NOT_SELECTED
		if not _treasures_count.has(_order_by_index(i)):
			var subcell := cell.get_child(0) as TextureRect
			subcell.self_modulate = Color.from_rgba8(85, 85, 85)

func _update_info() -> void:
	var treasure_order := _order_by_index(_cell_selected)
	if not _treasures_count.has(treasure_order):
		_info_title.print_text("???")
		_info_label.text = "It seems like you haven't found it yet..."
	else:
		var treasure := _get_treasure_by_order(treasure_order)
		if treasure:
			var count := _treasures_count[treasure_order]
			if count > 1:
				_info_title.print_text("%s (x%d)" % [treasure.name, count])
			else:
				_info_title.print_text("%s" % treasure.name)
			_info_label.text = treasure.description

func _order_by_index(index: int) -> int:
	return index + 1

func _exit() -> void:
	SceneManager.go_to(_parent_payload.get("scene_path"), _parent_payload)
