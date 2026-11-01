shader_type canvas_item;
render_mode unshaded;

// Static layered blue gas clouds around the orbit's open corners. Their
// placement stays fixed while the planet and its structures move separately.
float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
               mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
    vec2 p = UV * vec2(5.2, 3.0);
    float detail = value_noise(p) * 0.39
        + value_noise(p * 2.1 + 8.3) * 0.29
        + value_noise(p * 4.2 + 17.6) * 0.21
        + value_noise(p * 8.4 + 29.1) * 0.11;
    float left = 1.0 - smoothstep(0.06, 0.63, UV.x);
    float right = smoothstep(0.37, 0.94, UV.x);
    float top = 1.0 - smoothstep(0.00, 0.62, UV.y);
    float bottom = smoothstep(0.38, 1.00, UV.y);
    float envelope = max(left * top, right * top);
    envelope = max(envelope, max(left * bottom, right * bottom) * 0.75);
    float filament = smoothstep(0.48, 0.65,
        detail + value_noise(p * 6.6 + 12.0) * 0.10);
    float cloud = max(smoothstep(0.30, 0.59, detail), filament * 0.58) * envelope;
    vec3 hue = mix(vec3(0.045, 0.14, 0.39), vec3(0.14, 0.46, 0.90), detail);
    COLOR = vec4(hue, cloud * 0.72);
}
