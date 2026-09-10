shader_type canvas_item;

// Colors RAW values forming palette
uniform vec3 col_lightest : source_color = vec3(0.608, 0.737, 0.059);
uniform vec3 col_light : source_color = vec3(0.545, 0.675, 0.059);
uniform vec3 col_dark : source_color = vec3(0.188, 0.384, 0.188);
uniform vec3 col_darkest : source_color = vec3(0.059, 0.220, 0.059);

// Snaps the screen to four colors-only values
void fragment() {
	vec4 src = texture(TEXTURE, UV);
	int idx = int(round(src.r * 3.00));
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