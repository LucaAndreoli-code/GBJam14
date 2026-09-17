class_name DigExit
extends Area2D

## The way out of the pit, sitting on the start pocket.
## The player spawns inside it, so it only counts as a return once the player has actually
## left it: without that, the run would end on the very first frame.

## Emits the first time the player comes back, and never again
signal player_returned()

var _armed: bool = false
var _used: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

# Digging down is what arms the exit
func _on_body_exited(body: Node2D) -> void:
	if body is not DigPlayer:
		return
	_armed = true

func _on_body_entered(body: Node2D) -> void:
	if _used or not _armed:
		return
	if body is not DigPlayer:
		return
	_used = true
	player_returned.emit()
