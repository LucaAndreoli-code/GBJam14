extends Control

# Demo harness for GBTextBox: btn_b opens the dialogue, btn_a fills in and advances.

const DEMO_LINES: PackedStringArray = [
	"HELLO FROM GB JAM 14!",
	"PRESS A TO FILL THE LINE IN.",
	"PRESS A AGAIN TO GO ON.",
	"PRESS B TO REPLAY.",
]

@onready var _box: GBTextBox = $PaletteContainer/Screen/GBTextBox

func _ready() -> void:
	_box.dialogue_finished.connect(_on_dialogue_finished)
	_box.show_dialogue(DEMO_LINES)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("btn_b") and not _box.is_open():
		_box.show_dialogue(DEMO_LINES)
		get_viewport().set_input_as_handled()

func _on_dialogue_finished() -> void:
	print("dialogue_finished")
