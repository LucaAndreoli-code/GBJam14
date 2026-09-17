extends Node2D

#func _ready() -> void:
	#SceneManager.get_main_scene().toggle_bottom_bar(false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("btn_b"):
		_exit()
		return

func _exit() -> void:
	GameState.set_paused(false)
	visible = false
