shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec3 body_axes = vec3(3.0);
void vertex() {
    vec3 world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 on_body = normalize(world_point / body_axes) * body_axes * 1.0005;
    POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(on_body, 1.0);
}
void fragment() {
    float radius = length((UV - vec2(0.5)) * 2.0);
    ALBEDO = vec3(0.08, 0.13, 0.11);
    ALPHA = (1.0 - smoothstep(0.18, 1.0, radius)) * 0.14;
}
