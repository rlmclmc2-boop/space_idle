shader_type canvas_item;
render_mode blend_add;

uniform float power : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 2.0) = 1.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float strength = (0.45 + power * 0.55) * pulse;
    COLOR = vec4(tex.rgb * strength, tex.a * strength);
}
