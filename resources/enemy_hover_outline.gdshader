shader_type spatial;
// Simple outline shader used when an enemy is hovered.
// Expands the mesh slightly and renders a thin red border.
render_mode unshaded, cull_front, depth_draw_always;

// Color of the outline. The default is solid red.
uniform vec4 outline_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
// Width controls how far the mesh is expanded along its normals.
uniform float outline_width = 0.03;

void vertex() {
    // Move the vertices along their normals to create an expanded silhouette.
    POSITION += NORMAL * outline_width;
}

void fragment() {
    // Draw the outline using the specified color.
    ALBEDO = outline_color.rgb;
    ALPHA = outline_color.a;
}
