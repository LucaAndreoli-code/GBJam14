extends DungeonInteractable

## One entry per text box page, authored in the level scene.
@export var lines: PackedStringArray = []

## A sign with nothing written on it stays silent, and the A prompt goes off with it,
## see PlayerDungeonController._toggle_interact_hud().
func can_interact(_player: PlayerDungeonController) -> bool:
	return not lines.is_empty()

func interact(_player: PlayerDungeonController) -> void:
	SignalBus.dialogue_requested.emit(lines)
