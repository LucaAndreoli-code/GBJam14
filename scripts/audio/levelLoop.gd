extends Node

@onready var music_player = $AudioStreamPlayer

func _ready():
	# Force the track to start at 0 seconds to play the intro
	music_player.play(0.0) 
