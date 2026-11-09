shader_type canvas_item;
// Sharp bilinear: big pixels stay crisp, only their borders are blended, so
// any (non whole-number) scale looks even. Needs linear filtering.

void fragment() {
	vec2 res = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 texel = UV * res;
	vec2 scale = max(vec2(1.0), 1.0 / max(fwidth(texel), vec2(1e-5)));
	vec2 base = floor(texel);
	vec2 center = texel - base - 0.5;
	vec2 range = 0.5 - 0.5 / scale;
	vec2 f = (center - clamp(center, -range, range)) * scale + 0.5;
	COLOR = vec4(texture(TEXTURE, (base + f) / res).rgb, 1.0);
}
