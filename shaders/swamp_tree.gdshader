shader_type spatial;

// Swamp tree sway shader — vertex displacement only.
// Does NOT touch fragment/albedo/emission so the original GLB textures
// from Meshy render unmodified. Sway is height-weighted so trunks are
// nearly still while the canopy moves broadly.

uniform float sway_amount : hint_range(0.0, 0.3) = 0.07;
uniform float sway_speed  : hint_range(0.0, 4.0) = 0.6;
uniform float sway_phase  : hint_range(0.0, 6.28) = 0.0;

void vertex() {
    float world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
    float h = clamp(world_y / 4.0, 0.0, 1.0);

    float t = TIME * sway_speed + sway_phase;
    float wave_x = sin(t * 1.0 + VERTEX.z * 0.3) * 0.6
                 + sin(t * 1.7 + VERTEX.z * 0.5) * 0.4;
    float wave_z = cos(t * 0.8 + VERTEX.x * 0.3) * 0.6
                 + cos(t * 1.3 + VERTEX.x * 0.4) * 0.4;

    float amp = sway_amount * h * h;
    VERTEX.x += wave_x * amp;
    VERTEX.z += wave_z * amp;
}
