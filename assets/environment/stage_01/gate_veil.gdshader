shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
instance uniform float arch_center_y = 10.0;
varying vec3 world_position;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    float arch_width = 1.0 - smoothstep(13.0, 24.0, abs(world_position.x));
    float arch_height = 1.0 - smoothstep(13.0, 24.0, abs(world_position.y - arch_center_y));
    vec2 edge = smoothstep(vec2(0.0), vec2(0.12), UV) * smoothstep(vec2(0.0), vec2(0.12), vec2(1.0) - UV);
    vec2 drift = UV * vec2(11.0, 17.0) + vec2(TIME * 0.08, -TIME * 0.16);
    float billow = 0.5 + 0.5 * sin(drift.x + sin(drift.y * 1.7) * 1.5);
    float strands = pow(0.5 + 0.5 * sin(UV.y * 60.0 + sin(UV.x * 12.0 + TIME * 0.25)), 8.0);
    ALBEDO = mix(vec3(0.055, 0.12, 0.20), vec3(0.18, 0.33, 0.44), billow);
    ALPHA = arch_width * arch_height * edge.x * edge.y * (0.16 + billow * 0.18 + strands * 0.10);
}
