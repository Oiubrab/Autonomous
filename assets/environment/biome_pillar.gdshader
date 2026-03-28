shader_type spatial;

uniform sampler2D albedo_texture : source_color, hint_default_white;

// UV tiling multiplier — default (1,1) preserves existing GLB asset behaviour.
// Set to match the material's uv1_scale for tiled flat surfaces (walls, floor).
uniform vec2 uv_scale = vec2(1.0, 1.0);

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
	vec4 tex = texture(albedo_texture, UV * uv_scale);
	vec3 col = tex.rgb;

	// Identify bioluminescent/organic pixels: any saturated (non-grey) surface that isn't too dark.
	// Using chroma instead of green-dominance so it works across all Meshy asset colour palettes.
	float chroma = max(col.r, max(col.g, col.b)) - min(col.r, min(col.g, col.b));
	float brightness = dot(col, vec3(0.333));
	float organic = smoothstep(0.05, 0.22, chroma) * smoothstep(0.1, 0.45, brightness);

	// Spatial pattern — breaks up the shift so it ripples rather than floods uniformly.
	float spatial = sin(UV.y * 10.0 + UV.x * 5.0) * 0.4;

	// Time-driven hue angle: cycles through roughly green → cyan → blue → violet → back.
	float t = TIME * shift_speed + phase_offset + spatial;
	float hue_angle = sin(t) * 2.8; // ±2.8 rad (~160°) reaches red/violet at the extremes

	vec3 shifted = hue_rotate(col, hue_angle);

	// Emission pulse — slightly faster than the hue shift for visual interest.
	float pulse = 0.55 + 0.45 * sin(t * 1.6);

	ALBEDO     = mix(col, shifted, organic);
	EMISSION   = shifted * organic * emission_strength * pulse;
	ROUGHNESS  = mix(0.88, 0.18, organic);
	METALLIC   = mix(0.28, 0.0,  organic);
}
