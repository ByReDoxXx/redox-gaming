shader_type canvas_item;
// CRT television look: a dark gap between source lines, an RGB aperture
// grille in screen pixels and a soft vignette. Use with nearest filtering.

uniform float scanline_strength : hint_range(0.0, 1.0) = 0.4;
uniform float mask_strength : hint_range(0.0, 1.0) = 0.18;
uniform float brightness = 1.2;

void fragment() {
	vec2 res = 1.0 / TEXTURE_PIXEL_SIZE;
	vec3 col = texture(TEXTURE, UV).rgb;
	float line = fract(UV.y * res.y);
	float d = abs(line - 0.5) * 2.0;
	col *= 1.0 - scanline_strength * d * d;
	float m = mod(FRAGCOORD.x, 3.0);
	vec3 mask = vec3(1.0 - mask_strength);
	if (m < 1.0) { mask.r = 1.0; } else if (m < 2.0) { mask.g = 1.0; } else { mask.b = 1.0; }
	col *= mask * brightness;
	vec2 v = UV * (1.0 - UV.yx);
	col *= pow(clamp(v.x * v.y * 18.0, 0.0, 1.0), 0.15);
	COLOR = vec4(col, 1.0);
}
