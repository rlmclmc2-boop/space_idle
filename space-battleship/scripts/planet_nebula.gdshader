shader_type canvas_item;
render_mode unshaded;

// The enclosing page can retain continuous coverage without promoting the
// original corner gas to a second foreground. Defaults preserve source use.
uniform float field_opacity : hint_range(0.0, 1.0) = 1.0;
uniform float upper_recession : hint_range(0.0, 1.0) = 0.0;

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
    float fine_gas = value_noise(p * 13.0 + 41.0) * 0.45
        + value_noise(p * 24.0 + 11.0) * 0.25;
    float blue_vein = smoothstep(0.55, 0.72, detail + fine_gas * 0.23);
    // Preserve the broad smoky mass while a few fine, broken cyan wisps
    // catch the light; avoid hard contour bands at page scale.
    float bright_wisp = smoothstep(0.56, 0.70,
        detail + value_noise(p * 13.0 + 41.0) * 0.15);
    float fine_dust = value_noise(p * 29.0 + 57.0) * 0.58
        + value_noise(p * 61.0 + 83.0) * 0.42;
    vec2 star_cell = floor(UV * vec2(22.0, 12.0));
    vec2 star_uv = fract(UV * vec2(22.0, 12.0));
    vec2 star_center = vec2(hash21(star_cell + vec2(9.0, 4.0)),
                            hash21(star_cell + vec2(3.0, 14.0)));
    vec2 star_delta = star_uv - star_center;
    float blue_star = smoothstep(0.975, 0.995, hash21(star_cell + vec2(23.0, 7.0)))
        * exp(-dot(star_delta, star_delta) * 85.0) * envelope;
    float cloud = max(smoothstep(0.30, 0.59, detail), filament * 0.58);
    cloud = max(cloud, max(blue_vein * 0.54, bright_wisp * 0.46)) * envelope;
    cloud *= 0.72 + fine_dust * 0.58;
    vec3 hue = mix(vec3(0.045, 0.14, 0.39), vec3(0.14, 0.46, 0.90), detail);
    hue = mix(hue, vec3(0.25, 0.75, 1.0), max(blue_vein, bright_wisp) * 0.46);
    hue += vec3(0.015, 0.055, 0.09) * smoothstep(0.58, 0.80, fine_dust) * blue_vein;
    hue = mix(hue, vec3(0.45, 0.88, 1.0), blue_star);
    float page_weight = mix(1.0,
        0.30 + 0.70 * smoothstep(0.15, 0.80, UV.y), upper_recession);
    COLOR = vec4(hue,
        min(max(cloud * 0.86, blue_star * 0.84), 0.89) * field_opacity * page_weight);
}
