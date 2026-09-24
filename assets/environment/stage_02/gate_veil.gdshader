shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
instance uniform float arch_center_y = 27.0;
varying vec3 world_position;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    float arch_width = 1.0 - smoothstep(18.0, 28.0, abs(world_position.x));
    float arch_height = 1.0 - smoothstep(18.0, 31.0, abs(world_position.y - arch_center_y));
    vec2 edge = smoothstep(vec2(0.0), vec2(0.14), UV) * smoothstep(vec2(0.0), vec2(0.14), vec2(1.0) - UV);
    float fold = UV.x * 36.0 - UV.y * 15.0 + TIME * 1.8 + sin(UV.y * 32.0 + TIME * 0.7) * 2.0;
    float gust = pow(0.5 + 0.5 * sin(fold), 5.0);
    float wisp = pow(0.5 + 0.5 * sin(UV.y * 70.0 + sin(UV.x * 11.0 + TIME * 0.3)), 12.0);
    float glint = pow(0.5 + 0.5 * sin(fold * 0.37 + TIME * 0.4), 32.0);
    ALBEDO = mix(vec3(0.12, 0.16, 0.27), vec3(0.55, 0.27, 0.61), gust) + vec3(0.10, 0.20, 0.19) * glint;
    ALPHA = arch_width * arch_height * edge.x * edge.y * (0.30 + gust * 0.28 + wisp * 0.16 + glint * 0.07);
}
