class_name GBTextBox
extends Node2D

# GameBoy dialogue box: a background panel plus a GBLabel, shown one line at a
# time. It sits hidden in a scene and waits for an interaction to open it.

# Fired when the box closes, whether the last line was advanced past or the
# dialogue was cancelled. Whoever opened the box listens here to take control back.
signal dialogue_finished()

@onready var _label: GBLabel = $GBLabel

var _lines: PackedStringArray = []
var _index := 0

func _ready() -> void:
	# Authored visible so the box can be placed in the editor; only an
	# interaction is allowed to put it on screen at runtime.
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	# Input callbacks ignore visibility, so a hidden box would otherwise eat
	# every btn_a in the game.
	if not visible:
		return
	if event.is_action_pressed("btn_a"):
		advance()
		# Keeps the press that talks to the box from also reaching gameplay.
		get_viewport().set_input_as_handled()

func show_dialogue(lines: PackedStringArray) -> void:
	# Nothing to say is not an error, it just means no box.
	if lines.is_empty():
		return
	_lines = lines
	_index = 0
	visible = true
	_label.print_text(_lines[0])

func advance() -> void:
	if not visible:
		return
	# Classic GameBoy: the first press fills the line in, the next one moves on.
	if _label.is_printing():
		_label.skip()
		return
	_index += 1
	if _index >= _lines.size():
		close()
		return
	_label.print_text(_lines[_index])

func close() -> void:
	if not visible:
		return
	visible = false
	_lines = []
	_index = 0
	_label.clear_text()
	dialogue_finished.emit()

func is_open() -> bool:
	return visible
