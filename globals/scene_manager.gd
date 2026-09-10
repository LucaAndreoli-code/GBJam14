extends Node

## Emits when a scene change is requested
signal scene_change_started(path: String)
## Emits when a scene change is completed
signal scene_changed(scene: Node)

const NEW_SCENE_PAYLOAD_METHOD_SIGNATURE = "on_scene_entered"

var _current_viewport: SubViewport
var _current_path: String
var _current_scene: Node
var _is_swapping: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Returns the current main viewport
func get_current_viewport() -> SubViewport:
	return _current_viewport

## Returns the current visible scene
func get_current_scene() -> Node:
	return _current_scene

## Registers a viewport as the main viewport
func register_viewport(viewport: SubViewport) -> void:
	if _current_viewport != null:
		push_warning("Registering a new viewport \"%s\" even if there's already one \"%s\"" % [viewport.get_path(), _current_viewport.get_path()])
		return
	_current_viewport = viewport

## Switches from the current scene to a new scene
func go_to(path: String, payload: Dictionary = {}) -> void:
	# If statement to avoid bugs caused by double calls in the same frame
	if _is_swapping:
		return
	if _current_viewport == null:
		push_error("Trying to change scene without a viewport specified!")
		return
	_is_swapping = true
	get_tree().paused = true
	scene_change_started.emit(path)
	_do_swap.call_deferred(path, payload)	

## Reloads the current scene
func reload(payload: Dictionary = {}) -> void:
	if _current_scene == null or _current_path.is_empty():
		push_warning("Asked for a scene reload when there's no scene!")
		return
	go_to(_current_path, payload)

func _do_swap(path: String, payload: Dictionary) -> void:
	var scene_pack := load(path)
	if scene_pack == null or scene_pack is not PackedScene:
		push_error("Unable to load scene at \"%s\": null or unexpected format" % path)
		get_tree().paused = GameState.is_paused()
		_is_swapping = false
		return
	await Palette.fade_out()
	if _current_scene != null:
		_current_viewport.remove_child(_current_scene)
		_current_scene.queue_free()
	var scene := (scene_pack as PackedScene).instantiate()
	_current_viewport.add_child(scene)
	_current_scene = scene
	_current_path = path
	if _current_scene.has_method(NEW_SCENE_PAYLOAD_METHOD_SIGNATURE):
		_current_scene.call(NEW_SCENE_PAYLOAD_METHOD_SIGNATURE, payload)
	await Palette.fade_in()
	get_tree().paused = GameState.is_paused()
	_is_swapping = false
	scene_changed.emit(_current_scene)
