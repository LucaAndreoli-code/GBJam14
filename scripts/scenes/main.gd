class_name MainScene
extends Control

@export var initial_scene: PackedScene
@export var title_font: Font
@export var text_font: Font
@export var little_font: Font

@onready var _game_viewport: SubViewport = $PaletteContainer/Screen/VisibilityContainer/GameWorld
@onready var _bottom_bar: Control = $PaletteContainer/Screen/BottomBar
@onready var _music_player: AudioStreamPlayer2D = $Music/Music

func _ready() -> void:
	GameState.set_fonts(title_font, text_font, little_font)
	SceneManager.register_viewport(self, _game_viewport)
	if initial_scene == null:
		push_warning("No initial scene set on Main!")
	else:
		SceneManager.go_to(initial_scene.resource_path, {})
	SignalBus.music_level_changed.connect(_on_music_level_changed)

func get_music_player() -> AudioStreamPlayer2D:
	return _music_player

func toggle_bottom_bar(is_enabled: bool) -> void:
	if _bottom_bar and _bottom_bar.visible != is_enabled:
		_bottom_bar.visible = is_enabled

func _on_music_level_changed(level: float) -> void:
	_music_player.volume_db = linear_to_db(level)
