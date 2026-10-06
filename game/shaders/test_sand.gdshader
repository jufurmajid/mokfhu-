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
	for (int i = 0; i < 4; i++) {
		value += noise2(p) * amplitude;
		p = p * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return value;
}

void vertex() {
	float dune = sin(VERTEX.x * 0.085) * 0.045 + cos(VERTEX.z * 0.071) * 0.035;
	VERTEX.y += dune;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float broad = fbm(p * 0.045);
	float detail = fbm(p * 0.33);
	float grains = hash21(floor(p * 30.0));

	vec3 shade_sand = vec3(0.38, 0.285, 0.18);
	vec3 sun_sand = vec3(0.62, 0.49, 0.32);
	vec3 base = mix(shade_sand, sun_sand, smoothstep(0.18, 0.88, broad));
	base *= 0.94 + detail * 0.10;
	base += (grains - 0.5) * 0.018;

	ALBEDO = base;
	ROUGHNESS = clamp(0.84 + detail * 0.10, 0.78, 0.96);
	METALLIC = 0.0;
	SPECULAR = 0.12;
}
