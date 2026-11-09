shader_type canvas_item;
// Handheld LCD: thin dark grid between the source pixels. Use with nearest
// filtering at 3x scale or more.

uniform float grid_strength : hint_range(0.0, 1.0) = 0.32;

void fragment() {
	vec2 res = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 p = fract(UV * res);
	vec2 edge = smoothstep(vec2(0.0), vec2(0.18), p) * smoothstep(vec2(0.0), vec2(0.18), 1.0 - p);
	float g = mix(1.0 - grid_strength, 1.0, edge.x * edge.y);
	vec3 col = texture(TEXTURE, UV).rgb;
	COLOR = vec4(col * g * 1.06, 1.0);
}
