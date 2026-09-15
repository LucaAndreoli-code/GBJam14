class_name Treasure
extends Area2D

## A golden treasure buried under the terrain.
## Buried treasures are invisible and not collectible; digging their cells reveals them.

## Emits when the player walks into a revealed treasure, right before it frees itself
signal collected(treasure: Treasure)

enum Kind { SMALL, MEDIUM, BIG }

## Footprint of each kind, in field cells
const SIZES := {
	Kind.SMALL: Vector2i(1, 1),
	Kind.MEDIUM: Vector2i(1, 2),
	Kind.BIG: Vector2i(2, 2),
}

## Seconds each kind adds to the run timer. Unused until the timer lands.
const TIME_BONUS := {
	Kind.SMALL: 1.0,
	Kind.MEDIUM: 1.5,
	Kind.BIG: 3.0,
}

## Seconds of one on or off step of a sonar blink
const FLASH_STEP := 0.2

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _placeholder: ColorRect = $Placeholder

var _kind: Kind = Kind.SMALL
var _cells: Array[Vector2i] = []
var _revealed: bool = false
var _flash_left: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Only the sonar blink needs a frame tick, so stay idle until it asks for one
	set_process(false)

## Places the treasure over the given cells and buries it.
## `origin` is the top-left corner of the footprint, in this node's parent space.
func setup(kind: Kind, cells: Array[Vector2i], origin: Vector2, cell_size: Vector2i) -> void:
	_kind = kind
	_cells = cells
	var pixel_size := Vector2(_footprint(kind) * cell_size)
	position = origin + pixel_size * 0.5
	var rect := RectangleShape2D.new()
	rect.size = pixel_size
	_shape.shape = rect
	_placeholder.position = -pixel_size * 0.5
	_placeholder.size = pixel_size
	_bury()

## Footprint in cells, with the 1x2 medium randomly laid on its side so horizontal and
## vertical tunnels have the same chance of running into it.
static func footprint_for(kind: Kind, rng: RandomNumberGenerator) -> Vector2i:
	var size: Vector2i = SIZES[kind]
	if size.x != size.y and rng.randi() % 2 == 1:
		return Vector2i(size.y, size.x)
	return size

func get_kind() -> Kind:
	return _kind

func get_cells() -> Array[Vector2i]:
	return _cells

func get_time_bonus() -> float:
	return TIME_BONUS[_kind]

func is_revealed() -> bool:
	return _revealed

## Brings the treasure into view and makes it collectible
func reveal() -> void:
	if _revealed:
		return
	_revealed = true
	visible = true
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
	visible = int(_flash_left / FLASH_STEP) % 2 == 0

func _end_flash() -> void:
	_flash_left = 0.0
	set_process(false)
	# A treasure uncovered during the blink stays up; one still buried goes back to hidden
	visible = _revealed

func _bury() -> void:
	_revealed = false
	visible = false
	# The one that matters: without it the player would collect treasures by walking
	# over terrain that has not been dug out yet.
	monitoring = false

func _footprint(kind: Kind) -> Vector2i:
	# Derived from the cells the spawner reserved, so a rotated medium stays correct
	if _cells.is_empty():
		return SIZES[kind]
	var used := Rect2i(_cells[0], Vector2i.ONE)
	for cell in _cells:
		used = used.expand(cell).expand(cell + Vector2i.ONE)
	return used.size

func _on_body_entered(body: Node2D) -> void:
	if body is not DigPlayer:
		return
	collected.emit(self)
	queue_free()
