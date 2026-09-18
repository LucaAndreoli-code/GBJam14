class_name DigSurface
extends Sprite2D

## The wall band above the pit of the digging minigame.
## It is the only thing that reacts to the torch: the field below has to stay flat and readable,
## so the full screen pass (VisibilityContainer) is switched off here and the darkness lives in a
## material mounted on this sprite alone.

## Dedicated to this band: same contract as the dungeon's visibility.gdshader, but its ramp
## brightens near the flame, and "viewport_size" is the texture size because the lights are given
## in texture pixels rather than viewport pixels
const TORCH_GLOW_SHADER: Shader = preload("res://shaders/torch_glow.gdshader")

## The shader's light array is a fixed vec3[4]: anything past that reads out of bounds
const MAX_LIGHTS := 4

const LIGHT_SOURCE_RADIUS_METHOD_SIGNATURE = "get_light_radius"

## Flicker of the halo, matching VisibilityContainer in main.tscn
@export_range(0.0, 10.0, 0.1) var flicker_speed: float = 5.5
@export_range(0.0, 2.0, 0.1) var flicker_amplitude: float = 0.6
## Where the brightest core ends, as a fraction of the source radius: it sits inside the
## inner band, so it stays below 1.0 while the two ratios below stay above it.
@export_range(0.0, 1.0, 0.05) var core_radius_ratio: float = 0.5
## Where the central band ends and where the halo ends, as multiples of the source radius.
## The defaults reproduce the dungeon's falloff; the reference art closes the dark ring nearer 1.5.
@export_range(1.0, 3.0, 0.05) var central_radius_ratio: float = 1.15
@export_range(1.0, 8.0, 0.05) var outer_radius_ratio: float = 2.0

var _material: ShaderMaterial

func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = TORCH_GLOW_SHADER
	_material.set_shader_parameter("viewport_size", Vector2(texture.get_size()))
	# Constant at runtime, so they are pushed once rather than every frame
	_material.set_shader_parameter("core_radius_ratio", core_radius_ratio)
	_material.set_shader_parameter("central_radius_ratio", central_radius_ratio)
	_material.set_shader_parameter("outer_radius_ratio", outer_radius_ratio)
	material = _material

func _process(_delta: float) -> void:
	var lights: Array[Vector3] = []
	for source in get_tree().get_nodes_in_group(Groups.LIGHT_SOURCES):
		if source is not Node2D:
			continue
		if not source.has_method(LIGHT_SOURCE_RADIUS_METHOD_SIGNATURE):
			continue
		var source_pos := _to_texture_pixels((source as Node2D).global_position)
		# Only the inner radius is read here: the band multipliers in y and z are per source for
		# ScreenVisibilityManager, while torch_glow.gdshader takes its own three as scalar uniforms.
		var source_radius: Vector3 = source.call(LIGHT_SOURCE_RADIUS_METHOD_SIGNATURE)
		# Offset per instance, so two torches never pulse in unison
		var source_offset := float(source.get_instance_id() % 100 / 10.0)
		lights.append(Vector3(source_pos.x, source_pos.y,
				_calc_flickering(source_radius.x, source_offset)))
		if lights.size() == MAX_LIGHTS:
			break
	_material.set_shader_parameter("lights", lights)
	_material.set_shader_parameter("lights_count", lights.size())

# The shader works off UV, so the origin is the top-left corner of the texture, not the node
func _to_texture_pixels(world_position: Vector2) -> Vector2:
	var local := to_local(world_position) - offset
	if centered:
		local += Vector2(texture.get_size()) * 0.5
	return local.round()

# Copy of ScreenVisibilityManager._calc_flickering(): rounded, so the edge never crawls by
# sub-pixels
func _calc_flickering(radius: float, offset_seconds: float) -> float:
	var time := offset_seconds + Time.get_ticks_msec() / 1000.0
	return round(radius + sin(time * flicker_speed) * flicker_amplitude)
