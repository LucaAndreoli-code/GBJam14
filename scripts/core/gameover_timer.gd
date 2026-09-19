class_name GameoverTimer
extends RefCounted

## The countdown that starts when the torch dies. It lives in GameState rather than in the
## scene that owns it: the pit is a scene of its own, and a countdown rebuilt on every swap
## would hand the player a fresh minute for free.

class Data:
	var duration: int = 0
	var countdown: int = 0
	var active: bool = false

var _duration: int = 0
var _countdown_timer: int = 0
var _is_active: bool = false

func _init() -> void:
	var data := GameState.get_gameover()
	_duration = data.duration
	_countdown_timer = data.countdown
	_is_active = data.active
	SignalBus.game_second_tick.connect(_on_game_second_tick)
	SignalBus.torch_tick.connect(_on_torch_tick)
	SignalBus.torch_refill.connect(_on_refill)

func is_active() -> bool:
	return _is_active

func get_remaining_duration() -> int:
	return _countdown_timer

## Mirrors TorchTimer.broadcast(): the HUD is rebuilt with the scene and only hears changes,
## so the state has to be pushed once the listeners are connected.
func broadcast() -> void:
	SignalBus.gameover_tick.emit(_countdown_timer, _is_active)

## Idempotent on purpose: torch_tick(0) arrives on every scene entry through
## TorchTimer.broadcast(), and a countdown already running must not start over.
func arm() -> void:
	if _is_active:
		return
	if _duration <= 0:
		push_warning("Gameover timer armed with no duration, see DungeonManager._setup_gameover()")
		return
	_is_active = true
	_countdown_timer = _duration
	_update_game_state()
	SignalBus.gameover_tick.emit(_countdown_timer, _is_active)

func _on_torch_tick(remaining: int, _light_value: float) -> void:
	if remaining > 0:
		return
	arm()

func _on_refill(source: Node2D) -> void:
	# Same gate as TorchTimer._on_refill(): only the dungeon player picks torches up.
	if not source is PlayerDungeonController:
		return
	_is_active = false
	_countdown_timer = _duration
	_update_game_state()
	SignalBus.gameover_tick.emit(_countdown_timer, _is_active)

func _on_game_second_tick(_game_seconds: int) -> void:
	if not _is_active:
		return
	# Spent: the signal below fires exactly once, and a scene re-entered on a dead countdown
	# must not fire it again.
	if _countdown_timer == 0:
		return
	_countdown_timer -= 1
	SignalBus.gameover_tick.emit(_countdown_timer, _is_active)
	print("Gameover update: %d seconds from gameover" % _countdown_timer)
	_update_game_state()
	if _countdown_timer == 0:
		SignalBus.gameover_triggered.emit()

func _update_game_state() -> void:
	var data := Data.new()
	data.duration = _duration
	data.countdown = _countdown_timer
	data.active = _is_active
	GameState.set_gameover(data)
