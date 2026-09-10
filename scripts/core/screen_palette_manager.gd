extends SubViewportContainer

func _ready() -> void:
	Palette.palette_changed.connect(_on_palette_changed)
	Palette.fade_step_changed.connect(_on_fade_step_changed)
	_apply(Palette.get_active_palette())
	_apply_fade_step(Palette.get_fade_step())

func _on_palette_changed(colors: Array[Color]) -> void:
	_apply(colors)

func _on_fade_step_changed(step: int) -> void:
	_apply_fade_step(step)

func _apply(colors: Array[Color]) -> void:
	if material == null:
		push_error("No material found on PaletteContainer: palette not applied")
		return
	material.set_shader_parameter("col_lightest", colors[0])
	material.set_shader_parameter("col_light", colors[1])
	material.set_shader_parameter("col_dark", colors[2])
	material.set_shader_parameter("col_darkest", colors[3])

func _apply_fade_step(step: int) -> void:
	if material == null:
		push_error("No material found on PaletteContainer: fading step not applied")
		return
	material.set_shader_parameter("fade_step", step)
