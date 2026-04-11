shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

// Swamp water shader.
// - Gentle vertex displacement for slow wave motion
// - Dark, slightly reflective surface
// - Bioluminescent glow pulses from below — soft teal/amber bloom at surface edges
// - Scrolling normal map for subtle surface detail

uniform sampler2D normal_map_a : hint_normal, repeat_enable;
uniform sampler2D normal_map_b : hint_normal, repeat_enable;

uniform vec4  water_color      : source_color  = vec4(0.01, 0.03, 0.05, 0.95);
uniform vec4  bio_glow_color   : source_color  = vec4(0.15, 0.7, 0.5, 1.0);
uniform float bio_glow_strength: hint_range(0.0, 2.0) = 0.04;
uniform float wave_height      : hint_range(0.0, 0.3) = 0.06;
uniform float wave_speed       : hint_range(0.0, 2.0) = 0.25;
uniform float normal_scale     : hint_range(0.0, 4.0) = 1.5;
uniform float roughness        : hint_range(0.0, 1.0) = 0.12;
uniform float uv_scale         : hint_range(0.1, 8.0) = 2.5;

void vertex() {
    float t = TIME * wave_speed;
    // Two overlapping wave directions
    float wave = sin(VERTEX.x * 0.4 + t) * 0.6
               + sin(VERTEX.z * 0.35 + t * 0.8) * 0.4
               + sin((VERTEX.x + VERTEX.z) * 0.25 + t * 1.1) * 0.3;
    VERTEX.y += wave * wave_height;
}

void fragment() {
    vec2 uv = UV * uv_scale;

    // Two scrolling normal maps at different speeds and angles
    vec2 uv_a = uv + vec2(TIME * 0.03,  TIME * 0.02);
    vec2 uv_b = uv + vec2(-TIME * 0.02, TIME * 0.035);
    vec3 n_a = texture(normal_map_a, uv_a).rgb;
    vec3 n_b = texture(normal_map_b, uv_b).rgb;
    NORMAL_MAP = normalize(n_a + n_b - vec3(1.0));
    NORMAL_MAP_DEPTH = normal_scale;

    ALBEDO    = water_color.rgb;
    ALPHA     = water_color.a;

    // Bioluminescent pulse — slow drift
    float pulse = sin(TIME * 0.4) * 0.15 + 0.85;
    EMISSION  = bio_glow_color.rgb * bio_glow_strength * pulse;

    ROUGHNESS  = roughness;
    METALLIC   = 0.05;
    SPECULAR   = 0.8;
}
