extends Node

@export var cave_sound: AudioStream
@export var dig_sound: AudioStream
@export var discovery_sound: AudioStream
@export var footstep_sound: AudioStream
@export var bump_sound: AudioStream
@export var key_pickup_sound: AudioStream
@export var torch_out_sound: AudioStream
@export var unlock_door_sound: AudioStream
@export var leveltheme: AudioStream
@export var minigametheme: AudioStream
@export var losestinger: AudioStream
@export var winstinger: AudioStream
@export var titletheme: AudioStream
var sfx_players: Array[AudioStreamPlayer] = []
var max_players := 14


func _ready():
	for i in max_players:
		var player = AudioStreamPlayer.new()
		# The scene swap in SceneManager.go_to() pauses the whole tree; a pausable player
		# would be cut off mid-sound for the duration of the fade out/in.
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		sfx_players.append(player)


func play_sfx(sound: AudioStream):
	for player in sfx_players:
		if not player.playing:
			player.stream = sound
			player.play()
			return
			
			
