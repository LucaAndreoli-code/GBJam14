extends Control

var _parent_payload: Dictionary
var _input_enabled: bool = false

func _ready() -> void:
	SignalBus.visibility_shader_toggled.emit(false)
	SceneManager.get_main_scene().toggle_bottom_bar(false)
	await get_tree().create_timer(1.0).timeout
	_input_enabled = true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("btn_a"):
		SceneManager.go_to(_parent_payload.get("next_scene_path"), _parent_payload)
		return

func on_scene_entered(payload: Dictionary) -> void:
	_parent_payload = payload
