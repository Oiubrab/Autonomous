shader_type spatial;
render_mode depth_draw_opaque, diffuse_lambert, specular_schlick_ggx, cull_disabled;

// Swamp ground — triplanar world-space sampling eliminates all UV seams.
// The texture coordinates come from world XZ position, not mesh UVs,
// so tiling is perfectly continuous with no grid artifacts.

uniform sampler2D tex_mud  : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_rock : source_color, filter_linear_mipmap, repeat_enable;
uniform float tile_size : hint_range(1.0, 50.0) = 22.0; // metres per texture repeat

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv_a = v_world_pos.xz / tile_size;
	vec2 uv_b = v_world_pos.xz / (tile_size * 1.6); // different scale for rock avoids alignment

	vec3 mud_col  = texture(tex_mud,  uv_a).rgb;
	vec3 rock_col = texture(tex_rock, uv_b).rgb;

	// Slope blend: steep = rock, flat = mud
	float slope = 1.0 - abs(NORMAL.y);
	float blend = smoothstep(0.15, 0.55, slope);

	ALBEDO    = mix(mud_col, rock_col, blend);
	ROUGHNESS = mix(0.92, 0.78, blend);
	METALLIC  = 0.0;
}
