class_name GBLabel
extends Label

# Label that reveals its text one character at a time, GameBoy dialogue style.
# It never slices the string
#
# Listeners hook the signals instead of polling: character_printed carries the
# character itself so audio can stay silent on spaces and punctuation.

# Fired once per revealed character. Not fired for the characters a skip reveals.
signal character_printed(character: String, index: int)
# Fired when the whole text is on screen, whether it finished typing or was skipped.
signal text_finished()

# Reveal rate. Zero or less prints the whole text instantly.
@export var characters_per_second: float = 20.0
# Whether _ready types out the text the scene already carries.
@export var auto_start: bool = true
# Whether btn_a skips ahead. Turn it off when something else owns the input.
@export var skip_enabled: bool = true

var _printing := false
var _target_count := 0
var _revealed := 0
var _elapsed := 0.0

func _ready() -> void:
	# Label defaults to VC_CHARS_BEFORE_SHAPING, which drops the hidden characters
	# before the text is shaped: with autowrap on, the box reflows on every reveal.
	# AFTER_SHAPING shapes the full string once and only hides glyphs, so the
	# layout is final from the first character.
	visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	set_process(false)
	if auto_start and not text.is_empty():
		print_text(text)
	else:
		visible_characters = -1

func _unhandled_input(event: InputEvent) -> void:
	if not skip_enabled or not _printing:
		return
	if event.is_action_pressed("btn_a"):
		skip()
		# Stops the same press from also advancing whatever shows this label.
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if characters_per_second <= 0.0:
		_finish()
		return
	var interval := 1.0 / characters_per_second
	_elapsed += delta
	# A loop, not an if: above 60 chars/s more than one character lands per frame.
	# The _printing check keeps a character_printed listener free to call
	# print_text() or skip() from inside the loop.
	while _printing and _elapsed >= interval and _revealed < _target_count:
		_elapsed -= interval
		_reveal_next()
	if _printing and _revealed >= _target_count:
		_finish()

func print_text(new_text: String) -> void:
	text = new_text
	_target_count = get_total_character_count()
	_revealed = 0
	_elapsed = 0.0
	_printing = true
	visible_characters = 0
	if _target_count == 0:
		# Still finishes, so a caller awaiting text_finished never hangs.
		_finish()
		return
	set_process(true)

func skip() -> void:
	if not _printing:
		return
	# No character_printed for the rest: that would fire a burst of audio.
	_finish()

func is_printing() -> bool:
	return _printing

func clear_text() -> void:
	_printing = false
	set_process(false)
	text = ""
	_target_count = 0
	_revealed = 0
	_elapsed = 0.0
	visible_characters = -1

func _reveal_next() -> void:
	var index := _revealed
	_revealed += 1
	visible_characters = _revealed
	character_printed.emit(text[index], index)

func _finish() -> void:
	_revealed = _target_count
	_printing = false
	set_process(false)
	visible_characters = -1
	text_finished.emit()
