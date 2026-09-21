class_name PlayerDungeonController
extends CharacterBody2D

enum Axis { 
	NONE, 
	X, 
	Y 
}

const CORNER_CORRECTION := 8.0
const DOOR_PROBE_DISTANCE := 16.0
const DOOR_OPEN_TILESET_SOURCE_ID: int = 1

@export var movement_speed: float = 30.0
@export var torch_light_radius: float = 40.0
@export var light_max_diameter: float = 20.0
@export var light_central_radius_ratio: float = 1.15
@export var light_outer_radius_ratio: float = 2.0
@export var no_light_inner_radius: float = 0.0
@export var no_light_central_radius_ratio: float = 0.0
@export var no_light_outer_radius_ratio: float = 2.0
@export var torch_light_min_value: float = 0.25

@onready var _player_light: Sprite2D = $InnerLightSprite
@onready var _interact_area: Area2D = $InteractArea
@onready var _anim_player: AnimationPlayer = $AnimationPlayer

var _dungeon: TileMapLayer
var _animator: PlayerDungeonAnimator
var _interact_hud: InteractHUD
var _torch_remaining: int = 999
var _torch_light_value: float = 1.0
var _subpixel_accumulator: Vector2 = Vector2.ZERO
var _last_axis: Axis = Axis.NONE
var _facing: Vector2i = Vector2i.DOWN
var _can_move: bool = true
var _is_input_enabled: bool = true
var _step_distance: float = 0.0
const FOOTSTEP_DISTANCE := 8.0
var _wall_bump_timer: float = 0.0
const WALL_BUMP_COOLDOWN := 0.25
var _torch_out_played: bool = false

func _ready() -> void:
	_animator = PlayerDungeonAnimator.new(_anim_player)
	var hud_container := get_tree().get_first_node_in_group(Groups.HUD_CONTAINER) as Control
	if hud_container:
		_interact_hud = InteractHUD.new(self)
		hud_container.add_child(_interact_hud)
	SignalBus.input_enabled.connect(_on_input_enabled)
	SignalBus.torch_tick.connect(_on_torch_tick)

func _process(_delta: float) -> void:
	_scale_player_light()
	_toggle_interact_hud()
	_animator.animate()

func _physics_process(delta: float) -> void:
	_wall_bump_timer = maxf(_wall_bump_timer - delta, 0.0)
	
	if not _can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var input := _get_directional_input()
	if input != Vector2.ZERO:
		_facing = Vector2i(input)
	var steps_to_move := Vector2.ZERO
	if input == Vector2.ZERO:
		velocity = Vector2.ZERO
		_subpixel_accumulator = Vector2.ZERO
	else:
		var step := input * movement_speed * delta
		_subpixel_accumulator += step
		steps_to_move = Vector2(int(_subpixel_accumulator.x), int(_subpixel_accumulator.y))
		_subpixel_accumulator -= steps_to_move
		velocity = steps_to_move / delta
	if _is_blocked(input, delta):
		var has_slid: bool = _try_corner_correction(input, delta, steps_to_move)
		if has_slid:
			velocity = Vector2.ZERO
		elif _wall_bump_timer <= 0.0:
			AudioManager.play_sfx(AudioManager.bump_sound, -12.0)
			_wall_bump_timer = WALL_BUMP_COOLDOWN
	move_and_slide()
	global_position = global_position.round()
	if steps_to_move != Vector2.ZERO:
		_step_distance += steps_to_move.length()

	if _step_distance >= FOOTSTEP_DISTANCE:
		AudioManager.play_sfx(AudioManager.footstep_sound, -12.0)
		_step_distance = 0.0
	_animator.update(input != Vector2.ZERO and _can_move, _torch_remaining > 0, _facing)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("dpad_left") or event.is_action_pressed("dpad_right"):
		_last_axis = Axis.X
	elif event.is_action_pressed("dpad_up") or event.is_action_pressed("dpad_down"):
		_last_axis = Axis.Y

func _unhandled_input(event: InputEvent) -> void:
	if not _is_input_enabled or not event.is_action_pressed("btn_a"):
		return
	var o := _get_closest_interactable_object()
	if o != null:
		o.interact(self)
		return
	var keys := GameState.get_keys()
	if keys <= 0:
		return
	var door = _get_facing_key_door()
	if door != null:
		_open_door(door)
		AudioManager.play_sfx(AudioManager.unlock_door_sound, -6.0) 
		GameState.set_keys(keys - 1)
		var lines: PackedStringArray = ["The door unlocked!"]
		SignalBus.dialogue_requested.emit(lines)

func _exit_tree() -> void:
	if is_instance_valid(_interact_hud):
		_interact_hud.queue_free()

func get_light_radius() -> Vector3:
	var light_radius: float = torch_light_radius * clamp(_torch_light_value, torch_light_min_value, 1.0)
	var has_torch := _torch_remaining > 0
	var inner_radius := no_light_inner_radius if not has_torch else light_radius
	var central_ratio := no_light_central_radius_ratio if not has_torch else light_central_radius_ratio
	var outer_ratio := no_light_outer_radius_ratio if not has_torch else light_outer_radius_ratio
	return Vector3(inner_radius, central_ratio, outer_ratio)

func force_darkness() -> bool:
	return _torch_remaining <= 0

func set_dungeon_tilemap(tilemap: TileMapLayer) -> void:
	_dungeon = tilemap

func pick_torch() -> void:
	_torch_out_played = false
	SignalBus.torch_refill.emit(self)
	var lines: PackedStringArray = ["Torch refilled!"]
	SignalBus.dialogue_requested.emit(lines)

func add_key() -> void:
	var amount := GameState.get_keys()
	GameState.set_keys(amount + 1)
	var lines: PackedStringArray = ["Got a key!"]
	SignalBus.dialogue_requested.emit(lines)

func read_note(lines: PackedStringArray) -> void:
	SignalBus.dialogue_requested.emit(lines)

func _on_input_enabled(is_enabled: bool) -> void:
	_is_input_enabled = is_enabled
	_can_move = _is_input_enabled

func _on_torch_tick(remaining: int, light_value: float) -> void:
	_torch_remaining = remaining
	_torch_light_value = light_value

	if remaining <= 0 and not _torch_out_played:
		_torch_out_played = true
		AudioManager.play_sfx(AudioManager.torch_out_sound, -4.0)

func _get_directional_input() -> Vector2:
	var input := Vector2(
		Input.get_action_strength("dpad_right") - Input.get_action_strength("dpad_left"),
		Input.get_action_strength("dpad_down") - Input.get_action_strength("dpad_up"),
	)
	if input.x != 0.0 and input.y != 0.0:
		if _last_axis == Axis.Y:
			input.x = 0.0
		else:
			input.y = 0.0
	return input

func _is_blocked(direction: Vector2, delta: float) -> bool:
	return test_move(global_transform, direction * movement_speed * delta)

func _try_corner_correction(direction: Vector2, delta: float, steps_to_move: Vector2) -> bool:
	var perpendicular := Vector2(direction.y, direction.x).abs()
	var step := direction * movement_speed * delta
	var slide_amount := steps_to_move.length()
	if slide_amount == 0:
		return false
	for offset in [1.0, -1.0]:
		for amount in range(1, int(CORNER_CORRECTION) + 1):
			var nudge: Vector2 = perpendicular * offset * amount
			if not test_move(global_transform.translated(nudge), step):
				var proportioned_nudge: Vector2 = perpendicular * offset * slide_amount
				global_position += proportioned_nudge
				return true
	return false

func _scale_player_light() -> void:
	var d: int = int(round(light_max_diameter * _torch_light_value))
	d -= d % 2
	var s := d / float(_player_light.texture.get_width())
	_player_light.scale = Vector2(s, s)

func _get_closest_interactable_object() -> DungeonInteractable:
	var best: DungeonInteractable = null
	var best_d := INF
	for a in _interact_area.get_overlapping_areas():
		if a is not DungeonInteractable:
			continue
		if not (a as DungeonInteractable).can_interact(self):
			continue
		var d := global_position.distance_squared_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best

func _toggle_interact_hud() -> void:
	if _interact_hud:
		var can_open_door := GameState.get_keys() > 0 and _get_facing_key_door() != null
		_interact_hud.toggle(_get_closest_interactable_object() != null or can_open_door)

func _get_facing_key_door() -> Variant:
	if _dungeon == null:
		return null
	var probe := global_position + Vector2(_facing) * DOOR_PROBE_DISTANCE
	var cell := _dungeon.local_to_map(_dungeon.to_local(probe))
	var data := _dungeon.get_cell_tile_data(cell)
	if data == null or not data.get_custom_data("locked_door"):
		return null
	return cell

# Both halves are recorded as they are swapped: the pairing is known here and nowhere else, so
# DungeonManager._reapply_opened_doors() never has to re-derive it after a scene reload.
func _open_door(door: Vector2i) -> void:
	var level_key := _get_level_key()
	var source_id := _dungeon.get_cell_source_id(door)
	var data := _dungeon.get_cell_tile_data(door)
	_dungeon.set_cell(door, source_id, data.get_custom_data("opened_tile"))
	GameState.add_opened_door(level_key, door)
	var cell := door + _facing
	while true:
		data = _dungeon.get_cell_tile_data(cell)
		if data == null:
			return
		if data.get_custom_data("locked_door"):
			source_id = _dungeon.get_cell_source_id(cell)
			_dungeon.set_cell(cell, source_id, data.get_custom_data("opened_tile"))
			GameState.add_opened_door(level_key, cell)
			return
		cell += _facing

## Mirrors DungeonInteractable.get_level_key(): owner is the dungeon root.
func _get_level_key() -> String:
	return owner.scene_file_path if owner else ""
