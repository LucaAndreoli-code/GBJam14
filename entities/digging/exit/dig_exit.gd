class_name DigExit
extends Area2D

## The way out of the pit, sitting on the start pocket.
## The player spawns inside it, so it only counts as a return once the player has actually
## left it: without that, the run would end on the very first frame.

## Emits when the player comes back into the pocket, and then the exit stops sampling:
## the run is over unless rearm() puts it back to work.
signal player_returned()

var _player: DigPlayer
var _rect: Rect2
var _armed: bool = false
# The player spawns on top of the exit, see the scene
var _was_inside: bool = true

func _ready() -> void:
	# No body_entered / body_exited: the pause takes the scene out of the physics space and gets
	# the whole pair replayed on resume, ending the run with the player standing still. The
	# overlap is sampled instead, and only while the scene runs.
	monitoring = false
	monitorable = false
	var shape := $CollisionShape2D as CollisionShape2D
	var shape_size := (shape.shape as RectangleShape2D).size
	_rect = Rect2(global_position + shape.position - shape_size * 0.5, shape_size)

func set_player(player: DigPlayer) -> void:
	_player = player

## Puts the exit back to work after the player refused to leave. The player is standing
## inside the pocket right now, so the arming flag goes back down with it: it takes a walk
## out into the field, and a second walk in, before the return is reported again.
func rearm() -> void:
	_armed = false
	# The player is inside as of the frame that emitted, so the sampler has to agree or the
	# very next frame would read a fresh entry and fire straight away.
	_was_inside = true
	set_physics_process(true)

func _physics_process(_delta: float) -> void:
	# Set one frame late by the minigame: children are readied before their parent
	if _player == null:
		return
	var inside := _rect.intersects(_player.get_body_rect())
	if inside == _was_inside:
		return
	_was_inside = inside
	# Digging down is what arms the exit
	if not inside:
		_armed = true
		return
	if not _armed:
		return
	player_returned.emit()
	# Nothing left to sample until someone asks for more, see rearm()
	set_physics_process(false)
