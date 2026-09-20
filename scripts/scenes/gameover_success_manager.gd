extends Node2D

const LEVEL_SEL_SCENE_PATH: String = "res://scenes/game/level_selection.tscn"

@onready var _frame_title: Label = $Container/Label
@onready var _treasure_t: Control = $"Container/TreasuresTitle"
@onready var _treasure_i: Control = $"Container/TreasuresInfo"
@onready var _required_points_v_label: Label = $Container/PointsInfo/RequiredCollected/Value
@onready var _completion_rate_v_label: Label = $Container/PointsInfo/CompletionRate/Value
@onready var _treasure_s_v_label: Label = $Container/TreasuresInfo/Small/Value
@onready var _treasure_m_v_label: Label = $Container/TreasuresInfo/Medium/Value
@onready var _treasure_b_v_label: Label = $Container/TreasuresInfo/Big/Value

var _payload: Dictionary
var _is_gameover: bool = false
var _required_points: int = 0
var _collected_points: int = 0
var _treasure_s_collected: int = 0
var _treasure_m_collected: int = 0
var _treasure_b_collected: int = 0

var _is_input_enabled: bool = false

func _ready() -> void:
	GameState.set_paused(false)
	SignalBus.visibility_shader_toggled.emit(false)
	SceneManager.get_main_scene().toggle_bottom_bar(false)
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not _is_input_enabled:
		return
	if event.is_action_pressed("btn_a"):
		GameState.reset_run()
		SceneManager.go_to(_payload.get("scene_path"))
	elif event.is_action_pressed("btn_b"):
		SceneManager.go_to(LEVEL_SEL_SCENE_PATH)

func on_scene_entered(payload: Dictionary) -> void:
	_payload = payload
	_is_gameover = payload.get("is_gameover", false)
	if not _is_gameover:
		AudioManager.stop_music()
		AudioManager.play_sfx(AudioManager.winstinger, -2.0)
	_required_points = GameState.get_total_points()
	_collected_points = GameState.get_collected_points()
	var treasures := GameState.get_collected_treasures()
	for t in treasures.keys():
		match t.kind:
			TreasureInfo.Kind.SMALL:
				_treasure_s_collected += treasures[t]
			TreasureInfo.Kind.MEDIUM:
				_treasure_m_collected += treasures[t]
			TreasureInfo.Kind.BIG:
				_treasure_b_collected += treasures[t]
	_update_ui()
	await get_tree().create_timer(1.5).timeout
	_is_input_enabled = true

func _update_ui():
	var enough_points := _collected_points >= _required_points
	var completion_rate: float = (float(_collected_points) / float(_required_points)) * 100
	if _is_gameover:
		_frame_title.text = "LOST IN THE DARK"
		_treasure_t.visible = false
		_treasure_i.visible = false
	else:
		_frame_title.text = "CONTRACT DONE" if enough_points else "CONTRACT FAILED"
		_treasure_s_v_label.text = "%02d" % _treasure_s_collected
		_treasure_m_v_label.text = "%02d" % _treasure_m_collected
		_treasure_b_v_label.text = "%02d" % _treasure_b_collected
	_required_points_v_label.text = "%03d / %03d" % [_collected_points, _required_points]
	_completion_rate_v_label.text = "%02d %%" % completion_rate
	visible = true
