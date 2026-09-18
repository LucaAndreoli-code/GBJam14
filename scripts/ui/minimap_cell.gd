class_name MinimapCell
extends Control

enum Type {
	NONE,
	PLAYER,
	TORCH
}

@export var type: Type = Type.NONE

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
	_open_right.visible = false
	_door_right.visible = false
	_open_down.visible = false
	_door_down.visible = false
	match type:
		Type.PLAYER: _player.visible = true
		Type.TORCH: _torch.visible = true
	_room.size = Vector2(11.0, 11.0)
	_player.position = Vector2(2.0, 2.0)
	_player.size = Vector2(7.0, 7.0)
	_torch.position = Vector2(2.0, 2.0)
	_torch.size = Vector2(7.0, 7.0)

func setup(links: int, right_visible: bool, down_visible: bool, has_torch: bool) -> void:
	_open_right.visible = right_visible and bool(links & MinimapUtils.Link.OPEN_RIGHT)
	_door_right.visible = right_visible and bool(links & MinimapUtils.Link.DOOR_RIGHT) and not _open_right.visible
	_open_down.visible = down_visible and bool(links & MinimapUtils.Link.OPEN_DOWN)
	_door_down.visible = down_visible and bool(links & MinimapUtils.Link.DOOR_DOWN) and not _open_down.visible
	_torch.visible = has_torch
	_player.visible = false
