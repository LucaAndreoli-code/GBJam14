extends Node

var _title_font: Font
var _text_font: Font
var _little_font: Font

var _seed: int = 0
var _just_started: bool = true
var _paused: bool = false
var _input_enabled: bool = true

var _music_level: float = 0.0
var _sfx_level: float = 0.0

var _time: GameTime.Data = GameTime.Data.new()
var _torch: TorchTimer.Data = TorchTimer.Data.new()
var _gameover: GameoverTimer.Data = GameoverTimer.Data.new()
var _keys: int = 0
var _collected_treasures: Dictionary[TreasureInfo, int] = {}

# World state, scoped per level: the level's scene_file_path maps to a
# Dictionary[Vector2i, bool] of tilemap cells. The dungeon scene is rebuilt from its .tscn on
# every return from a digging run, so whatever the world lost has to be replayed from here.
var _dug_interactables: Dictionary[String, Dictionary] = {}
var _taken_torches: Dictionary[String, Dictionary] = {}
var _taken_keys: Dictionary[String, Dictionary] = {}
var _opened_doors: Dictionary[String, Dictionary] = {}

var _seen_scene_intros: Dictionary[String, bool] = {}
var _seen_session_intros: Dictionary[String, bool] = {}

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

func is_just_started() -> bool:
	return _just_started

func set_just_started(value: bool) -> void:
	if _just_started == value:
		return
	_just_started = value

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

func get_music_level() -> float:
	return _music_level

func set_music_level(value: float) -> void:
	if value != _music_level:
		_music_level = value
		SignalBus.music_level_changed.emit(_music_level)

func get_sfx_level() -> float:
	return _sfx_level

func set_sfx_level(value: float) -> void:
	if value != _sfx_level:
		_sfx_level = value
		SignalBus.sfx_level_changed.emit(_sfx_level)

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

func is_interactable_dug(level_key: String, cell: Vector2i) -> bool:
	return _has_level_cell(_dug_interactables, level_key, cell)

func add_dug_interactable(level_key: String, cell: Vector2i) -> void:
	_add_level_cell(_dug_interactables, level_key, cell)

func is_torch_taken(level_key: String, cell: Vector2i) -> bool:
	return _has_level_cell(_taken_torches, level_key, cell)

func add_taken_torch(level_key: String, cell: Vector2i) -> void:
	_add_level_cell(_taken_torches, level_key, cell)

func is_key_taken(level_key: String, cell: Vector2i) -> bool:
	return _has_level_cell(_taken_keys, level_key, cell)

func add_taken_key(level_key: String, cell: Vector2i) -> void:
	_add_level_cell(_taken_keys, level_key, cell)

func is_door_opened(level_key: String, cell: Vector2i) -> bool:
	return _has_level_cell(_opened_doors, level_key, cell)

func add_opened_door(level_key: String, cell: Vector2i) -> void:
	_add_level_cell(_opened_doors, level_key, cell)

## The cells a level has to re-open on load, see DungeonManager._reapply_opened_doors().
func get_opened_doors(level_key: String) -> Array:
	return _opened_doors.get(level_key, {}).keys()

func _has_level_cell(store: Dictionary, level_key: String, cell: Vector2i) -> bool:
	var cells: Dictionary = store.get(level_key, {})
	return cells.get(cell, false)

func _add_level_cell(store: Dictionary, level_key: String, cell: Vector2i) -> void:
	if not store.has(level_key):
		var cells: Dictionary[Vector2i, bool] = {}
		store[level_key] = cells
	store[level_key][cell] = true

# Session state: never reset, so a scene's intro text plays once per launch even though the
# dungeon scene is rebuilt on every return from a digging run.
func is_scene_intro_seen(intro_key: String) -> bool:
	return _seen_scene_intros.get(intro_key, false)

func mark_scene_intro_seen(intro_key: String) -> void:
	_seen_scene_intros[intro_key] = true

func is_session_intro_seen(key: String) -> bool:
	return _seen_session_intros.has(key)

func mark_session_intro_seen(key: String) -> void:
	_seen_session_intros[key] = true

func clear_session_intros() -> void:
	_seen_session_intros.clear()

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

# Wipes everything a single run owns. Called when the level selection opens, so replaying a level
# starts from a clean world. Fonts and _seen_scene_intros are deliberately left alone: the first
# is process-wide setup, the second is session state by design, see is_scene_intro_seen().
func reset_run() -> void:
	_seed = 0
	_paused = false
	_input_enabled = true
	_time = GameTime.Data.new()
	_torch = TorchTimer.Data.new()
	_gameover = GameoverTimer.Data.new()
	_keys = 0
	_collected_treasures = {}
	_dug_interactables = {}
	_taken_torches = {}
	_taken_keys = {}
	_opened_doors = {}
	_minimap = MinimapUtils.Data.new()
	_treasures_pool_generated = false
	_treasures_pool = []
	_collected_points = 0
	_total_points = 0
	_exit_door_opened = false
	clear_session_intros()
