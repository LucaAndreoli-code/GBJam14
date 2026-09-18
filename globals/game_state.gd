extends Node

var _title_font: Font
var _text_font: Font
var _little_font: Font

var _seed: int = 0
var _paused: bool = false
var _input_enabled: bool = true

var _time: GameTime.Data = GameTime.Data.new()
var _torch: TorchTimer.Data = TorchTimer.Data.new()
var _keys: int = 0

var _dug_interactables: Dictionary[Vector2i, bool] = {}

var _minimap: MinimapUtils.Data = MinimapUtils.Data.new()

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
		set_seed(randi_range(1, UINT32_MAX))
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

func get_keys() -> int:
	return _keys

func set_keys(value: int) -> void:
	if _keys == value:
		return
	_keys = value
	SignalBus.keys_changed.emit(_keys)

func is_interactable_dug(cell: Vector2i) -> bool:
	if not _dug_interactables.has(cell):
		return false
	return _dug_interactables[cell]

func add_dug_interactable(cell: Vector2i) -> void:
	if _dug_interactables.has(cell):
		return
	_dug_interactables[cell] = true

func get_minimap() -> MinimapUtils.Data:
	return _minimap

func set_minimap(value: MinimapUtils.Data) -> void:
	_minimap = value
	_minimap.empty = _minimap.rooms.size() <= 0
