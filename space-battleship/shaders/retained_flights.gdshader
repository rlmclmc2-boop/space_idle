shader_type canvas_item;
uniform float simulation_clock = 0.0;
uniform sampler2D pulse_texture : source_color, filter_linear, repeat_disable;
varying vec2 pulse_uv;
varying flat float static_pulse;
void vertex() {
    static_pulse = 0.0;
    if (INSTANCE_CUSTOM.x >= 32.0) {
        float kind = INSTANCE_CUSTOM.x - 32.0;
        if (abs(UV.x - kind) > 0.1) {
            VERTEX = vec2(0.0);
            COLOR.a = 0.0;
        } else if (kind < 0.5) {
            // The native pulse topology begins with one six-vertex glow quad.
            // Reuse only this quad; collapse the old diamond/ridge/tail triangles.
            if (VERTEX_ID < 6) {
                vec2 corner = vec2(0.0);
                if (VERTEX_ID == 1 || VERTEX_ID == 2 || VERTEX_ID == 4) corner.x = 1.0;
                if (VERTEX_ID == 2 || VERTEX_ID == 4 || VERTEX_ID == 5) corner.y = 1.0;
                VERTEX = vec2((corner.x - 0.5) * 34.0, (corner.y - 0.5) * 14.0);
                pulse_uv = vec2(corner.y, 1.0 - corner.x);
                static_pulse = 1.0;
                COLOR = vec4(1.0);
                float age = (simulation_clock - INSTANCE_CUSTOM.y) - INSTANCE_CUSTOM.z;
                VERTEX.x += INSTANCE_CUSTOM.w * age;
            } else {
                VERTEX = vec2(0.0);
                COLOR.a = 0.0;
            }
        }
    }
}
void fragment() {
    if (static_pulse > 0.5) COLOR = texture(pulse_texture, pulse_uv);
}
