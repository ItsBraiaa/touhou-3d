shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
void fragment() {
    vec2 edge = smoothstep(vec2(0.0), vec2(0.16), UV) * smoothstep(vec2(0.0), vec2(0.16), vec2(1.0) - UV);
    float wisp = pow(0.5 + 0.5 * sin(UV.y * 70.0 + sin(UV.x * 11.0 + TIME * 0.3)), 18.0);
    ALBEDO = vec3(0.48, 0.25, 0.65);
    ALPHA = edge.x * edge.y * (0.012 + wisp * 0.04);
}
