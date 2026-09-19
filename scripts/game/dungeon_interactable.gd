@abstract
class_name DungeonInteractable
extends Area2D

@abstract func interact(player: PlayerDungeonController) -> void

func can_interact(_player: PlayerDungeonController) -> bool:
	return true

## Scopes world state to the level this node was authored in: owner is the dungeon root, whose
## scene_file_path is what SceneManager reloads on every return from a digging run.
func get_level_key() -> String:
	return owner.scene_file_path if owner else ""
