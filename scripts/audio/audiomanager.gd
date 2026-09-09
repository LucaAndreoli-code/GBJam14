extends Node

# Audio player pool for sound effects
var sfx_players: Array[AudioStreamPlayer] = []
var max_sfx_players: int = 8

# Dedicated music player
var music_player: AudioStreamPlayer


func _ready() -> void:
	# Create SFX player pool
	for i in range(max_sfx_players):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)

	# Create music player
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)


# Play a sound effect using the first available player
func play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return

	for player in sfx_players:
		if not player.playing:
			player.stream = stream
			player.play()
			return

	# If all players are busy, reuse the first one
	sfx_players[0].stream = stream
	sfx_players[0].play()


# Play background music
func play_music(stream: AudioStream) -> void:
	if stream == null:
		return

	if music_player.stream == stream and music_player.playing:
		return

	music_player.stream = stream
	music_player.play()


# Stop the current music
func stop_music() -> void:
	music_player.stop()


# Pause the current music
func pause_music() -> void:
	music_player.stream_paused = true


# Resume the current music
func resume_music() -> void:
	music_player.stream_paused = false
