extends Node

var leveltheme: AudioStream = preload("res://assets/audio/Music/LevelTheme_NoTail.mp3")
var minigametheme: AudioStream = preload("res://assets/audio/Music/Minigame_160BPM.mp3")
var losestinger: AudioStream = preload("res://assets/audio/Music/LoseStinger.wav")
var winstinger: AudioStream = preload("res://assets/audio/Music/WinStinger.mp3")
var titletheme: AudioStream = preload("res://assets/audio/Music/TitleScreen_Draft1.wav")
var level_selection_theme: AudioStream = preload ("res://assets/audio/Music/MapScreen_Phrygian.mp3")
var cave_sound: AudioStream = preload("res://assets/audio/SFX/CaveIn.wav")
var dig_sound: AudioStream = preload("res://assets/audio/SFX/Dig.wav")
var discovery_sound: AudioStream = preload("res://assets/audio/SFX/Discovery.wav")
var footstep_sound: AudioStream = preload("res://assets/audio/SFX/Footstep.wav")
var bump_sound: AudioStream = preload("res://assets/audio/SFX/Bump.wav")
var key_pickup_sound: AudioStream = preload("res://assets/audio/SFX/KeyPickup.wav")
var torch_out_sound: AudioStream = preload("res://assets/audio/SFX/TorchOut.wav")
var unlock_door_sound: AudioStream = preload("res://assets/audio/SFX/UnlockDoor.wav")
var text_sound: AudioStream = preload("res://assets/audio/SFX/Text.wav")
var ui_move_sound: AudioStream = preload("res://assets/audio/SFX/UI_Move.wav")
var ui_select_sound: AudioStream = preload("res://assets/audio/SFX/UI_Select.wav")
var startup_sound: AudioStream = preload("res://assets/audio/SFX/Startup.mp3")
var sfx_players: Array[AudioStreamPlayer] = []
var max_players := 19

var music_player: AudioStreamPlayer


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Music player
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)

	# SFX players
	for i in max_players:
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)

	# Volume settings
	SignalBus.music_level_changed.connect(_on_music_level_changed)
	SignalBus.sfx_level_changed.connect(_on_sfx_level_changed)


func play_music(sound: AudioStream, from_position: float = 0.0, force_restart: bool = false):
	if sound == null:
		push_error("AudioManager: Tried to play null music!")
		return

	if not force_restart and music_player.stream == sound and music_player.playing:
		return

	music_player.stream = sound
	music_player.play(from_position)


func stop_music():
	music_player.stop()


func play_sfx(sound: AudioStream, volume_db: float = 0.0) -> void:
	if sound == null:
		push_error("AudioManager: Tried to play a null sound!")
		return

	for player in sfx_players:
		if not player.playing:
			player.stream = sound
			player.volume_db = volume_db
			player.play()
			return


func _on_music_level_changed(level: float) -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(level))


func _on_sfx_level_changed(level: float) -> void:
	var bus := AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(bus, linear_to_db(level))
