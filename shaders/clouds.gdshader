shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

// UV goes 0→1 across the plane mesh. We scale it by plane_size to get
// world-scale coordinates — no varying needed, fragment runs at full resolution.
uniform float plane_size   : hint_range(100.0, 2000.0) = 600.0;
uniform float cloud_speed  : hint_range(0.0, 0.05) = 0.006;
uniform float cloud_scale  : hint_range(0.001, 0.05) = 0.007;
uniform float cloud_offset : hint_range(0.0, 10.0) = 0.0;
uniform float coverage     : hint_range(0.0, 1.0) = 0.38;
uniform vec4  cloud_color  : source_color = vec4(0.1, 0.11, 0.17, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i),             hash(i + vec2(1.0, 0.0)), f.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 6; i++) {
		v += a * vnoise(p);
		p  = p * 2.1 + vec2(1.9, 3.7);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	// UV * plane_size gives world-scale coordinates (centred doesn't matter for tiling)
	vec2 xz = UV * plane_size;
	float t  = TIME * cloud_speed + cloud_offset;

	vec2 uv1 = xz * cloud_scale + vec2(t, t * 0.4);
	vec2 uv2 = xz * cloud_scale * 1.6 + vec2(-t * 0.5, t * 0.9);

	float n     = fbm(uv1) * 0.6 + fbm(uv2) * 0.4;
	float alpha = smoothstep(coverage, coverage + 0.3, n) * cloud_color.a;

	// Fade out near mesh edges so the rectangle isn't visible
	vec2 edge = abs(UV - 0.5) * 2.0;
	float fade = 1.0 - smoothstep(0.72, 1.0, max(edge.x, edge.y));

	ALBEDO = cloud_color.rgb;
	ALPHA  = alpha * fade;
}
