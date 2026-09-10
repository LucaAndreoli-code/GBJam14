shader_type canvas_item;

// Colors RAW values forming palette
uniform vec3 col_lightest : source_color = vec3(0.608, 0.737, 0.059);
uniform vec3 col_light : source_color = vec3(0.545, 0.675, 0.059);
uniform vec3 col_dark : source_color = vec3(0.188, 0.384, 0.188);
uniform vec3 col_darkest : source_color = vec3(0.059, 0.220, 0.059);

// Fading step used in scenes' transitions
uniform int fade_step : hint_range(-3, 3) = 0;

// Snaps the screen to four colors-only values
void fragment() {
	vec4 src = texture(TEXTURE, UV);
	// Calculates the color index using SOURCE RAW value and the fading step
	int idx = clamp(int(round(src.r * 3.00)) + fade_step, 0, 3);
	vec3 out_col = col_darkest;
	if (idx == 1) {
		out_col = col_dark;
	} else if (idx == 2) {
		out_col = col_light;
	} else if (idx == 3) {
		out_col = col_lightest;
	}
	COLOR = vec4(out_col, src.a);
}