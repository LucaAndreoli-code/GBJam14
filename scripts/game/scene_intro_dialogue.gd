class_name SceneIntroDialogue
extends Node2D

## One entry per text box page, authored in the level scene.
@export var lines: PackedStringArray = []
## The "already seen" key. Left empty, the containing scene's scene_file_path is used, so two
## copies of the same level share one intro. Set it to hold more than one intro in a scene, or
## to share a single intro across different scenes.
@export var intro_key: String = ""

func _ready() -> void:
	if lines.is_empty():
		return
	# scene_changed lands after Palette.fade_in(), see SceneManager._do_swap(). This _ready() runs
	# while the scene is being added to the viewport, so the connection is in place well before.
	SceneManager.scene_changed.connect(_on_scene_changed)

func _on_scene_changed(scene: Node) -> void:
	if scene != owner:
		return
	SceneManager.scene_changed.disconnect(_on_scene_changed)
	var key := intro_key if not intro_key.is_empty() else scene.scene_file_path
	if GameState.is_scene_intro_seen(key):
		return
	# Marked before the request goes out: the intro is spent even if the scene mounts no text box.
	GameState.mark_scene_intro_seen(key)
	SignalBus.dialogue_requested.emit(lines)
