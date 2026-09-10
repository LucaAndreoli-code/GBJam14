extends Node2D

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("btn_b"):
		SceneManager.go_to("res://scenes/demo/scene_manager/scene_manager_2.tscn")
