shader_type spatial;

uniform sampler2D albedo_texture : source_color, hint_default_white;

// Speed of the colour cycle. Varied per instance via phase_offset.
uniform float shift_speed : hint_range(0.05, 1.0) = 0.3;

// Per-instance random offset so pillars don't pulse in sync.
uniform float phase_offset : hint_range(0.0, 6.28) = 0.0;

// How intensely the organic parts glow.
uniform float emission_strength : hint_range(0.0, 4.0) = 2.0;

// Hue rotation using Rodrigues' formula around the (1,1,1) axis.
// This keeps luminance roughly constant while rotating through the spectrum.
vec3 hue_rotate(vec3 col, float angle) {
	float s = sin(angle);
	float c = cos(angle);
	vec3 k = vec3(0.57735); // normalize(vec3(1))
	return col * c + cross(k, col) * s + k * dot(k, col) * (1.0 - c);
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	vec3 col = tex.rgb;

	// Identify bioluminescent/organic pixels: green-dominant and not too dark.
	float green_dom = col.g - max(col.r, col.b);
	float brightness = dot(col, vec3(0.333));
	float organic = smoothstep(0.08, 0.35, green_dom) * smoothstep(0.1, 0.45, brightness);

	// Spatial pattern — breaks up the shift so it ripples rather than floods uniformly.
	float spatial = sin(UV.y * 10.0 + UV.x * 5.0) * 0.4;

	// Time-driven hue angle: cycles through roughly green → cyan → blue → violet → back.
	float t = TIME * shift_speed + phase_offset + spatial;
	float hue_angle = sin(t) * 1.4; // ±1.4 rad covers a wide colour arc

	vec3 shifted = hue_rotate(col, hue_angle);

	// Emission pulse — slightly faster than the hue shift for visual interest.
	float pulse = 0.55 + 0.45 * sin(t * 1.6);

	ALBEDO     = mix(col, shifted, organic);
	EMISSION   = shifted * organic * emission_strength * pulse;
	ROUGHNESS  = mix(0.88, 0.18, organic);
	METALLIC   = mix(0.28, 0.0,  organic);
}
