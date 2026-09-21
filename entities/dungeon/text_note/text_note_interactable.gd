extends DungeonInteractable

@export var note: TextNoteInfo

@export var is_pickable: bool = true

func _ready() -> void:
	if not note:
		push_warning("Note info not set on note %s" % name)
	elif GameState.is_note_taken(get_level_key(), note.id):
		queue_free()
		return

func can_interact(_player: PlayerDungeonController) -> bool:
	return is_pickable

func interact(_player: PlayerDungeonController) -> void:
	if note:
		GameState.add_taken_note(get_level_key(), note.id)
	_player.read_note(note.lines)
	queue_free()
