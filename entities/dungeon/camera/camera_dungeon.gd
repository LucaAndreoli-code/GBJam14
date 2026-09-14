extends Camera2D

enum MovementDirection {
	TOP,
	BOTTOM,
	LEFT,
	RIGHT
}

const SCREEN_SIZE: Vector2 = Vector2(160.0, 144.0)
const ROOM_SIZE: Vector2 = Vector2(160.0, 112.0)
const ROOM_OFFSET: Vector2 = Vector2(0.0, 16.0)
const PLAYER_SIZE: float = 16.0
const PLAYER_AUTOMOVE: float = 4.0
const PLAYER_STEP: Dictionary[MovementDirection, Vector2] = {
	MovementDirection.TOP: Vector2(0, -1),
	MovementDirection.BOTTOM: Vector2(0, 1),
	MovementDirection.LEFT: Vector2(-1, 0),
	MovementDirection.RIGHT: Vector2(1, 0),
}

@export var player: PlayerDungeonController
@export var movement_duration: float = 0.5

var _is_traslating: bool = false
var _last_direction: MovementDirection

func _ready() -> void:
	assert(player != null, "Camera is missing the player reference!")

func _process(_delta: float) -> void:
	var camera_rect := _get_camera_rect()
	if not _is_traslating:
		if player.global_position.y <= camera_rect.position.y:
			_move(MovementDirection.TOP)
		elif player.global_position.y >= camera_rect.end.y:
			_move(MovementDirection.BOTTOM)
		elif player.global_position.x <= camera_rect.position.x:
			_move(MovementDirection.LEFT)
		elif player.global_position.x >= camera_rect.end.x:
			_move(MovementDirection.RIGHT)

func _move(direction: MovementDirection) -> void:
	_is_traslating = true
	_last_direction = direction
	GameState.set_input_enabled(false)
	var target_pos := _get_camera_next_position(direction, _get_camera_rect())
	target_pos -= ROOM_OFFSET
	var tween := create_tween()
	tween.tween_property(self, "global_position", target_pos, movement_duration)
	tween.finished.connect(_on_move_end)

func _on_move_end() -> void:
	player.global_position += PLAYER_STEP[_last_direction] * PLAYER_AUTOMOVE
	_is_traslating = false
	GameState.set_input_enabled(true)

func _get_camera_next_position(direction: MovementDirection, camera_rect: Rect2) -> Vector2:
	match direction:
		MovementDirection.TOP:
			return Vector2(camera_rect.position.x, camera_rect.position.y - camera_rect.size.y)
		MovementDirection.BOTTOM:
			return Vector2(camera_rect.position.x, camera_rect.end.y)
		MovementDirection.LEFT:
			return Vector2(camera_rect.position.x - camera_rect.size.x, camera_rect.position.y)
		MovementDirection.RIGHT:
			return Vector2(camera_rect.end.x, camera_rect.position.y)
	return Vector2.ZERO

func _get_camera_rect() -> Rect2:
	return Rect2(global_position + ROOM_OFFSET, ROOM_SIZE)
