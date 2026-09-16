extends Node2D

var _parent_payload: Dictionary

func _ready() -> void:
	Palette.switch_to_palette("brown_shades")
	SceneManager.get_main_scene().toggle_bottom_bar(false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("btn_b"):
		_exit()
		return

func on_scene_entered(payload: Dictionary) -> void:
	_parent_payload = payload

func _exit() -> void:
	SceneManager.go_to(_parent_payload.get("scene_path"), _parent_payload)
