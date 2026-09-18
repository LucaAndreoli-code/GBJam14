class_name InteractHUD
extends Control

const UI_BUTTON_SHEET: Texture2D = preload("res://assets/sprites/ui/player_interact_a_button.png")
const SIZE: Vector2 = Vector2(8.0, 8.0)
const PLAYER_SIZE: Vector2 = Vector2(16.0, 16.0)
const OFFSET: Vector2 = Vector2(5.0, 18.0)
const BLINK_INTERVAL: float = 0.5

var _player: PlayerDungeonController
var _rect: TextureRect
var _blink_time: float = 0.0

func _init(player: PlayerDungeonController) -> void:
	name = "InteractHUD"
	size = SIZE
	_player = player
	visible = false

func _ready() -> void:
	_build_ui()

func _process(delta: float) -> void:
	# Lives outside the game scene, so the pause has to be read rather than inherited
	if GameState.is_paused():
		return
	var screen_pos := _player.get_global_transform_with_canvas().origin
	var new_pos := (screen_pos - OFFSET).round()
	if global_position != new_pos:
		global_position = new_pos
	if not visible:
		return
	_blink_time += delta
	_rect.visible = fmod(_blink_time, BLINK_INTERVAL * 2.0) < BLINK_INTERVAL

func toggle(value: bool):
	if visible == value:
		return
	visible = value
	if value:
		_blink_time = 0.0
		_rect.visible = true

func _build_ui() -> void:
	_rect = TextureRect.new()
	_rect.texture = UI_BUTTON_SHEET
	add_child(_rect)
