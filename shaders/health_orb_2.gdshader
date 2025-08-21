shader_type canvas_item;

// -------- Parameters --------
uniform float health_ratio : hint_range(0.0, 1.0, 0.001) = 1.0;
uniform float tilt : hint_range(-0.5, 0.5) = 0.0;
uniform float sloshing_amp : hint_range(0.0, 0.2, 0.001) = 0.06;
uniform float sloshing_speed : hint_range(0.0, 10.0, 0.01) = 2.0;

uniform float edge_softness : hint_range(0.0001, 0.05, 0.0001) = 0.01;
uniform float foam_thickness : hint_range(0.001, 0.08, 0.0005) = 0.02;
uniform float foam_speed : hint_range(0.0, 10.0, 0.01) = 1.2;

uniform float glass_rim_intensity : hint_range(0.0, 3.0) = 0.9;
uniform float glass_rim_width : hint_range(0.2, 6.0) = 2.5;

// NEW: move the rim highlight center (−1..1 in centered orb space)
uniform vec2 rim_offset = vec2(0.0, 0.0);

// Aspect ratio of the rect (width/height)
uniform float aspect = 1.0;

// Colors
uniform vec4 liquid_color : source_color = vec4(0.90, 0.08, 0.08, 1.0);
uniform vec4 foam_color   : source_color = vec4(1.0, 0.85, 0.85, 1.0);

// Optional textures
uniform sampler2D glass_normal : repeat_enable; // subtle warble
uniform bool use_glass_normal = false;
uniform vec2 glass_normal_tiling = vec2(3.0, 3.0);

uniform sampler2D liquid_noise : repeat_enable; // interior variation
uniform bool use_liquid_noise = false;
uniform vec2 liquid_noise_tiling = vec2(2.0, 2.0);
uniform vec2 liquid_noise_scroll = vec2(0.0, -0.05);
// NEW: intensity of color modulation from noise (0 subtle → 1 strong+)
uniform float liquid_noise_intensity : hint_range(0.0, 2.0, 0.01) = 0.2;

// -------- Helpers --------
float circle_mask(vec2 uv_centered, float soft) {
    // Keep the orb circular in non-square rects
    vec2 p = uv_centered * vec2(aspect, 1.0);
    float r = length(p);
    return smoothstep(1.0, 1.0 - soft, r); // 1 inside, 0 outside
}

float rim_highlight(vec2 uv_centered) {
    // Shift where we evaluate distance to the rim using rim_offset
    vec2 shifted = (uv_centered - rim_offset);
    float r = length(shifted * vec2(aspect, 1.0));
    float dist_to_edge = clamp(1.0 - r, 0.0, 1.0);
    float rim = pow(dist_to_edge, glass_rim_width) * glass_rim_intensity;
    return rim;
}

void fragment() {
    // Flip Y (UI has UV.y=0 at top)
    vec2 uv01 = vec2(UV.x, 1.0 - UV.y);   // 0..1
    vec2 uv_c = (uv01 - 0.5) * 2.0;       // centered −1..1
    float t = TIME;

    // Glass UV warble (optional)
    vec2 uv_warp = vec2(0.0);
    if (use_glass_normal) {
        vec2 n_uv = uv01 * glass_normal_tiling + vec2(t * 0.03, -t * 0.02);
        vec3 g = texture(glass_normal, n_uv).rgb;
        uv_warp = (g.rg - 0.5) * 0.02;
    }

    // Circular orb mask
    float orb_mask = circle_mask(uv_c, edge_softness);

    // Liquid surface (fill + slosh + tilt)
    float slosh = sin(t * sloshing_speed) * sloshing_amp;
    float fill = clamp(health_ratio + slosh + uv_c.x * 0.5 * tilt, 0.0, 1.0);

    // Compare pixel y to surface (remember we flipped UVs)
    float surface_y = fill;                 // top-down space
    float under_val = (surface_y - uv01.y);       // >0 means below surface
    float is_liquid = step(0.0, under_val);
    float liquid_soft = smoothstep(-edge_softness, edge_softness, under_val);

    // Foam line
    float band = clamp(liquid_soft - smoothstep(foam_thickness, foam_thickness + edge_softness, under_val), 0.0, 1.0);
    float foam_wave = 0.5 + 0.5 * sin(uv01.x * 25.0 + t * foam_speed * 3.14159);
    float foam_mask = band * foam_wave;

    // Liquid interior (aspect-correct noise)
    vec3 col_liquid = liquid_color.rgb;
    if (use_liquid_noise) {
        vec2 uv_iso = (uv01 - 0.5) * vec2(aspect, 1.0) + 0.5; // isotropic space
        vec2 ln_uv = uv_iso * liquid_noise_tiling + liquid_noise_scroll * t + uv_warp;
        float n = texture(liquid_noise, ln_uv).r;
        float noise_factor = 1.0 + (n - 0.5) * 2.0 * liquid_noise_intensity;
        col_liquid *= noise_factor;
    }
    col_liquid *= is_liquid;

    // Fake depth darkening
    float depth01 = uv01.y;              // 0 bottom … 1 top (after flip)
    float bottom_bias = 1.0 - depth01;   // 1 at bottom
    vec3 col_shaded = mix(col_liquid, col_liquid * 0.75, bottom_bias * 0.35);

    // Foam & rim
    vec3 col_foam = foam_color.rgb * foam_mask;
    float rim = rim_highlight(uv_c + uv_warp);
    vec3 col_rim = vec3(rim);

    // Composite & alpha
    vec3 rgb_in = (col_shaded + col_foam + col_rim) * orb_mask;
    float a_liquid = clamp(is_liquid * 0.9 + foam_mask * 0.9, 0.0, 1.0);
    float a = max(a_liquid, rim * 0.7) * orb_mask;

    COLOR = vec4(rgb_in, a);
}
