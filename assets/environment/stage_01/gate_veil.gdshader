shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
varying vec3 world_position;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    float low_gate = 1.0 - smoothstep(10.0, 23.0, world_position.y);
    vec2 edge = smoothstep(vec2(0.0), vec2(0.12), UV) * smoothstep(vec2(0.0), vec2(0.12), vec2(1.0) - UV);
    float strands = pow(0.5 + 0.5 * sin(UV.y * 60.0 + sin(UV.x * 12.0 + TIME * 0.25)), 16.0);
    ALBEDO = vec3(0.12, 0.25, 0.39);
    ALPHA = low_gate * edge.x * edge.y * (0.01 + strands * 0.075);
}
