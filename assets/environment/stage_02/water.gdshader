shader_type spatial;
render_mode cull_disabled;
uniform sampler2D grain : repeat_enable, filter_linear_mipmap;
uniform vec4 water_color : source_color = vec4(0.04, 0.20, 0.18, 1.0);
void vertex() {
    VERTEX.y += sin(VERTEX.x * 0.8 + TIME * 1.5) * 0.05;
}
void fragment() {
    vec2 flow = UV * vec2(2.0, 9.0) + vec2(0.0, TIME * 0.18);
    float ripple = texture(grain, flow).r;
    float streak = sin(UV.x * 49.0 + sin(UV.y * 22.0 + TIME * 3.5) * 1.6);
    float foam = smoothstep(0.40, 0.61, ripple) * 0.65 + smoothstep(0.65, 0.95, streak) * 0.45;
    ALBEDO = mix(water_color.rgb, vec3(0.70, 0.86, 0.76), foam * 0.45);
    ROUGHNESS = 0.3;
    METALLIC = 0.12;
}
