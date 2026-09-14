extends Node

# Global event hub.
# Scenes emit here, other scenes listen here, so they never need to know each other.
# Add new signals below as the game grows.

# Fired when the game is paused or unpaused.
signal game_paused(is_paused: bool)

# Fired when the torch's timer ticks.
signal torch_tick(remaining: int, light_value: float)

# Fired when the torch's ends
signal torch_ended(is_ended: bool)
