extends Node

# Global event hub.
# Scenes emit here, other scenes listen here, so they never need to know each other.
# Add new signals below as the game grows.

@warning_ignore_start("unused_signal")

## Fired when the visibility shader is toggled.
signal visibility_shader_toggled(is_enabled: bool)

## Fired when the game is paused or unpaused.
signal game_paused(is_paused: bool)

## Fired when the game's input is enabled or not.
signal input_enabled(is_enabled: bool)

## Fired each game's tick.
signal game_tick(delta: float, game_time: float)

## Fired each game's second.
signal game_second_tick(game_seconds: int)

## Fired when the torch's timer ticks.
signal torch_tick(remaining: int, light_value: float)

## Fired when a torch refill is requested.
signal torch_refill(source: Node2D)

## Fired when the gameover countdown changes: the seconds left and whether it is running.
signal gameover_tick(remaining: int, is_active: bool)

## Fired once when the gameover countdown runs out.
signal gameover_triggered()

## Fired when the keys' counter changes
signal keys_changed(amount: int)

## Fired when the treasure points change: what has been banked so far, and what the level's
## pool is worth in total.
signal points_changed(collected: int, total: int)

## Fired once when the dungeon's exit door unlocks.
signal exit_door_opened()

## Fired when an entity asks the current scene to show a dialogue box, one array entry per page.
signal dialogue_requested(lines: PackedStringArray)

@warning_ignore_restore("unused_signal")
