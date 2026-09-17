class_name Treasure
extends Area2D

## A golden treasure buried under the terrain.
## A buried treasure is drawn under the field, so the dirt still covering it hides it:
## digging uncovers it a slice at a time, and it only becomes collectible once every cell
## of its footprint is gone.

## Emits when the player walks into a revealed treasure, right before it frees itself
signal collected(treasure: Treasure)

## Footprint of each kind, in field cells. The artwork is authored to match: a cell is 8px
## and every minigame_texture under entities/treasures is 8x8, 8x16 or 16x16.
const SIZES := {
	TreasureInfo.Kind.SMALL: Vector2i(1, 1),
	TreasureInfo.Kind.MEDIUM: Vector2i(1, 2),
	TreasureInfo.Kind.BIG: Vector2i(2, 2),
}

## Seconds each kind adds to the run timer. Unused until the timer lands.
const TIME_BONUS := {
	TreasureInfo.Kind.SMALL: 1.0,
	TreasureInfo.Kind.MEDIUM: 1.5,
	TreasureInfo.Kind.BIG: 3.0,
}

## Seconds of one on or off step of a sonar blink
const FLASH_STEP := 0.15

## The artwork sits under DigField, which is at z 0: every dirt tile in the set is fully
## opaque, so the terrain masks it by itself. No per pixel mask, no region, just draw order.
const BURIED_Z: int = -1
## The silhouette sits above the field instead: the sonar has to read through dirt, or the
## scan would point at nothing. Two nodes and not one, because the artwork has to keep
## showing through the holes already dug while the silhouette blinks over the rest.
const FLASH_Z: int = 1
const SILHOUETTE_SHADER: Shader = preload("res://shaders/treasure_silhouette.gdshader")

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _sprite: Sprite2D = $Sprite
@onready var _silhouette: Sprite2D = $Silhouette

var _info: TreasureInfo
var _cells: Array[Vector2i] = []
var _revealed: bool = false
var _flash_left: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# The two layers straddle the field: artwork below, silhouette above. Set up once
	# here, so a blink only has to toggle a visibility flag.
	_sprite.z_index = BURIED_Z
	var silhouette_material := ShaderMaterial.new()
	silhouette_material.shader = SILHOUETTE_SHADER
	_silhouette.material = silhouette_material
	_silhouette.z_index = FLASH_Z
	_silhouette.visible = false
	# Only the sonar blink needs a frame tick, so stay idle until it asks for one
	set_process(false)

## Places the treasure over the given cells and buries it.
## `info` carries everything the run needs to know about it: the kind decides the footprint,
## the minigame texture is the artwork, and the whole resource travels back to the dungeon
## once the treasure is picked up.
## `origin` is the top-left corner of the footprint, in this node's parent space.
func setup(info: TreasureInfo, cells: Array[Vector2i], origin: Vector2, cell_size: Vector2i) -> void:
	_info = info
	_cells = cells
	var footprint := _footprint()
	var pixel_size := Vector2(footprint * cell_size)
	position = origin + pixel_size * 0.5
	var rect := RectangleShape2D.new()
	rect.size = pixel_size
	_shape.shape = rect
	_sprite.texture = info.minigame_texture
	# A rotated footprint is the one case where the kind does not tell you the on screen
	# orientation, see footprint_for(): the upright art has to lie down to cover the cells.
	_sprite.rotation = PI * 0.5 if footprint != SIZES[info.kind] else 0.0
	_silhouette.texture = _sprite.texture
	_silhouette.rotation = _sprite.rotation
	# kind is hand authored in the .tres while the artwork comes from the sheet: a mismatch
	# would stretch the collider past the sprite, so say it out loud instead of drawing it.
	var art_cells := Vector2i(info.minigame_texture.get_size()) / cell_size
	if art_cells != SIZES[info.kind]:
		push_warning("%s: kind wants %v cells, art covers %v" % [info.name, SIZES[info.kind], art_cells])
	_bury()

## Footprint in cells, with the 1x2 medium randomly laid on its side so horizontal and
## vertical tunnels have the same chance of running into it.
static func footprint_for(kind: TreasureInfo.Kind, rng: RandomNumberGenerator) -> Vector2i:
	var size: Vector2i = SIZES[kind]
	if size.x != size.y and rng.randi() % 2 == 1:
		return Vector2i(size.y, size.x)
	return size

## The resource this treasure was spawned from, for whoever collects it
func get_info() -> TreasureInfo:
	return _info

func get_kind() -> TreasureInfo.Kind:
	return _info.kind

func get_cells() -> Array[Vector2i]:
	return _cells

func get_time_bonus() -> float:
	return TIME_BONUS[_info.kind]

func is_revealed() -> bool:
	return _revealed

## Makes the treasure collectible, now that the last cell over it has been dug out.
## Nothing to do about visibility: the sprite has been drawn all along, the dirt was
## simply covering it.
func reveal() -> void:
	if _revealed:
		return
	_revealed = true
	monitoring = true

## Blinks the treasure for `duration` seconds so the sonar can point at it.
## Deliberately leaves `monitoring` alone: the scan shows where a treasure is, it does not
## let the player pick it up through terrain that is still solid.
func flash(duration: float) -> void:
	if _revealed:
		return
	_flash_left = duration
	set_process(true)

func _process(delta: float) -> void:
	_flash_left -= delta
	# _revealed can flip mid blink, when the player digs the treasure out while it shows
	if _flash_left <= 0.0 or _revealed:
		_end_flash()
		return
	_silhouette.visible = int(_flash_left / FLASH_STEP) % 2 == 0

func _end_flash() -> void:
	_flash_left = 0.0
	set_process(false)
	# Only the extra layer goes away. Whatever had been dug out stays uncovered
	# underneath, exactly as it was before the ping.
	_silhouette.visible = false

func _bury() -> void:
	_revealed = false
	# Visible from the start: the dirt above is the mask. Carving a single cell uncovers
	# that slice of the sprite and nothing more, instead of popping the whole chest up.
	visible = true
	_silhouette.visible = false
	# The one that matters: without it the player would collect treasures by walking
	# over terrain that has not been dug out yet.
	monitoring = false

func _footprint() -> Vector2i:
	# Derived from the cells the spawner reserved, so a rotated medium stays correct
	if _cells.is_empty():
		return SIZES[_info.kind]
	var used := Rect2i(_cells[0], Vector2i.ONE)
	for cell in _cells:
		used = used.expand(cell).expand(cell + Vector2i.ONE)
	return used.size

func _on_body_entered(body: Node2D) -> void:
	if body is not DigPlayer:
		return
	collected.emit(self)
	queue_free()
