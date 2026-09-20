class_name GBTextBox
extends Node2D

# GameBoy dialogue box: a background panel plus a GBLabel, shown one line at a
# time. It sits hidden in a scene and waits for an interaction to open it.
#
# Two ways to open it: show_dialogue() for plain lines, show_confirm() for a question
# that ends on a YES / NO row.

# Fired when the box closes, whether the last line was advanced past or the
# dialogue was cancelled. Whoever opened the box listens here to take control back.
signal dialogue_finished()
# Fired when a confirm box is answered: true on YES, false on NO. A btn_b cancel answers
# NO, and a close() from the outside answers whatever the caret was left on. It always
# comes right after dialogue_finished, which only reports that the box closed.
signal choice_made(accepted: bool)

enum Mode { LINEAR, CONFIRM }

# Where the caret sits for either option, in the box's own pixels: 7px to the left of
# the word it points at, see YesLabel and NoLabel in the scene. The row itself never
# moves, only the caret does, the same way the inventory only swaps which cell is framed.
const CURSOR_YES_X: float = 82.0
const CURSOR_NO_X: float = 117.0

# The panel's free interior runs y 5..46, and the YES / NO row takes y 34..47, see the
# Choice node. A plain message gets the whole height, a question gets what is left above
# the options. The label works out how many lines that is from its own font.
const TEXT_TOP: float = 6.0
# Same rhythm as the A prompt over the player's head, see InteractHUD.
const BLINK_INTERVAL: float = 0.5

@export var text_bottom_linear: float = 46.0
@export var text_bottom_confirm: float = 33.0

@onready var _label: GBLabel = $GBLabel
@onready var _choice: Control = $Choice
@onready var _cursor: Label = $Choice/Cursor
@onready var _more: TextureRect = $MorePrompt

var _lines: PackedStringArray = []
var _index := 0
var _mode: Mode = Mode.LINEAR
var _choosing := false
# Doubles as the slot the caret is on and as what close() reports, so a box closed from
# the outside still answers instead of leaving the caller waiting.
var _answer := false
var _blink := 0.0

func _ready() -> void:
	# Authored visible so the box can be placed in the editor; only an
	# interaction is allowed to put it on screen at runtime.
	visible = false
	_choice.visible = false
	_more.visible = false
	# The options only show up once the last line has finished typing itself, so the
	# box listens to the label rather than waiting for another button press.
	_label.text_finished.connect(_on_text_finished)

# The prompt blinks whenever the box is waiting on a press, whether that press scrolls the
# text up a line, turns the page or closes the box: to the player it is the same message.
func _process(delta: float) -> void:
	if not visible or _choosing or _label.is_printing():
		_more.visible = false
		_blink = 0.0
		return
	_blink += delta
	_more.visible = fmod(_blink, BLINK_INTERVAL * 2.0) < BLINK_INTERVAL

func _unhandled_input(event: InputEvent) -> void:
	# Input callbacks ignore visibility, so a hidden box would otherwise eat
	# every btn_a in the game.
	if not visible:
		return
	# An open box is modal: the pause menu sits under it in the same container and
	# unhandled input walks the tree bottom up, so swallowing btn_start here is what
	# keeps the paused screen from opening on top of a question.
	if event.is_action_pressed("btn_start"):
		get_viewport().set_input_as_handled()
		return
	if _choosing:
		_choice_input(event)
		return
	if event.is_action_pressed("btn_a"):
		advance()
		# Keeps the press that talks to the box from also reaching gameplay.
		get_viewport().set_input_as_handled()

func _choice_input(event: InputEvent) -> void:
	if event.is_action_pressed("btn_a"):
		_pick(_answer)
	elif event.is_action_pressed("btn_b"):
		_pick(false)
	elif event.is_action_pressed("dpad_left"):
		_set_answer(true)
	elif event.is_action_pressed("dpad_right"):
		_set_answer(false)
	else:
		return
	get_viewport().set_input_as_handled()

func show_dialogue(lines: PackedStringArray) -> void:
	_show(lines, Mode.LINEAR, false)

# Same as show_dialogue(), except the last line stays up with a YES / NO row under it:
# dpad left and right move the caret, btn_a picks, btn_b answers NO. The answer comes
# back through choice_made.
# The row takes the bottom of the panel, so a question gets fewer lines than a plain
# message. Length is not a problem either way: what does not fit scrolls.
func show_confirm(lines: PackedStringArray, default_accept: bool = false) -> void:
	_show(lines, Mode.CONFIRM, default_accept)

func _show(lines: PackedStringArray, mode: Mode, default_accept: bool) -> void:
	# Nothing to say is not an error, it just means no box.
	if lines.is_empty():
		return
	_lines = lines
	_index = 0
	_mode = mode
	_choosing = false
	_choice.visible = false
	_set_answer(default_accept)
	visible = true
	_blink = 0.0
	# Resized before printing: the label counts its visible lines off this rect.
	_label.offset_top = TEXT_TOP
	_label.offset_bottom = text_bottom_confirm if mode == Mode.CONFIRM else text_bottom_linear
	_label.print_paragraph(_lines[0])

func advance() -> void:
	if not visible:
		return
	# A question is answered, not advanced past
	if _choosing:
		return
	# Classic GameBoy: the first press fills the line in, the next one moves on. On the
	# last line of a confirm that first press is what puts the options up, so answering
	# always costs a second press and nobody confirms by accident.
	if _label.is_printing():
		_label.skip()
		return
	# The page is full and the text goes on: one press, one line up.
	if _label.has_more_lines():
		_label.scroll_line()
		return
	_index += 1
	if _index >= _lines.size():
		close()
		return
	_label.print_paragraph(_lines[_index])

func close() -> void:
	if not visible:
		return
	var was_confirm := _mode == Mode.CONFIRM
	var answer := _answer
	visible = false
	_choice.visible = false
	_more.visible = false
	_choosing = false
	_mode = Mode.LINEAR
	_lines = []
	_index = 0
	_label.clear_text()
	dialogue_finished.emit()
	# After dialogue_finished on purpose: whoever listens to both sees the box close
	# first and the answer second, and a close() from the outside still answers.
	if was_confirm:
		choice_made.emit(answer)

func is_open() -> bool:
	return visible

# True while the question is up and waiting for an answer
func is_choosing() -> bool:
	return _choosing

func _on_text_finished() -> void:
	if not visible or _mode != Mode.CONFIRM or _choosing:
		return
	# Only the last line carries the question
	if _index < _lines.size() - 1:
		return
	_choosing = true
	_choice.visible = true

func _set_answer(accepted: bool) -> void:
	if _answer != accepted and _choosing:
		AudioManager.play_sfx(AudioManager.ui_move_sound, -10.0)
	_answer = accepted
	_cursor.position.x = CURSOR_YES_X if accepted else CURSOR_NO_X
	
func _pick(accepted: bool) -> void:
	AudioManager.play_sfx(AudioManager.ui_select_sound, -8.0)
	_answer = accepted
	close()
