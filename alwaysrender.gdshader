shader_type spatial;

render_mode unshaded, depth_draw_always;

void fragment() {
    ALBEDO = vec3(1.0);
    ALPHA = 1.0;
}