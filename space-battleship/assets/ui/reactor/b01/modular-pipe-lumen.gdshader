shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float load_fraction : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform vec4 glass_color : source_color = vec4(0.08, 0.40, 0.55, 0.75);
uniform vec4 packet_color : source_color = vec4(0.68, 0.91, 1.0, 1.0);

void fragment() {
    // UV.x is *arc length* along a physical conduit from core socket to
    // module socket. This moves packets through the lumen, not over the bay.
    float cross = 1.0 - abs(UV.y * 2.0 - 1.0);
    float vessel = smoothstep(0.02, 0.45, cross);
    // A dim continuous cavity establishes its direction. The discrete bright
    // packets carry the visible work, so this is not a travelling water ripple.
    float wave = fract(UV.x * 3.0 - phase * 0.42);
    float packet = smoothstep(0.02, 0.13, wave) * (1.0 - smoothstep(0.25, 0.45, wave));
    float core = pow(max(cross, 0.0), 1.7);
    float perceptual_load = sqrt(load_fraction);
    float packet_light = clamp(2.0 * packet * perceptual_load * core, 0.0, 1.0);
    COLOR = vec4(glass_color.rgb * 0.28 + packet_color.rgb * packet_light,
                 vessel * clamp(0.08 + 0.92 * packet_light, 0.0, 1.0));
}
