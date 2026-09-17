class_name TreasureInfo
extends Resource

## Footprint class of a treasure, in dig field cells: SMALL is 1x1, MEDIUM 1x2, BIG 2x2.
## Declared here and not on Treasure so the resource stays pure data - the inventory loads
## TreasureInfo too, and it must not drag the digging entity, its shader and its textures
## in with it.
enum Kind { SMALL, MEDIUM, BIG }

@export var order: int
@export var kind: Kind
@export var name: String
@export var description: String
@export var minigame_texture: Texture2D
@export var inventory_texture: Texture2D
