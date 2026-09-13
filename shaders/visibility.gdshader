shader_type canvas_item;

// "Matrix" to say which color index should be for each palette index-color
// Each column represents a palette's color (darkest to lightest, left to right)
// The value in a column represents which color index should be used from the palette:
// 0 => Darkest color
// 1 => Dark color
// 2 => Light color
// 3 => Lightest color
// The rows represents the distance from the light point
const int ramp[16] = {
	0, 2, 2, 3, 	// Values near the torch (lightest)
	0, 1, 1, 2,
	0, 0, 0, 1,
	0, 0, 0, 0		// Values far from the torch (darkest)
};

// The size of the viewport, in pixels
uniform vec2 viewport_size = vec2(160.0, 144.0);

// The lightning circles' radius
// The circle nearest to the torch
uniform float inner_circle_radius = 30.0;
// The central circle
uniform float medium_circle_radius = 50.0;
// The outer circle, close to complete dark
uniform float outer_circle_radius = 70.0;

uniform vec2 light_pos;

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	vec2 pixel_pos = UV * viewport_size;
	float dist = length(pixel_pos - light_pos);
	
	int light_level = 3;
	if (dist < inner_circle_radius) {
		light_level = 0;
	}
	else if (dist < medium_circle_radius) {
		light_level = 1;
	}
	else if (dist < outer_circle_radius) {
		light_level = 2;
	}
	
	int ramp_idx = int(clamp(round(src.r * 3.00), 0.0, 3.0));
	
	int idx = ramp[light_level * 4 + ramp_idx];
	
	float g = float(idx) / 3.00;
	COLOR = vec4(g, g, g, src.a);
}