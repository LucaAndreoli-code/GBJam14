extends Node

var leveltheme: AudioStream = preload("res://assets/audio/Music/LevelTheme_NoTail.mp3")
var minigametheme: AudioStream = preload("res://assets/audio/Music/Minigame_160BPM.mp3")
var losestinger: AudioStream = preload("res://assets/audio/Music/LoseStinger.wav")
var winstinger: AudioStream = preload("res://assets/audio/Music/WinStinger.wav")
var titletheme: AudioStream = preload("res://assets/audio/Music/TitleScreen_Draft1.wav")

var cave_sound: AudioStream = preload("res://assets/audio/SFX/CaveIn.wav")
var dig_sound: AudioStream = preload("res://assets/audio/SFX/Dig.wav")
var discovery_sound: AudioStream = preload("res://assets/audio/SFX/Discovery.wav")
var footstep_sound: AudioStream = preload("res://assets/audio/SFX/Footstep.wav")
var bump_sound: AudioStream = preload("res://assets/audio/SFX/Bump.wav")
var key_pickup_sound: AudioStream = preload("res://assets/audio/SFX/KeyPickup.wav")
var torch_out_sound: AudioStream = preload("res://assets/audio/SFX/TorchOut.wav")
var unlock_door_sound: AudioStream = preload("res://assets/audio/SFX/UnlockDoor.wav")

var sfx_players: Array[AudioStreamPlayer] = []
var max_players := 14

func _ready():
	for i in max_players:
		var player = AudioStreamPlayer.new()
		add_child(player)
		sfx_players.append(player)

func play_sfx(sound: AudioStream):
	if sound == null:
		push_error("AudioManager: Tried to play a null sound!")
		return

	for player in sfx_players:
		if not player.playing:
			player.stream = sound
			player.play()
			return
