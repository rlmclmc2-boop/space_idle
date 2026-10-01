shader_type canvas_item;
render_mode unshaded;
uniform vec2 atlas_cell = vec2(0.0);
uniform vec2 atlas_grid = vec2(2.0);
uniform sampler2D assembly_order : filter_linear, repeat_disable;
uniform float progress = 0.0;
uniform float part_count = 1.0;
uniform float energy_phase = 0.0;
uniform bool working = false;
// Scoped workshop trial can reduce the future-assembly silhouette.
uniform float blueprint_opacity : hint_range(0.0,1.0) = 1.0;
// Local mechanical motion, only on the three new machines. 0 preserves iron.
uniform int machine_motion = 0;
// Opt-in for cream-plated iron prototype; other assets keep brightness gating.
uniform bool warm_energy_only = false;
// Start progress, acceptance fade-in, acceptance weight. Explicitly sampled
// by the owner so paused/hidden cards retain an identical image.
uniform vec3 completion_state = vec3(0.0,1.0,0.0);

void fragment() {
	// Clamp inside the selected cell: linear filtering must never pull in a
	// neighbouring machine, including at the atlas's odd-sized 627px cells.
	vec2 source_uv = UV;
	float running = progress >= 1.0 ? 1.0 : completion_state.y * completion_state.z;
	if (machine_motion == 1 && UV.x > 0.395 && UV.x < 0.65 && UV.y > 0.315 && UV.y < 0.61) {
		// The isolated floating cartridge moves; crescent arms and base do not.
		source_uv.y -= sin(energy_phase * 1.7) * 0.008 * running;
	}
	if (machine_motion == 2 && UV.x > 0.385 && UV.x < 0.635 && UV.y > 0.29 && UV.y < 0.49) {
		// One press stroke with a brief dwell, anchored at the upper piston.
		float stroke = pow(0.5 - 0.5 * cos(energy_phase * 1.35), 3.0);
		source_uv.y -= stroke * 0.012 * smoothstep(0.29,0.37,UV.y) * running;
	}
	if (machine_motion == 3 && ((UV.x > 0.42 && UV.x < 0.59 && UV.y < 0.44) || (UV.x > 0.25 && UV.x < 0.39 && UV.y < 0.468) || (UV.x > 0.61 && UV.x < 0.75 && UV.y < 0.468))) {
		// Three separate suspended crystals; the crucible and sockets stay still.
		float crystal = UV.x < 0.41 ? 0.0 : (UV.x > 0.59 ? 2.0 : 1.0);
		source_uv.y -= sin(energy_phase * 1.15 + crystal * 1.6) * 0.007 * running;
	}
	vec2 inset = TEXTURE_PIXEL_SIZE * 0.5;
	vec2 uv = clamp((source_uv + atlas_cell) / atlas_grid,
		atlas_cell / atlas_grid + inset, (atlas_cell + vec2(1.0)) / atlas_grid - inset);
	vec4 ink = texture(TEXTURE, uv);
	float order = texture(assembly_order, source_uv).r;
	// The fractional order is a baked, stationary growth field. Only progress
	// reveals it: pause does not shimmer or randomly remove installed pixels.
	float installed = smoothstep(order - 0.08, order + 0.08, progress * part_count);
	if (completion_state.z > 0.0) {
		float previous = smoothstep(order - 0.08, order + 0.08, completion_state.x * part_count);
		installed = mix(installed, mix(previous,1.0,completion_state.y),completion_state.z);
	}
	float brightness = max(ink.r, max(ink.g, ink.b));
	// All recipes retain their complete silhouette at zero progress. The
	// blueprint is neutral and stationary; progress only adds material/light.
	vec3 blueprint = vec3(0.22,0.40,0.53) * (0.65 + brightness * 0.35);
	// The moving highlight is gated by existing bright ink, so energy follows
	// the artist's filaments, facets and seams instead of drawing new geometry.
	float energy = warm_energy_only ? smoothstep(0.25,0.55,ink.r-ink.b)*smoothstep(0.55,0.85,ink.g) : smoothstep(0.55,0.95,brightness);
	float pulse = pow(0.5 + 0.5 * sin(UV.y * 26.0 + UV.x * 9.0 + energy_phase * 2.4), 5.0);
	float luminance = dot(ink.rgb,vec3(0.2126,0.7152,0.0722));
	vec3 balanced = mix(ink.rgb,vec3(luminance),0.18);
	float pulse_strength = (completion_state.z > 0.0 || progress >= 1.0) ? 0.025 : 0.14;
	vec3 live = balanced * (0.92 + pulse_strength * pulse * energy);
	live *= min(1.0,0.86 / max(max(live.r,live.g),max(live.b,0.001)));
	if (!working && completion_state.z <= 0.0 && progress < 1.0) {
		installed = 0.0;
		blueprint *= 0.68;
	}
	float ghost_alpha = ink.a * (0.54 + 0.22 * brightness) * blueprint_opacity;
	COLOR = vec4(mix(blueprint,live,installed),mix(ghost_alpha,ink.a,installed));
}
