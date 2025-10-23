shader_type canvas_item;

// ====== LOOK CONTROLS ======
uniform float contrast        : hint_range(0.5, 2.0) = 1.08; // gentle pop
uniform float saturation      : hint_range(0.0, 2.5) = 1.35; // 2003-colorful
uniform float vibrance        : hint_range(0.0, 1.0) = 0.25; // boosts muted colors more
uniform float gamma_adjust    : hint_range(0.5, 1.5) = 1.00; // leave at 1 unless you want slight gamma

// Optional “crunch”
uniform float posterize_steps : hint_range(0.0, 64.0) = 0.0; // 0 = off, try 16 for subtle banding

// ====== BLOOM CONTROLS ======
uniform float bloom_threshold : hint_range(0.0, 2.0) = 0.75; // what counts as "bright"
uniform float bloom_knee      : hint_range(0.0, 1.0) = 0.4;  // softness near threshold
uniform float bloom_intensity : hint_range(0.0, 3.0) = 1.4;  // how strong the bloom adds back
uniform float bloom_radius_px : hint_range(0.5, 8.0) = 2.5;  // radius in pixels (scaled by resolution)
uniform int   bloom_rings     = 3;                           // number of sampling rings (1–4)

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear_mipmap;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 sample_scene(vec2 uv) {
    return texture(SCREEN_TEXTURE, uv).rgb;
}

// Soft threshold extraction (UE-style knee)
vec3 extract_bright(vec3 c) {
    float l = dot(c, LUMA);
    float k = bloom_threshold * bloom_knee + 1e-6;
    float soft = clamp((l - bloom_threshold + k) / (2.0 * k), 0.0, 1.0);
    float cutoff = max(l - bloom_threshold, 0.0);
    float w = (cutoff + soft) / max(l, 1e-6);
    return c * clamp(w, 0.0, 1.0);
}

// Cheap multi-ring radial blur of the bright parts
vec3 bloom_blur(vec2 uv, vec2 px) {
    vec3 acc = vec3(0.0);
    float weight_sum = 0.0;

    // Predefined directions (8 dirs)
    vec2 dirs[8] = vec2[8](
        vec2( 1.0,  0.0),
        vec2( 0.0,  1.0),
        vec2(-1.0,  0.0),
        vec2( 0.0, -1.0),
        vec2( 0.7071,  0.7071),
        vec2(-0.7071,  0.7071),
        vec2( 0.7071, -0.7071),
        vec2(-0.7071, -0.7071)
    );

    int rings = clamp(bloom_rings, 1, 4);

    for (int r = 1; r <= rings; r++) {
        float ring = float(r);
        float ring_weight = 1.0 / ring; // farther rings contribute a bit less
        vec2 offset = px * bloom_radius_px * ring;

        // center tap (bright prepass helps avoid over-softening)
        vec3 b_center = extract_bright(sample_scene(uv));
        acc += b_center * ring_weight;
        weight_sum += ring_weight;

        // 8 directions
        for (int i = 0; i < 8; i++) {
            vec2 o = dirs[i] * offset;
            vec3 b1 = extract_bright(sample_scene(uv + o));
            vec3 b2 = extract_bright(sample_scene(uv - o));
            acc += (b1 + b2) * (0.5 * ring_weight);
            weight_sum += ring_weight;
        }
    }
    return acc / max(weight_sum, 1e-6);
}

vec3 apply_saturation(vec3 c, float sat) {
    vec3 g = vec3(dot(c, LUMA));
    return mix(g, c, sat);
}

vec3 apply_vibrance(vec3 c, float vib) {
    float maxc = max(max(c.r, c.g), c.b);
    vec3 g = vec3(dot(c, LUMA));
    // Increase saturation more when color is flat (1.0 - maxc)
    return c + (c - g) * vib * (1.0 - maxc);
}

vec3 apply_contrast(vec3 c, float cont) {
    // Contrast around mid-grey in sRGB-ish space
    return (c - 0.5) * cont + 0.5;
}

vec3 apply_posterize(vec3 c, float steps) {
    if (steps <= 1.0) return c;
    return floor(c * steps) / steps;
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec3 base = sample_scene(uv);

    // Bloom
    vec2 px = SCREEN_PIXEL_SIZE; // size of one pixel in UV
    vec3 blurred_bright = bloom_blur(uv, px);
    vec3 color = base + blurred_bright * bloom_intensity;

    // Color styling
    color = pow(color, vec3(1.0 / gamma_adjust)); // optional slight gamma
    color = apply_saturation(color, saturation);
    color = apply_vibrance(color, vibrance);
    color = apply_contrast(color, contrast);

    // Optional era “crunch”
    color = apply_posterize(color, posterize_steps);

    COLOR = vec4(clamp(color, 0.0, 1.0), texture(SCREEN_TEXTURE, uv).a);
}
