extends Control

@export var initial_scene: PackedScene

@onready var _game_viewport: SubViewport = $PaletteContainer/Screen

func _ready() -> void:
	SceneManager.register_viewport(_game_viewport)
	if initial_scene == null:
		push_warning("No initial scene set on Main!")
	else:
		SceneManager.go_to(initial_scene.resource_path, {})
