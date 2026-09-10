extends Control

# Demo harness for GBLabel. Logs both signals so their timing can be checked,
# and reprints on btn_b so the typewriter can be replayed without restarting.

const DEMO_TEXT := "HELLO FROM GB JAM 14! PRESS A TO SKIP, B TO REPLAY."

@onready var _label: GBLabel = $PaletteContainer/Screen/GBLabel

func _ready() -> void:
	_label.character_printed.connect(_on_character_printed)
	_label.text_finished.connect(_on_text_finished)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("btn_b"):
		_label.print_text(DEMO_TEXT)
		get_viewport().set_input_as_handled()

func _on_character_printed(character: String, index: int) -> void:
	print("character_printed: '%s' at %d" % [character, index])

func _on_text_finished() -> void:
	print("text_finished")
