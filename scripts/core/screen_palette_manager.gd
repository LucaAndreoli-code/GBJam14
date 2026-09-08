extends SubViewportContainer

func _ready() -> void:
	Palette.palette_changed.connect(_on_palette_changed)
	_apply(Palette.get_active_palette())

func _on_palette_changed(colors: Array[Color]) -> void:
	_apply(colors)

func _apply(colors: Array[Color]) -> void:
	if material == null:
		push_error("No material found on PaletteContainer: palette not applied")
		return
	material.set_shader_parameter("col_lightest", colors[0])
	material.set_shader_parameter("col_light", colors[1])
	material.set_shader_parameter("col_dark", colors[2])
	material.set_shader_parameter("col_darkest", colors[3])
