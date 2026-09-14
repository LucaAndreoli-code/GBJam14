extends Node

# Global event hub.
# Scenes emit here, other scenes listen here, so they never need to know each other.
# Add new signals below as the game grows.

# Fired when the game is paused or unpaused.
signal game_paused(is_paused: bool)

# Fired each game's tick
signal game_tick(delta: float, game_time: float)

# Fired each game's second
signal game_second_tick(game_seconds: int)

# Fired when the torch's timer ticks.
signal torch_tick(remaining: int, light_value: float)

# Fired when a torch refill is requested
signal torch_refill(source: Node2D)
