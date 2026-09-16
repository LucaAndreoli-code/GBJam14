shader_type canvas_item;

// Flattens the sprite onto a single shade, keeping its alpha: the sonar shows the shape
// of what is buried, not the artwork. Default 2/3 is SRC_LIGHT, one step down from the
// brightest shade: it still reads over dirt, which the tileset paints in the two darkest
// shades only, without being the loudest thing on screen.
// Source shade, not a display color: palette.gdshader indexes on the red channel, so
// 2.0 / 3.0 rounds to index 2 and comes out as the palette's light color.
uniform float shade : hint_range(0.0, 1.0) = 0.6666667;

void fragment() {
	COLOR = vec4(vec3(shade), texture(TEXTURE, UV).a);
}
