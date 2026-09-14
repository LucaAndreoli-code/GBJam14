extends SubViewportContainer

@export_range(0.0, 10.0, 0.1) var flicker_speed: float = 4.0
@export_range(0.0, 2.0, 0.1) var flicker_amplitude: float = 0.5

const LIGHT_SOURCE_RADIUS_METHOD_SIGNATURE = "get_light_radius"

func _process(_delta: float) -> void:
	var light_sources := get_tree().get_nodes_in_group("light_sources")
	var lights: Array[Vector3] = []
	for source in light_sources:
		if source is not Node2D:
			push_warning("Found light source which is not Node2D: %s" % source.name)
			continue
		if not source.has_method(LIGHT_SOURCE_RADIUS_METHOD_SIGNATURE):
			push_warning("Found light source which has no %s: %s" % 
			[LIGHT_SOURCE_RADIUS_METHOD_SIGNATURE, source.name])
			continue
		var source_node := source as Node2D
		var canvas_xform := source.get_viewport().get_canvas_transform()
		var source_pos : Vector2 = (canvas_xform * source_node.global_position).round()
		var source_radius: float = source.call(LIGHT_SOURCE_RADIUS_METHOD_SIGNATURE)
		var source_radius_offset := float(source.get_instance_id() % 100 / 10.0)
		var source_radius_flickered := _calc_flickering(source_radius, source_radius_offset)
		lights.append(Vector3(source_pos.x, source_pos.y, source_radius_flickered))
	_apply(lights)

func _calc_flickering(radius: float, offset: float) -> float:
	var time := offset + Time.get_ticks_msec() / 1000.0
	return round(radius + sin(time * flicker_speed) * flicker_amplitude)

func _apply(lights: Array[Vector3]) -> void:
	if material == null:
		push_error("No material found on VisibilityContainer: visibility not applied")
		return
	material.set_shader_parameter("lights", lights)
	material.set_shader_parameter("lights_count", lights.size())
