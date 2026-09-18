class_name MinimapCell
extends Control

enum Type {
	NONE,
	PLAYER,
	TORCH
}

@export var type: Type = Type.NONE
@export var cell_size: Vector2i = Vector2i(9, 9)
@export var cell_spacing: Vector2i = Vector2i(2, 2)

@onready var _room: ColorRect = $Room
@onready var _open_right: ColorRect = $OpenRight
@onready var _door_right: ColorRect = $DoorRight
@onready var _open_down: ColorRect = $OpenDown
@onready var _door_down: ColorRect = $DoorDown
@onready var _torch: ColorRect = $Torch
@onready var _player: ColorRect = $Player

func _ready():
	if type == Type.NONE:
		return
	_player.visible = false
	_torch.visible = false
	_open_right.visible = false
	_door_right.visible = false
	_open_down.visible = false
	_door_down.visible = false
	match type:
		Type.PLAYER: _player.visible = true
		Type.TORCH: _torch.visible = true
	scale(cell_size, cell_spacing)

func setup(
	links: int, \
	right_visible: bool, \
	down_visible: bool, \
	has_player: bool, \
	has_torch: bool, \
	new_size: Vector2i = Vector2i.ZERO,
	new_spacing: Vector2i = Vector2i.ONE) -> void:
	_open_right.visible = right_visible and bool(links & MinimapUtils.Link.OPEN_RIGHT)
	_door_right.visible = right_visible and bool(links & MinimapUtils.Link.DOOR_RIGHT) and not _open_right.visible
	_open_down.visible = down_visible and bool(links & MinimapUtils.Link.OPEN_DOWN)
	_door_down.visible = down_visible and bool(links & MinimapUtils.Link.DOOR_DOWN) and not _open_down.visible
	_torch.visible = has_torch
	_player.visible = has_player
	scale(new_size, new_spacing)

func scale(new_size: Vector2i, new_spacing: Vector2i) -> void:
	if new_size == Vector2i.ZERO:
		new_size = cell_size
	var inner_size := new_size - new_spacing
	var offset: Vector2i = (inner_size / 4.0).round()
	var content_size := inner_size - offset * 2
	_room.size = inner_size
	if _door_right.visible:
		_door_right.position = Vector2(inner_size.x, offset.y)
		_door_right.size = Vector2(new_spacing.x, inner_size.y - offset.y * 2)
	if _open_right.visible:
		_open_right.position = Vector2(inner_size.x, 0.0)
		_open_right.size = Vector2(new_spacing.x, inner_size.y)
	if _door_down.visible:
		_door_down.position = Vector2(offset.x, inner_size.y)
		_door_down.size = Vector2(inner_size.x - offset.x * 2, new_spacing.y)
	if _open_down.visible:
		_open_down.position = Vector2(0.0, inner_size.y)
		_open_down.size = Vector2(inner_size.x, new_spacing.y)
	if _player.visible:
		_player.position = offset
		_player.size = content_size
	if _torch.visible:
		_torch.position = offset
		_torch.size = content_size
