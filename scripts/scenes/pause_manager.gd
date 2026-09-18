extends Node2D

## Owns the whole pause toggle: a scene gets pause simply by mounting this menu, and a scene that
## does not mount it - the map, the inventory - stays unpausable. The menu needs no process_mode of
## its own: GameState freezes the game scene alone, see SceneManager._apply_pause().

func _ready() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed("btn_b"):
			_close()
	elif event.is_action_pressed("btn_start"):
		_open()

func _open() -> void:
	GameState.set_paused(true)
	visible = true

func _close() -> void:
	GameState.set_paused(false)
	visible = false
