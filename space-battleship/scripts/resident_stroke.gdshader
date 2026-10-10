shader_type canvas_item;
render_mode unshaded;
uniform float shape_width = 1.0;
uniform float stroke_factor = 0.045;
uniform float minimum_width = 1.0;
void vertex() {
    float nominal = max(minimum_width, shape_width * stroke_factor);
    float compensated;
    if (nominal <= 2.50001) {
        compensated = nominal * 0.5;
    } else if (nominal <= 5.00001) {
        compensated = mix(nominal * 0.5, nominal - 0.625, (nominal - 2.5) / 2.5);
    } else {
        compensated = nominal - 0.625;
    }
    float feather = 1.25 * min(1.0, compensated);
    VERTEX = VERTEX * shape_width + UV * (compensated * 0.5) + CUSTOM0.xy * feather;
}
