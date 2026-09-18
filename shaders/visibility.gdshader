shader_type canvas_item;

// "Matrix" to say which color index should be for each palette index-color
// Each column represents a palette's color (darkest to lightest, left to right)
// The value in a column represents which color index should be used from the palette:
// 0 => Darkest color
// 1 => Dark color
// 2 => Light color
// 3 => Lightest color
// The rows represents the distance from the light point
const int RAMP[16] = {
	0, 1, 2, 3, 	// Values near the torch (lightest)
	0, 1, 1, 2,
	0, 0, 0, 1,
	0, 0, 0, 0		// Values far from the torch (darkest)
};

// The size of the viewport, in pixels
uniform vec2 viewport_size = vec2(160.0, 144.0);

// Light sources: xy is the position in viewport pixels, z is the base radius.
uniform vec4 lights[4];
uniform int lights_count;
uniform vec2 ratios[4];

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	
	// No sources means no visibility system at all
	if (lights_count == 0) {
		COLOR = src;
	}
	else {
		// Work in viewport pixels
		vec2 pixel_pos = UV * viewport_size;

		// Starts fully dark, each source can only brighten it
		int light_level = 3;
		bool best_is_dark = false;

		for (int i = 0; i < lights_count; i++) {
			vec4 light = lights[i];
			vec2 ratio = ratios[i];
			
			vec2 light_pos = vec2(light.x, light.y);

			float dist = length(pixel_pos - light_pos);

			float inner_radius = light.z;
			float central_radius = inner_radius * ratio.x;
			float outer_radius = inner_radius * ratio.y;
			
			int local_level = 3;
			if (dist < inner_radius) {
				local_level = 0;
			}
			else if (dist < central_radius) {
				local_level = 1;
			}
			else if (dist < outer_radius) {
				local_level = 2;
			}
			
			bool is_dark = light.w > 0.5;

			// Best lit wins, so the order of the sources doesn't matter
			if (local_level < light_level || (local_level == light_level && best_is_dark && !is_dark)) {
				light_level = local_level;
				best_is_dark = is_dark;
			}
		}

		// Assets are drawn in four fixed greys, same decoding as the palette pass
		int ramp_idx = int(clamp(round(src.r * 3.00), 0.0, 3.0));

		int idx = RAMP[light_level * 4 + ramp_idx];
		
		if (best_is_dark) {
			idx = min(idx, 1);
		}

		// Write the index back as grey: the palette pass downstream re-decodes it
		// the same way, so this shader must not output final colors
		float g = float(idx) / 3.00;
		COLOR = vec4(g, g, g, src.a);
	}
}