shader_type canvas_item;
render_mode unshaded;

uniform sampler2D active_plate : source_color, filter_linear;
uniform sampler2D locked_idle_plate : source_color, filter_linear;
uniform sampler2D locked_active_plate : source_color, filter_linear;
uniform sampler2D effect_mask : filter_linear;
uniform sampler2D module_mask : filter_linear;
uniform sampler2D pipe_mask : filter_linear;
uniform float core_load = 0.0;
uniform float weapons_load = 0.0;
uniform float defence_load = 0.0;
uniform float smelting_load = 0.0;
uniform float condensation_load = 0.0;
uniform float condensation_enabled = 0.0;
uniform float phase = 0.0;

float ellipse(vec2 uv, vec2 center, vec2 radius, float feather) {
	float d = length((uv - center) / radius);
	return 1.0 - smoothstep(1.0 - feather, 1.0 + feather, d);
}

// The four streams follow the bent conduits from the core to each machine.
float conduit(vec2 uv, vec2 a, vec2 b, float bend, float width, float time) {
	float t = clamp((uv.x - a.x) / (b.x - a.x), 0.0, 1.0);
	float y = mix(a.y, b.y, t) + bend * sin(t * 3.14159265);
	float body = (1.0 - smoothstep(width * 0.45, width, abs(uv.y - y))) * step(min(a.x, b.x), uv.x) * step(uv.x, max(a.x, b.x));
	float moving = pow(0.5 + 0.5 * cos((t * 4.0 - time * 0.8) * 6.2831853), 10.0);
	return body * (0.09 + moving * 0.68);
}

void fragment() {
	vec2 uv = UV;
	bool locked = condensation_enabled < 0.5;
	vec4 idle = locked ? texture(locked_idle_plate, uv) : texture(TEXTURE, uv);
	// Machinery ends before this static console band; skip all field math there.
	if (uv.y >= 0.58) {
		COLOR = idle;
	} else {
	vec4 active = locked ? texture(locked_active_plate, uv) : texture(active_plate, uv);
	float core = max(ellipse(uv, vec2(0.5, 0.255), vec2(0.19, 0.17), 0.10), ellipse(uv, vec2(0.5, 0.095), vec2(0.047, 0.09), 0.15));
	float weapon = ellipse(uv, vec2(0.16, 0.145), vec2(0.17, 0.10), 0.16);
	float shield = ellipse(uv, vec2(0.90, 0.145), vec2(0.14, 0.11), 0.17);
	float iron = ellipse(uv, vec2(0.15, 0.385), vec2(0.17, 0.11), 0.17);
	float crystal = ellipse(uv, vec2(0.86, 0.385), vec2(0.15, 0.12), 0.17);
	vec3 tube_glass = texture(pipe_mask, uv).rgb;
	float pipe_w = 0.0;
	float pipe_d = 0.0;
	float pipe_i = 0.0;
	float pipe_c = 0.0;
	if (tube_glass.r > 0.0 && weapons_load > 0.0) pipe_w = conduit(uv, vec2(0.395, 0.205), vec2(0.270, 0.160), -0.005, 0.014, phase) * tube_glass.r;
	if (tube_glass.r > 0.0 && defence_load > 0.0) pipe_d = conduit(uv, vec2(0.665, 0.205), vec2(0.800, 0.160), -0.005, 0.014, phase) * tube_glass.r;
	if (tube_glass.g > 0.0 && smelting_load > 0.0) pipe_i = conduit(uv, vec2(0.400, 0.315), vec2(0.260, 0.411), -0.005, 0.014, phase) * tube_glass.g;
	if (tube_glass.b > 0.0 && condensation_load > 0.0) pipe_c = conduit(uv, vec2(0.650, 0.315), vec2(0.800, 0.417), -0.005, 0.014, phase) * tube_glass.b;
	float selected = max(core * core_load, max((weapon + pipe_w) * weapons_load, max((shield + pipe_d) * defence_load, max((iron + pipe_i) * smelting_load, (crystal + pipe_c) * condensation_load))));
	float blend_power = selected > 0.0 ? min(1.0, 0.72 + selected * 0.28) * min(1.0, selected * 8.0) : 0.0;
	vec3 color = mix(idle.rgb, active.rgb, blend_power);

	// Fluid inside the glass sphere moves while painted metal braces stay fixed.
	vec3 effect = texture(effect_mask, uv).rgb;
	float inner = effect.r * step(0.0001, core_load);
	if (inner > 0.0) {
		float r = length((uv - vec2(0.5, 0.255)) / vec2(0.145, 0.132));
		float angle = atan(uv.y - 0.255, uv.x - 0.5);
		vec2 drift = 0.006 * vec2(sin(angle * 3.0 + r * 12.0 - phase * 2.3), cos(angle * 4.0 - r * 10.0 + phase * 1.7));
		vec3 moving_core = locked ? texture(locked_active_plate, uv + drift).rgb : texture(active_plate, uv + drift).rgb;
		color = mix(color, moving_core, inner * (0.35 + 0.48 * core_load));
		float orbit = pow(0.5 + 0.5 * sin(angle * 5.0 + r * 19.0 - phase * 3.4), 8.0);
		float ring = exp(-pow((r - 0.56 - 0.14 * sin(phase * 1.9)) * 10.0, 2.0));
		color += inner * core_load * (vec3(0.08, 0.56, 0.9) * orbit * 0.24 + vec3(0.06, 0.35, 0.65) * ring * 0.15);
	}

	// Bright packets travel outwards on each actual pipe, independently gated.
	color = mix(color, vec3(0.60, 0.95, 1.0), clamp(pipe_w * weapons_load * 2.8, 0.0, 0.70));
	color = mix(color, vec3(0.58, 0.90, 1.0), clamp(pipe_d * defence_load * 2.8, 0.0, 0.70));
	color = mix(color, vec3(1.0, 0.63, 0.18), clamp(pipe_i * smelting_load * 3.1, 0.0, 0.72));
	color = mix(color, vec3(0.83, 0.54, 1.0), clamp(pipe_c * condensation_load * 3.1, 0.0, 0.72));

	// Each machine has its own moving signature and no glow at true zero.
	float muzzle = effect.g;
	if (muzzle > 0.0 && weapons_load > 0.0) {
		float shot = pow(0.5 + 0.5 * cos((uv.x * 5.0 + phase * 0.88) * 6.2831853), 12.0);
		color = mix(color, vec3(1.0, 0.81, 0.32), clamp(muzzle * shot * weapons_load * 2.8, 0.0, 0.68));
	}
	vec2 module = texture(module_mask, uv).rg;
	if (module.g > 0.0 && defence_load > 0.0) {
		vec2 shield_p = (uv - vec2(0.944, 0.132)) / vec2(0.080, 0.100);
		float shield_r = length(shield_p);
		float shield_arc = exp(-pow((shield_r - 0.77) * 14.0, 2.0)) * module.g;
		float shield_sweep = pow(0.5 + 0.5 * cos(atan(shield_p.y, shield_p.x) * 3.0 - phase * 2.0), 7.0);
		color = mix(color, vec3(0.70, 0.96, 1.0), clamp(shield_arc * shield_sweep * defence_load * 2.9, 0.0, 0.70));
	}
	float molten = effect.b;
	if (molten > 0.0 && smelting_load > 0.0) {
		vec2 molten_flow = uv + vec2(0.002 * sin(uv.y * 80.0 - phase * 2.3), -0.003 * sin(phase * 2.1 + uv.x * 54.0));
		vec3 moving_molten = locked ? texture(locked_active_plate, molten_flow).rgb : texture(active_plate, molten_flow).rgb;
		color = mix(color, moving_molten, molten * smelting_load * 0.75);
		float pour = pow(0.5 + 0.5 * sin(uv.y * 135.0 - phase * 4.6 + uv.x * 26.0), 8.0);
		color = mix(color, vec3(1.0, 0.87, 0.39), clamp(molten * pour * smelting_load * 2.7, 0.0, 0.68));
	}
	float facets = module.r;
	if (facets > 0.0 && condensation_load > 0.0) {
		float refract = pow(0.5 + 0.5 * sin(uv.x * 96.0 + uv.y * 58.0 - phase * 2.9), 13.0);
		color = mix(color, vec3(0.95, 0.75, 1.0), clamp(facets * refract * condensation_load * 2.8, 0.0, 0.70));
	}
	COLOR = vec4(color, idle.a);
	}
	// End the painted bay inside its own surface, meeting the shared navy spine.
	// The central machinery and controls remain untouched beyond the 24px edges.
	float left_edge = smoothstep(0.0, 0.03, uv.x);
	float right_edge = smoothstep(0.0, 0.03, 1.0 - uv.x);
	COLOR.rgb = mix(vec3(0.05098, 0.14510, 0.2), COLOR.rgb, left_edge * right_edge);
}
