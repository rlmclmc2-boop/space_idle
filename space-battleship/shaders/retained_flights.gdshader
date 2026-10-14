shader_type canvas_item;
uniform float simulation_clock = 0.0;
void vertex() {
    if (INSTANCE_CUSTOM.x >= 32.0) {
        float kind = INSTANCE_CUSTOM.x - 32.0;
        if (abs(UV.x - kind) > 0.1) {
            VERTEX = vec2(0.0);
            COLOR.a = 0.0;
        } else if (kind < 0.5) {
            float age = (simulation_clock - INSTANCE_CUSTOM.y) - INSTANCE_CUSTOM.z;
            VERTEX.x += INSTANCE_CUSTOM.w * age;
        }
    }
}
