shader_type spatial;
render_mode cull_disabled;
uniform sampler2D grain : repeat_enable, filter_linear_mipmap;
uniform vec4 stone_color : source_color = vec4(0.32, 0.30, 0.25, 1.0);
uniform vec4 moss_color : source_color = vec4(0.22, 0.34, 0.10, 1.0);
uniform float moss_amount = 1.0;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
    vec3 weights = pow(abs(world_normal), vec3(4.0));
    weights /= max(dot(weights, vec3(1.0)), 0.001);
    float fine = texture(grain, world_position.yz * 0.12).r * weights.x
        + texture(grain, world_position.xz * 0.12).r * weights.y
        + texture(grain, world_position.xy * 0.12).r * weights.z;
    float broad = texture(grain, world_position.xz * 0.018).r;
    float strata = sin(world_position.y * 2.4 + broad * 11.0) * 0.06;
    float moss = smoothstep(0.20, 0.80, broad) * smoothstep(0.35, 0.85, world_normal.y) * moss_amount;
    ALBEDO = mix(stone_color.rgb * (0.63 + fine * 0.9 + strata), moss_color.rgb * (0.7 + fine * 0.6), moss);
    ROUGHNESS = 0.93;
}
