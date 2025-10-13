shader_type spatial;

render_mode cull_back, depth_draw_opaque;

// --- Textures ---
uniform sampler2D albedo_tex : filter_nearest; // nearest neighbor sampling
uniform sampler2D normal_tex : hint_normal, filter_nearest;  // optional normal map

// --- Water motion ---
uniform float amplitude : hint_range(0.0, 0.5) = 0.05;
uniform float frequency : hint_range(0.0, 4.0) = 0.6;
uniform float speed     : hint_range(0.0, 5.0) = 1.2;
uniform vec2  flow_dir  = vec2(1.0, 0.3);
uniform bool  scroll_uv = true;
uniform float uv_speed  : hint_range(0.0, 2.0) = 0.05;

// --- Look controls ---
uniform vec3  tint        = vec3(0.07, 0.25, 0.35);
uniform float roughness   : hint_range(0.0, 1.0) = 0.18;
uniform float metallic    : hint_range(0.0, 1.0) = 0.0;
uniform float fresnel_pow : hint_range(0.1, 10.0) = 3.0;
uniform float fresnel_str : hint_range(0.0, 2.0) = 0.5;
uniform vec3  fresnel_col = vec3(0.5, 0.8, 1.0);

vec2 dir_norm(vec2 d) {
	float len = max(length(d), 1e-4);
	return d / len;
}

void vertex() {
	vec2 d = dir_norm(flow_dir);
	float phase = dot(VERTEX.xz, d) * (TAU * frequency) + TIME * speed;
	float disp = sin(phase) * amplitude;
	VERTEX += NORMAL * disp;

	if (scroll_uv) {
		UV += d * (TIME * uv_speed);
	}
}

void fragment() {
	vec3 tex_color = texture(albedo_tex, UV).rgb;
	vec3 base_color = tex_color * tint;
	
	// Optional normal map (defaults to geometric normal if none)
	vec3 n = normalize(NORMAL);

	// Fresnel effect — brighter at grazing angles
	float fresnel = pow(1.0 - dot(n, VIEW), fresnel_pow) * fresnel_str;
	vec3 fresnel_effect = fresnel_col * fresnel;

	ALBEDO = base_color + fresnel_effect;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
