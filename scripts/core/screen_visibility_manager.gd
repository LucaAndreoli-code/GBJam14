extends SubViewportContainer

func _process(_delta: float) -> void:
	var light_sources := get_tree().get_nodes_in_group("light_sources")
	if light_sources.size() == 0:
		return
	var source := light_sources[0] as Node2D
	if source == null:
		push_warning("Found light source which is not Node2D: %s" % light_sources[0].name)
		return
	_apply(source)

func _apply(source: Node2D) -> void:
	if material == null:
		push_error("No material found on VisibilityContainer: visibility not applied")
		return
	material.set_shader_parameter("light_pos", round(source.global_position))
