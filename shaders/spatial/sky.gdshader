shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled;

//
// ► Inside-facing sky dome with controlled luminance
// ► Uses ALBEDO (not EMISSION) so bloom doesn’t go nuclear
//

// -------- Colors & shaping --------
uniform vec3 zenith_color   : source_color = vec3(0.08, 0.16, 0.35); // deep blue
uniform vec3 horizon_color  : source_color = vec3(0.35, 0.55, 0.85); // bright but not white
uniform float horizon_boost : hint_range(0.0, 1.5) = 0.35;            // extra haze at horizon
uniform float gradient_power: hint_range(0.2, 4.0) = 1.4;             // steepness of sky gradient

// -------- Sun disk (soft) --------
// Sun direction in *world* space (normalize this in your script if you set it there)
uniform vec3 sun_dir = vec3(0.0, 0.6, 0.8);    // where the sun sits in the sky
uniform float sun_disk_deg : hint_range(0.1, 10.0) = 2.0;
uniform float sun_soft_deg : hint_range(0.05, 10.0) = 1.8;  // falloff around disk
uniform vec3  sun_color    : source_color = vec3(1.0, 0.92, 0.78);   // warm
uniform float sun_luma     : hint_range(0.0, 2.0) = 0.45;            // keep modest; bloom will carry

// -------- Halo / anisotropic forward scatter --------
uniform float halo_strength : hint_range(0.0, 1.5) = 0.35;
uniform float halo_power    : hint_range(0.5, 8.0) = 3.0;

// -------- Overall luminance trim (post-bloom friendly) --------
uniform float base_luma     : hint_range(0.0, 2.0) = 0.85;

// -------- Subtle high-altitude darkening (mimics “depth”) --------
uniform float zenith_darken : hint_range(0.0, 1.0) = 0.2;

// Pass world position from vertex to fragment
varying vec3 v_world_pos;

void vertex() {
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Helpers
float radians_from_deg(float d){ return d * 0.017453292519943295; }

void fragment() {
    // Direction from camera to this fragment (on the inner sphere)
    vec3 camera_pos = (INV_VIEW_MATRIX[3]).xyz;
	vec3 to_frag = normalize(v_world_pos - camera_pos);

    // World up gives us altitude to blend zenith↔horizon
    float up_dot = clamp(dot(normalize(vec3(0.0, 1.0, 0.0)), to_frag), 0.0, 1.0);
    // Invert so 0 = zenith, 1 = horizon, then apply shaping
    float h = pow(1.0 - up_dot, gradient_power);

    // Base gradient
    vec3 sky = mix(zenith_color, horizon_color, h);

    // Add a little extra near the horizon (haze) without going to white
    sky = mix(sky, horizon_color, horizon_boost * smoothstep(0.6, 1.0, h));

    // Subtle darkening overhead for depth
    sky *= (1.0 - zenith_darken * smoothstep(0.0, 0.7, up_dot));

    // Sun disk (soft)
    vec3 sdir = normalize(sun_dir);
    float ang = acos(clamp(dot(to_frag, sdir), -1.0, 1.0)); // radians
    float disk = smoothstep(radians_from_deg(sun_disk_deg + sun_soft_deg),
                            radians_from_deg(sun_disk_deg),
                            ang);

    // Halo / forward scatter (strongest looking toward sun)
    float view_sun = clamp(dot(to_frag, sdir), 0.0, 1.0);
    float halo = pow(view_sun, halo_power) * halo_strength;

    // Compose with careful luminance — don’t use EMISSION here
    vec3 color = sky * base_luma
               + sun_color * (sun_luma * disk)
               + sun_color * (sun_luma * 0.5 * halo);

    ALBEDO = clamp(color, 0.0, 1.0);
    ALPHA = 1.0;
}
