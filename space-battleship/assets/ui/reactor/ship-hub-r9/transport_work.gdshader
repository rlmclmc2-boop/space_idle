shader_type canvas_item;
render_mode unshaded, blend_add;

uniform int kind = 2; // 2: core-to-port conduit, 3: vertical supply shaft
uniform int module_kind = 0;
uniform float power : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform vec4 tint : source_color = vec4(0.25, 0.80, 0.95, 1.0);

void fragment() {
	float strength = sqrt(clamp(power, 0.0, 1.0));
	float along = kind == 3 ? UV.y : UV.x;
	float across = kind == 3 ? UV.x : UV.y;
	float channel = 1.0 - smoothstep(0.20, 0.49, abs(across - 0.5));
	float ends = smoothstep(0.02, 0.14, along) * (1.0 - smoothstep(0.88, 0.99, along));
	float packet_pos = fract(along * 2.0 - phase * (kind == 3 ? 0.55 : 0.80));
	float packet = 1.0 - smoothstep(0.045, 0.25, packet_pos);
	float carrier = 0.16 + 0.09 * sin(along * 11.0 - phase * 1.3);
	float energy = clamp(carrier + packet * 0.78, 0.0, 1.0);
	COLOR = vec4(tint.rgb, strength * channel * ends * energy);
}
