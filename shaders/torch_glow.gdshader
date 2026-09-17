shader_type canvas_item;

// Torch halo for the digging minigame's surface band. Same contract as visibility.gdshader -
// decode the red channel to a shade index, write the index back as grey, never a final color -
// but mounted on a single sprite rather than on a screen wide container, so UV spans the
// texture and the lights are given in texture pixels.

// "Matrix" to say which color index should be for each palette index-color
// Each column represents a palette's color (darkest to lightest, left to right)
// The value in a column represents which color index should be used from the palette:
// 0 => Darkest color
// 1 => Dark color
// 2 => Light color
// 3 => Lightest color
// The rows represents the distance from the light point.
// Unlike visibility.gdshader the first row RAISES the indices: in the heart of the flame the
// wall has to turn the lit color of the palette instead of staying as it was authored.
const int RAMP[16] = {
	1, 2, 3, 3,		// Inside the flame: no black left, bricks lit
	0, 1, 2, 3,		// Identity: the art as it is drawn
	0, 1, 1, 2,		// Dimmed
	0, 0, 0, 0		// Past the light: flat dark
};

// Where the central band ends and where the halo ends, as multiples of the source radius
uniform float central_radius_ratio = 1.15;
uniform float outer_radius_ratio = 2.0;

// The size of the sprite's texture, in pixels
uniform vec2 viewport_size = vec2(160.0, 32.0);

// Light sources: xy is the position in texture pixels, z is the base radius.
uniform vec3 lights[4];
uniform int lights_count;

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	
	// No sources means no light system at all
	if (lights_count == 0) {
		COLOR = src;
	}
	else {
		
		// Work in texture pixels
		vec2 pixel_pos = UV * viewport_size;

		// Starts fully dark, each source can only brighten it
		int light_level = 3;

		for (int i = 0; i < lights_count; i++) {
			vec3 light = lights[i];
			vec2 light_pos = vec2(light.x, light.y);

			float dist = length(pixel_pos - light_pos);

			float inner_radius = light.z;
			float central_radius = inner_radius * central_radius_ratio;
			float outer_radius = inner_radius * outer_radius_ratio;

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

			// Best lit wins, so the order of the sources doesn't matter
			light_level = min(light_level, local_level);
		}

		// Assets are drawn in four fixed greys, same decoding as the palette pass
		int ramp_idx = int(clamp(round(src.r * 3.00), 0.0, 3.0));

		int idx = RAMP[light_level * 4 + ramp_idx];

		// Write the index back as grey: the palette pass downstream re-decodes it
		// the same way, so this shader must not output final colors
		float g = float(idx) / 3.00;
		COLOR = vec4(g, g, g, src.a);
	}
}
