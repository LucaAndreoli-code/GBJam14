extends Node

var _title_font: Font
var _text_font: Font
var _little_font: Font

var _seed: int = 0
var _paused: bool = false
var _input_enabled: bool = true

var _time: GameTime.Data = GameTime.Data.new()
var _torch: TorchTimer.Data = TorchTimer.Data.new()
var _gameover: GameoverTimer.Data = GameoverTimer.Data.new()
var _keys: int = 0
var _collected_treasures: Dictionary[TreasureInfo, int] = {}

var _dug_interactables: Dictionary[Vector2i, bool] = {}
var _seen_scene_intros: Dictionary[String, bool] = {}

var _minimap: MinimapUtils.Data = MinimapUtils.Data.new()
var _treasures_pool_generated: bool = false
var _treasures_pool: Array[TreasureInfo] = []

var _collected_points: int = 0
var _total_points: int = 0
var _exit_door_opened: bool = false

func get_title_font() -> Font:
	return _title_font

func get_text_font() -> Font:
	return _text_font

func get_little_font() -> Font:
	return _little_font

func set_fonts(title_font: Font, text_font: Font, little_font: Font) -> void:
	_title_font = title_font
	_text_font = text_font
	_little_font = little_font

func get_seed() -> int:
	if _seed == 0:
		set_seed(randi_range(1, 999999999))
		push_warning("Seed not set, generated %d instead" % _seed)
	return _seed

func set_seed(value: int) -> void:
	_seed = value
	seed(_seed)

func is_paused() -> bool:
	return _paused

func set_paused(value: bool) -> void:
	if _paused == value:
		return
	_paused = value
	SignalBus.game_paused.emit(_paused)

func is_input_enabled() -> bool:
	return _input_enabled

func set_input_enabled(value: bool) -> void:
	if _input_enabled == value:
		return
	_input_enabled = value
	SignalBus.input_enabled.emit(_input_enabled)

func get_time() -> GameTime.Data:
	return _time

func set_time(data: GameTime.Data) -> void:
	if data:
		if data.time != _time.time:
			_time.time = data.time
		if data.seconds != _time.seconds:
			_time.seconds = data.seconds
		if data.last_tick != _time.last_tick:
			_time.last_tick = data.last_tick

func get_torch() -> TorchTimer.Data:
	return _torch

func set_torch(data: TorchTimer.Data) -> void:
	if data:
		if data.duration != _torch.duration:
			_torch.duration = data.duration
		if data.countdown != _torch.countdown:
			_torch.countdown = data.countdown

func get_gameover() -> GameoverTimer.Data:
	return _gameover

func set_gameover(data: GameoverTimer.Data) -> void:
	if data:
		if data.duration != _gameover.duration:
			_gameover.duration = data.duration
		if data.countdown != _gameover.countdown:
			_gameover.countdown = data.countdown
		if data.active != _gameover.active:
			_gameover.active = data.active

func get_keys() -> int:
	return _keys

func set_keys(value: int) -> void:
	if _keys == value:
		return
	_keys = value
	SignalBus.keys_changed.emit(_keys)

func get_collected_treasures() -> Dictionary[TreasureInfo, int]:
	return _collected_treasures

func add_treasures_to_collection(value: Array[TreasureInfo]) -> void:
	if value.is_empty():
		return
	for t in value:
		if _collected_treasures.has(t):
			_collected_treasures[t] += 1
		else:
			_collected_treasures[t] = 1
		_collected_points += TreasureUtils.get_treasure_points(t)
	SignalBus.points_changed.emit(_collected_points, _total_points)

func get_collected_points() -> int:
	return _collected_points

func get_total_points() -> int:
	return _total_points

func is_exit_door_opened() -> bool:
	return _exit_door_opened

# One-way and emitted from here, so the door announces itself exactly once per run even though
# the dungeon scene is rebuilt on every return from a digging run.
func set_exit_door_opened() -> void:
	if _exit_door_opened:
		return
	_exit_door_opened = true
	SignalBus.exit_door_opened.emit()

func is_interactable_dug(cell: Vector2i) -> bool:
	if not _dug_interactables.has(cell):
		return false
	return _dug_interactables[cell]

func add_dug_interactable(cell: Vector2i) -> void:
	if _dug_interactables.has(cell):
		return
	_dug_interactables[cell] = true

# Session state: never reset, so a scene's intro text plays once per launch even though the
# dungeon scene is rebuilt on every return from a digging run.
func is_scene_intro_seen(intro_key: String) -> bool:
	return _seen_scene_intros.get(intro_key, false)

func mark_scene_intro_seen(intro_key: String) -> void:
	_seen_scene_intros[intro_key] = true

func get_minimap() -> MinimapUtils.Data:
	return _minimap

func set_minimap(value: MinimapUtils.Data) -> void:
	_minimap = value
	_minimap.empty = _minimap.rooms.size() <= 0

func is_treasures_pool_generated() -> bool:
	return _treasures_pool_generated

func get_treasures_pool() -> Array[TreasureInfo]:
	return _treasures_pool

func set_treasures_pool(value: Array[TreasureInfo]) -> void:
	_treasures_pool = value
	_treasures_pool_generated = true
	# Read here, while the pool is still whole: every digging run pops treasures out of it.
	_total_points = 0
	for t in _treasures_pool:
		_total_points += TreasureUtils.get_treasure_points(t)
	SignalBus.points_changed.emit(_collected_points, _total_points)
