shader_type canvas_item;

render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture;

// ---------- Core look ----------
uniform float contrast  : hint_range(0.5, 2.0, 0.01) = 1.15;
uniform float brightness: hint_range(0.0, 2.0, 0.01) = 1.00;
uniform float gamma_corr: hint_range(0.5, 2.5, 0.01) = 1.10; // >1 = darker midtones

// Per-channel posterize for that crunchy, uneven palette
uniform bool  enable_posterize = true;
uniform float posterize_r : hint_range(2.0, 64.0, 1.0) = 12.0;
uniform float posterize_g : hint_range(2.0, 64.0, 1.0) = 10.0;
uniform float posterize_b : hint_range(2.0, 64.0, 1.0) = 12.0;

// Ordered dithering (pre-quantize) to get nice banding texture
uniform bool  enable_dither = true;
uniform float dither_strength : hint_range(0.0, 1.0, 0.001) = 0.35; // scaled to posterize steps

// Pixelation (sample at reduced internal resolution, emulate nearest)
uniform bool  enable_pixelate = true;
uniform vec2  pixel_grid = vec2(384.0, 256.0); // try 320x200, 400x300, etc.

// ---------- RS2-ish atmosphere ----------
uniform bool enable_fog = true;
uniform vec3 fog_color = vec3(0.62, 0.70, 0.78);
uniform float fog_start : hint_range(0.0, 1.0) = 0.3; // where fog begins (screen-space Y)
uniform float fog_end   : hint_range(0.0, 1.0) = 0.8; // where fog fully saturates

// Subtle chromatic aberration for cheap lens crud
uniform bool  enable_ca = true;
uniform float ca_shift  : hint_range(0.0, 2.0, 0.0005) = 0.25; // in pixels at 1080p-ish; scale by TEXTURE_PIXEL_SIZE

// Film grain / sensor noise
uniform bool  enable_grain = true;
uniform float grain_intensity : hint_range(0.0, 0.5, 0.001) = 0.035;
uniform float grain_motion    : hint_range(0.0, 3.0, 0.01) = 1.3; // tie to TIME

// Vignette to frame the scene
uniform bool  enable_vignette = true;
uniform float vignette_strength : hint_range(0.0, 2.0, 0.001) = 0.7;
uniform float vignette_softness : hint_range(0.0, 1.0, 0.001) = 0.35;

// Sharpen (unsharp mask style)
uniform bool  enable_sharpen = true;
uniform float sharpen_amount : hint_range(0.0, 2.0, 0.001) = 0.25;

// Simple color tweaks (RS2 leaned a bit desaturated, cooler)
uniform float saturation : hint_range(0.0, 2.0, 0.001) = 0.9;
uniform float temperature: hint_range(-1.0, 1.0, 0.001) = -0.10; // - = cooler, + = warmer
uniform float tint       : hint_range(-1.0, 1.0, 0.001) = -0.05; // - = magenta, + = green

// ---------- Helpers ----------
vec3 posterize(vec3 c, vec3 steps) {
    return floor(c * steps) / steps;
}

// 4x4 Bayer value from integer pixel coords (no array indexing pitfalls)
float bayer4x4(ivec2 p) {
    // pattern in 0..15
    int x = p.x & 3;
    int y = p.y & 3;
    int idx = x + y * 4;
    // manual switch to keep GLES compilers happy
    int v = 0;
    if (idx==0) v=0; else if (idx==1) v=8; else if (idx==2) v=2; else if (idx==3) v=10;
    else if (idx==4) v=12; else if (idx==5) v=4; else if (idx==6) v=14; else if (idx==7) v=6;
    else if (idx==8) v=3; else if (idx==9) v=11; else if (idx==10) v=1; else if (idx==11) v=9;
    else if (idx==12) v=15; else if (idx==13) v=7; else if (idx==14) v=13; else v=5;
    return float(v) / 16.0;
}

float luma(vec3 c){ return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// grain hash
float hash21(vec2 p){
    // deterministic, fast
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

// saturation adjust
vec3 set_saturation(vec3 c, float s){
    float g = luma(c);
    return mix(vec3(g), c, s);
}

// temperature/tint (very lightweight)
vec3 apply_temp_tint(vec3 c, float temp, float tin){
    // temp: add to R, subtract from B; tint: add green, subtract magenta-ish
    c.r += 0.10 * temp;
    c.b -= 0.10 * temp;
    c.g += 0.12 * tin;
    c.r -= 0.06 * tin;
    c.b -= 0.06 * tin;
    return c;
}

// Unsharp mask: blur sample (3x3) then mix
vec3 unsharp(vec2 uv, vec2 px, sampler2D tex, float amt){
    vec3 sum = vec3(0.0);
    sum += texture(tex, uv + px * vec2(-1.0,-1.0)).rgb;
    sum += texture(tex, uv + px * vec2( 0.0,-1.0)).rgb;
    sum += texture(tex, uv + px * vec2( 1.0,-1.0)).rgb;
    sum += texture(tex, uv + px * vec2(-1.0, 0.0)).rgb;
    sum += texture(tex, uv + px * vec2( 0.0, 0.0)).rgb;
    sum += texture(tex, uv + px * vec2( 1.0, 0.0)).rgb;
    sum += texture(tex, uv + px * vec2(-1.0, 1.0)).rgb;
    sum += texture(tex, uv + px * vec2( 0.0, 1.0)).rgb;
    sum += texture(tex, uv + px * vec2( 1.0, 1.0)).rgb;
    vec3 blur = sum / 9.0;
    vec3 base = texture(tex, uv).rgb;
    vec3 detail = base - blur;
    return base + detail * amt;
}

// Chromatic aberration: offset channels outward from center
vec3 chromatic_aberration(vec2 uv, vec2 px, float shift){
    // scale shift by pixel size to be resolution independent
    float s = shift * max(px.x, px.y) * 800.0; // tune 800 for your target res feel
    vec2 dir = (uv - 0.5);
    // outward radial
    vec2 off = normalize(dir) * s * length(dir);
    float r = texture(screen_tex, uv + off).r;
    float g = texture(screen_tex, uv).g;
    float b = texture(screen_tex, uv - off).b;
    return vec3(r,g,b);
}

// Depth-ish fog (nonlinear depth—just shape it pleasingly)

void fragment(){
    vec2 uv = SCREEN_UV;
    vec2 px = TEXTURE_PIXEL_SIZE; // of the screen texture

    // Pixelation: snap UV to a coarse grid
    vec2 suv = uv;
    if (enable_pixelate){
        vec2 grid = max(pixel_grid, vec2(4.0));
        vec2 step_uv = 1.0 / grid;
        suv = (floor(uv / step_uv) + 0.5) * step_uv; // centers within the block
    }

    // Optional chromatic aberration samples first so the rest sees CA baked in
    vec3 color;
    if (enable_ca){
        color = chromatic_aberration(suv, px, ca_shift);
    } else {
        color = texture(screen_tex, suv).rgb;
    }

    // Core grade
    // Contrast & brightness
    color = (color - 0.5) * contrast + 0.5;
    color *= brightness;

    // Gamma (artist-friendly: apply before/after posterize feels different; RS2-ish = before)
    color = pow(max(color, 0.0), vec3(gamma_corr));

    // Ordered dithering before quantization to control banding texture
    if (enable_dither && enable_posterize){
        // Bayer space in pixel coords
        ivec2 ip = ivec2(floor(FRAGCOORD.xy));
        float b = bayer4x4(ip) - 0.5; // center around 0
        // scale by step size heuristic
        vec3 steps = vec3(posterize_r, posterize_g, posterize_b);
        vec3 d = vec3(b) * dither_strength / max(steps, vec3(1.0));
        color += d;
    }

    // Posterize (per channel)
    if (enable_posterize){
        color = posterize(color, vec3(posterize_r, posterize_g, posterize_b));
    }

    // Sharpen (bring back some “crispy” texel edges after pixelation)
    if (enable_sharpen && sharpen_amount > 0.0){
        vec3 sh = unsharp(suv, px, screen_tex, sharpen_amount);
        color = mix(color, sh, 0.75); // bias towards sharpened
    }

    // Subtle film grain (screen-space, animated)
    if (enable_grain && grain_intensity > 0.0){
        float g = hash21(FRAGCOORD.xy * 0.75 + TIME * grain_motion);
        // grain on luma, then colorize slightly
        float gl = (g - 0.5) * 2.0 * grain_intensity;
        color += gl * 0.6;                 // luma
        color += vec3(gl) * vec3(0.15,0.1,0.2); // slight cool bias
    }

    // Fog
    if (enable_fog) {
    	float f = smoothstep(fog_start, fog_end, uv.y);
    	color = mix(color, fog_color, f);
	}

    // Color mood: saturation + temperature/tint
    color = set_saturation(color, saturation);
    color = apply_temp_tint(color, temperature, tint);

    // Vignette (old clients felt darker edges on CRTs/LCDs of the time)
    if (enable_vignette && vignette_strength > 0.0){
        vec2 d = uv - 0.5;
        float r = dot(d, d); // radial
        float vig = smoothstep(0.8, vignette_softness, r); // invert-ish via softness
        color *= 1.0 - vig * vignette_strength;
    }

    COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
}
