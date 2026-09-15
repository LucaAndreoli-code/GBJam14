@abstract
class_name Interactable
extends Area2D

@abstract func interact(player: PlayerDungeonController) -> void

func can_interact(_player: PlayerDungeonController) -> bool:
	return true
