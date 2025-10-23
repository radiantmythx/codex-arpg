shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_opaque;

// ---- Texture ----
uniform sampler2D overlay_tex : source_color, filter_linear_mipmap, repeat_enable;

// If your texture has no alpha, set to 1.0 to use luma as the mask.
uniform float use_luma_as_alpha : hint_range(0.0, 1.0) = 0.0;

// If 1.0, multiply color by the texture RGB; if 0.0, ignore RGB (use tex only as a mask).
uniform float use_texture_rgb   : hint_range(0.0, 1.0) = 0.0;

// ---- UV transform ----
uniform vec2  uv_scale  = vec2(1.0, 1.0);
uniform vec2  uv_scroll = vec2(0.0, 0.6);
uniform float uv_rotate = 0.0; // radians

// ---- HDR color control ----
// Set values > 1.0 for strong bloom (e.g., 8, 3, 1). Alpha unused.
uniform vec4 emission_color : source_color = vec4(1.0, 0.55, 0.15, 1.0);

// Direct scalar gain on top of color
uniform float emission_intensity = 1.0;

// Pulse settings
uniform float pulse_speed   = 2.0;                   // radians/sec
uniform float pulse_amount  : hint_range(0.0, 8.0) = 2.5;

// Overall overlay opacity (visual add; does not clamp emission energy)
uniform float overlay_alpha : hint_range(0.0, 1.0) = 0.9;

vec2 rot2(vec2 p, float a) {
    float s = sin(a), c = cos(a);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

void fragment() {
    // UV transform
    vec2 uv = UV;
    uv = (uv - 0.5) * uv_scale;
    uv = rot2(uv, uv_rotate);
    uv += 0.5 + uv_scroll * TIME;

    vec4 tex = texture(overlay_tex, uv);

    // Mask
    float a_tex = tex.a;
    float luma  = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
    float mask  = mix(a_tex, luma, clamp(use_luma_as_alpha, 0.0, 1.0));

    // Optional multiply by texture color
    vec3 src_rgb = mix(vec3(1.0), tex.rgb, clamp(use_texture_rgb, 0.0, 1.0));

    // Pulse: 1.0 .. (1.0 + pulse_amount)
    float pulse = 1.0 + (0.5 + 0.5 * sin(TIME * pulse_speed)) * pulse_amount;

    // Final color energy (visible *and* bloom)
    vec3 energy = emission_color.rgb * src_rgb * (emission_intensity * pulse);

    // Show color even if Glow is off:
    ALBEDO   = energy;
    EMISSION = energy;

    // Additive overlay opacity
    ALPHA = clamp(mask * overlay_alpha, 0.0, 1.0);
}