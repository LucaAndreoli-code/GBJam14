class_name PlayerDungeonAnimator
extends RefCounted

enum AnimState { 
	IDLE,
	WALK
}

var _anim_player: AnimationPlayer
var _anim_state: AnimState = AnimState.IDLE

var _has_torch: bool = true
var _direction: Vector2i = Vector2i.DOWN

func _init(anim_player: AnimationPlayer) -> void:
	_anim_player = anim_player

func update(is_walking: bool, has_torch: bool, direction: Vector2i) -> void:
	_anim_state = AnimState.IDLE
	if is_walking:
		_anim_state = AnimState.WALK
	_has_torch = has_torch
	_direction = direction

func animate() -> void:
	_anim_player.play(_get_anim_name())

func _get_anim_name() -> String:
	var prefix := "idle"
	if _anim_state == AnimState.WALK:
		prefix = "walk"
	var suffix := "down"
	match _direction:
		Vector2i.UP: suffix = "up"
		Vector2i.DOWN: suffix = "down"
		Vector2i.LEFT: suffix = "left"
		Vector2i.RIGHT: suffix = "right"
	if not _has_torch:
		suffix += "_no_torch"
	return "%s_%s" % [prefix, suffix]
