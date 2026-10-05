shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		value += noise2(p) * amplitude;
		p = p * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return value;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float broad = fbm(p * 0.055);
	float detail = fbm(p * 0.42);
	float grains = hash21(floor(p * 38.0));

	vec3 warm = vec3(0.43, 0.285, 0.145);
	vec3 light_sand = vec3(0.69, 0.505, 0.285);
	vec3 base = mix(warm, light_sand, smoothstep(0.18, 0.88, broad));
	base *= 0.91 + detail * 0.15;
	base += (grains - 0.5) * 0.025;

	ALBEDO = base;
	ROUGHNESS = clamp(0.78 + detail * 0.13, 0.72, 0.96);
	METALLIC = 0.0;
	SPECULAR = 0.16;
}
