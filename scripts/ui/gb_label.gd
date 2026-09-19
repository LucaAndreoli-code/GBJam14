class_name GBLabel
extends Label

# Label that reveals its text one character at a time, GameBoy dialogue style.
# It never slices the string
#
# Two ways to drive it. print_text() types one string as it is, which is what every menu
# label in the game uses. print_paragraph() is opt-in: it wraps a long text against the
# label's own font and width, keeps a window of as many lines as the rect can show, and
# types the bottom one, so nothing ever spills outside the rect.
#
# Listeners hook the signals instead of polling: character_printed carries the
# character itself so audio can stay silent on spaces and punctuation.

# Fired once per revealed character. Not fired for the characters a skip reveals.
# In paragraph mode the index is relative to the line being typed, not to the whole text.
signal character_printed(character: String, index: int)
# Fired when the whole text is on screen, whether it finished typing or was skipped.
# In paragraph mode it waits for the last line: a full window with more text behind it
# fires lines_pending instead.
signal text_finished()
# Fired when the window is full and there is still text waiting. Whoever shows the label
# puts a "press A" prompt up and calls scroll_line() on the press.
signal lines_pending()

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

# Paragraph mode state. Only print_paragraph() turns it on: the single-line path leaves
# every field below at the values set here, where _prefix of 0 makes it a no-op.
var _paragraph := false
var _window: PackedStringArray = []
var _pending: PackedStringArray = []
var _visible_lines := 1
# Set while a skip is filling the page in: it turns every line that still fits the window
# into an instant reveal instead of a new typing run.
var _skipping := false
# Characters of the window lines already typed, newlines included. The typewriter counts
# from here, so the lines above the one being typed stay on screen.
var _prefix := 0

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
	_paragraph = false
	_window = []
	_pending = []
	_prefix = 0
	text = new_text
	_start_typing(new_text)

# Types a long text inside the rect instead of letting it overflow: the text is wrapped to
# the label's width, and only as many lines as the rect can show are on screen at once.
# When the window fills up and text is left, the label stops and fires lines_pending.
func print_paragraph(source: String) -> void:
	# The text is already broken into lines here, so Label's own wrapping would only
	# re-break what does not need it.
	autowrap_mode = TextServer.AUTOWRAP_OFF
	_paragraph = true
	_window = []
	_prefix = 0
	_visible_lines = maxi(1, int(size.y / get_line_height()))
	_pending = _wrap_lines(source)
	if _pending.is_empty():
		text = ""
		_start_typing("")
		return
	_start_next_line()

# Drops the top line of the window and types the next one under it. Nothing to scroll to
# is not an error: the caller asks has_more_lines() first, or calls this blind.
func scroll_line() -> void:
	if not _paragraph or _pending.is_empty():
		return
	if _window.size() >= _visible_lines:
		_window.remove_at(0)
	_start_next_line()

# True while the window is full and text is still waiting behind it.
func has_more_lines() -> bool:
	return _paragraph and not _pending.is_empty()

func skip() -> void:
	if not _printing:
		return
	# No character_printed for the rest: that would fire a burst of audio.
	if not _paragraph:
		_finish()
		return
	# Classic GameBoy: one press fills the whole visible page, not just the line being
	# typed. The window stops it: what is left still waits for a scroll.
	_skipping = true
	_finish()
	_skipping = false

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
	_paragraph = false
	_skipping = false
	_window = []
	_pending = []
	_prefix = 0

# Greedy word wrap against the label's own font and width. Label can wrap on its own but
# never says where it broke, and the window needs the individual lines.
func _wrap_lines(source: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	var max_width := size.x if size.x > 0.0 else custom_maximum_size.x
	if max_width <= 0.0:
		return PackedStringArray([source])
	# Authored line breaks are kept: each one starts a new wrapped block.
	for block in source.split("\n"):
		var current := ""
		for word in block.split(" ", false):
			var candidate := word if current.is_empty() else current + " " + word
			if _measure(candidate) <= max_width:
				current = candidate
				continue
			if not current.is_empty():
				lines.append(current)
				current = ""
			# A single word wider than the rect has nowhere to break: cut it instead of
			# letting it run past the frame.
			while _measure(word) > max_width and word.length() > 1:
				var cut := 1
				while cut < word.length() and _measure(word.substr(0, cut + 1)) <= max_width:
					cut += 1
				lines.append(word.substr(0, cut))
				word = word.substr(cut)
			current = word
		lines.append(current)
	return lines

func _measure(part: String) -> float:
	var font := get_theme_font("font")
	if font == null:
		return 0.0
	return font.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_font_size("font_size")).x

func _start_next_line() -> void:
	var line: String = _pending[0]
	_pending.remove_at(0)
	_window.append(line)
	text = "\n".join(_window)
	# Everything above the new line is already typed and stays on screen.
	_prefix = text.length() - line.length()
	_start_typing(line)

func _start_typing(line: String) -> void:
	_target_count = line.length()
	_revealed = 0
	_elapsed = 0.0
	_printing = true
	visible_characters = _prefix
	if _target_count == 0 or _skipping:
		# Still finishes, so a caller awaiting text_finished never hangs.
		_finish()
		return
	set_process(true)

func _reveal_next() -> void:
	var index := _revealed
	_revealed += 1
	visible_characters = _prefix + _revealed
	character_printed.emit(text[_prefix + index], index)

func _finish() -> void:
	_revealed = _target_count
	_printing = false
	set_process(false)
	visible_characters = -1
	if not _paragraph:
		text_finished.emit()
		return
	# The window still has room, so the text keeps flowing without asking for a press.
	if not _pending.is_empty() and _window.size() < _visible_lines:
		_start_next_line()
		return
	if not _pending.is_empty():
		lines_pending.emit()
		return
	text_finished.emit()
