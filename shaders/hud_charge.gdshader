shader_type canvas_item;

// Vertical charge meter drawn straight onto an icon: the rows above the fill level drop
// `shade_drop` steps down the 4 shade ramp, so the icon reads as spent until the fill
// climbs back over them.
// It works on the shade INDEX rather than on the raw color on purpose: the art sits at
// 0.83 and 0.88, so any plain multiply would collapse its two bright shades into one and
// flatten the icon into a silhouette.
// The output is still source shades, so palette.gdshader remaps it afterwards like
// everything else on screen.

// 0 right after the icon is spent, 1 when it is fully charged
uniform float charge : hint_range(0.0, 1.0) = 1.0;
// How many shades the uncharged part drops. 1 dims it, 3 blacks it out.
uniform int shade_drop : hint_range(0, 3) = 1;
// The icon can be a region of a shared atlas, and then UV spans that region inside the
// atlas rather than 0..1: these map the region's vertical span back onto 0..1 so the fill
// level means the same thing either way. The defaults cover a whole texture.
uniform float region_v_min = 0.0;
uniform float region_v_size = 1.0;

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	// Sampling stays on the raw UV: only the threshold needs the region's own coordinate.
	float v = (UV.y - region_v_min) / region_v_size;
	// v is 0 at the top of the icon, and the fill rises from the bottom, so what is left
	// empty is whatever sits above it.
	if (v < 1.0 - charge) {
		int idx = max(int(round(src.r * 3.0)) - shade_drop, 0);
		src.rgb = vec3(float(idx) / 3.0);
	}
	COLOR = src;
}
