shader_type canvas_item;
render_mode unshaded;

uniform float load_fraction : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform vec4 glass_color : source_color = vec4(0.015, 0.22, 0.36, 0.75);
uniform vec4 packet_color : source_color = vec4(0.12, 0.72, 1.0, 1.0);

void fragment() {
    // UV.x is *arc length* along a physical conduit from core socket to
    // module socket. This moves packets through the lumen, not over the bay.
    float cross = 1.0 - abs(UV.y * 2.0 - 1.0);
    float vessel = smoothstep(0.02, 0.45, cross);
    float carrier = 0.42 + 0.17 * sin(UV.x * 18.0 - phase * 2.1);
    float wave = fract(UV.x * 3.0 - phase * 0.42);
    float packet = smoothstep(0.0, 0.07, wave) * (1.0 - smoothstep(0.12, 0.42, wave));
    float core = pow(max(cross, 0.0), 2.4);
    float perceptual_load = sqrt(load_fraction);
    float light = perceptual_load * (carrier + 1.75 * packet) * core;
    COLOR = vec4(mix(glass_color.rgb, packet_color.rgb, clamp(light, 0.0, 1.0)),
                 vessel * perceptual_load * min(0.95, 0.48 + light * 0.7));
}
