shader_type spatial;
// was: render_mode blend_mix, depth_prepass_alpha, cull_back;
render_mode depth_draw_opaque, cull_back; // opaque pass so it's in SCREEN_TEXTURE

uniform sampler2D road_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D edge_noise_tex : source_color, repeat_enable;

// Separate tiling for X and Y
uniform float uv_scale_x = 1.0;
uniform float uv_scale_y = 1.0;

// Tint & roughness
uniform vec3  tint = vec3(1.0);
uniform float roughness_override : hint_range(0.0,1.0) = 0.9;

// Edge controls
uniform float edge_width_uv : hint_range(0.0, 0.5) = 0.08;
uniform float edge_softness = 0.5;
uniform float edge_noise_scale = 2.0;
uniform float edge_noise_strength = 0.6;
uniform float lift_mm = 2.0;

// Cutout controls
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5; // overall feather “thickness”
uniform bool  use_dither = true;

// 4×4 Bayer matrix for ordered dithering (soft-looking cutout in opaque pass)
float bayer(vec2 fragcoord) {
	int x = int(mod(fragcoord.x, 4.0));
	int y = int(mod(fragcoord.y, 4.0));
	int m[16] = int[16](
		 0,  8,  2, 10,
		12,  4, 14,  6,
		 3, 11,  1,  9,
		15,  7, 13,  5
	);
	return (float(m[y * 4 + x]) + 0.5) / 16.0;
}

// Lift slightly above ground to avoid z-fighting
void vertex() {
	VERTEX += NORMAL * (lift_mm * 0.001);
}

// Feathers all 4 edges, even with tiled UVs
float edge_alpha_mask(vec2 uv_raw) {
	vec2 uv01 = fract(uv_raw);
	float d = min(min(uv01.x, 1.0 - uv01.x), min(uv01.y, 1.0 - uv01.y));
	float n = texture(edge_noise_tex, uv_raw * edge_noise_scale).r * 2.0 - 1.0;
	float noisy_width = max(0.0001, edge_width_uv * (1.0 + n * edge_noise_strength));
	return smoothstep(0.0, noisy_width * (1.0 + edge_softness), d);
}

void fragment() {
	// Split scaling
	vec2 uv_tex = vec2(UV.x * uv_scale_x, UV.y * uv_scale_y);
	vec3 base = texture(road_tex, uv_tex).rgb * tint;

	// Feathered alpha mask 0..1 at the quad edges
	float a = edge_alpha_mask(UV);

	// --- OPAQUE CUTOUT: discard instead of blending ---
	if (use_dither) {
		// Ordered dither makes the edge look soft while remaining in opaque pass
		if (a < bayer(FRAGCOORD.xy) * alpha_cut) {
			discard;
		}
	} else {
		if (a < alpha_cut) {
			discard;
		}
	}

	ALBEDO    = base;
	ROUGHNESS = roughness_override;
	METALLIC  = 0.0;
	// no ALPHA in opaque mode
}