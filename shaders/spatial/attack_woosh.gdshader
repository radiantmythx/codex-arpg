shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back, fog_disabled;

uniform float intensity : hint_range(0.0, 1.0) = 0.7;       // overall effect strength
uniform float fade      : hint_range(0.0, 1.0) = 1.0;       // animate this down to 0
uniform float rim_strength : hint_range(0.0, 3.0) = 1.2;    // outline “glow” on edges
uniform vec4  tint : source_color = vec4(0.85, 0.95, 1.0, 0.06); // subtle tint & mix

// Refraction
uniform float refract_strength : hint_range(0.0, 0.05) = 0.012; // how far to offset screen UVs
uniform float noise_scale = 8.0;
uniform float time_scale  = 1.1;

// Optional “woosh” pulse (0..1) you can animate. Expands the cylinder’s XZ a hair.
uniform float woosh_pulse   : hint_range(0.0, 1.0) = 0.0;
uniform float woosh_amount  : hint_range(0.0, 0.12) = 0.05;

// Noise source for jittered refraction
uniform sampler2D noise_tex;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest_mipmap;

void vertex() {
    // Slight radial swell for a whoosh feel (kept tiny so it doesn’t feel gamey)
    vec3 v = VERTEX;
    float k = 1.0 + woosh_amount * woosh_pulse;
    v.xz *= k;
    VERTEX = v;
}

void fragment() {
    vec2 n_uv  = UV * noise_scale + vec2(TIME * time_scale, 0.0);
    float nval = texture(noise_tex, n_uv).r;
    float n01  = nval * 2.0 - 1.0;

    vec3 n = normalize(NORMAL);
    vec2 offset = (n.xy * 0.5 + n01 * 0.5) * refract_strength * intensity * fade;

    vec3 bg = textureLod(SCREEN_TEXTURE, SCREEN_UV + offset, 0.0).rgb;

    // ✅ Correct Fresnel formula
    vec3 view_dir = normalize(VIEW);
    float fres = pow(1.0 - dot(n, view_dir), 3.0);
    vec3 rim   = fres * rim_strength * tint.rgb;

    ALBEDO   = mix(bg, tint.rgb, tint.a);
    EMISSION = rim * intensity * fade;
    ALPHA    = clamp(intensity * fade * 0.5, 0.0, 0.5);
}
