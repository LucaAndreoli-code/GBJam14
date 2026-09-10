extends Node

# Global event hub.
# Scenes emit here, other scenes listen here, so they never need to know each other.
# Add new signals below as the game grows.

# Fired when the game is paused or unpaused.
signal game_paused(is_paused: bool)
