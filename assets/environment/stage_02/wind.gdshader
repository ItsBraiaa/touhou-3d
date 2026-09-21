shader_type spatial;
render_mode cull_disabled;
uniform vec4 leaf_color : source_color = vec4(0.25, 0.42, 0.16, 1.0);
uniform float sway = 0.18;
varying float shade;
void vertex() {
    vec3 origin = MODEL_MATRIX[3].xyz;
    float wind = sin(TIME * 1.6 + origin.x * 0.14 + origin.z * 0.08);
    VERTEX.x += wind * sway * max(VERTEX.y + 0.6, 0.0);
    VERTEX.z += cos(TIME * 1.1 + origin.z * 0.11) * sway * 0.4;
    shade = clamp(VERTEX.y * 0.2 + 0.75, 0.5, 1.0);
}
void fragment() {
    ALBEDO = leaf_color.rgb * shade;
    ROUGHNESS = 0.9;
}
