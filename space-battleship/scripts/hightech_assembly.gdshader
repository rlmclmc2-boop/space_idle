shader_type canvas_item;
render_mode unshaded;
uniform vec2 atlas_cell = vec2(0.0);
uniform vec2 atlas_grid = vec2(2.0);
uniform sampler2D assembly_order : filter_linear, repeat_disable;
uniform float progress = 0.0;
uniform float part_count = 1.0;
uniform float energy_phase = 0.0;
// Start progress, acceptance fade-in, acceptance weight. Explicitly sampled
// by the owner so paused/hidden cards retain an identical image.
uniform vec3 completion_state = vec3(0.0,1.0,0.0);

void fragment() {
	// Clamp inside the selected cell: linear filtering must never pull in a
	// neighbouring machine, including at the atlas's odd-sized 627px cells.
	vec2 inset = TEXTURE_PIXEL_SIZE * 0.5;
	vec2 uv = clamp((UV + atlas_cell) / atlas_grid,
		atlas_cell / atlas_grid + inset, (atlas_cell + vec2(1.0)) / atlas_grid - inset);
	vec4 ink = texture(TEXTURE, uv);
	float order = texture(assembly_order, UV).r;
	// The fractional order is a baked, stationary growth field. Only progress
	// reveals it: pause does not shimmer or randomly remove installed pixels.
	float installed = smoothstep(order - 0.08, order + 0.08, progress * part_count);
	if (completion_state.z > 0.0) {
		float previous = smoothstep(order - 0.08, order + 0.08, completion_state.x * part_count);
		installed = mix(installed, mix(previous,1.0,completion_state.y),completion_state.z);
	}
	float brightness = max(ink.r, max(ink.g, ink.b));
	vec3 blueprint = vec3(0.16,0.36,0.49) * (0.35 + brightness * 0.65);
	// The moving highlight is gated by existing bright ink, so energy follows
	// the artist's filaments, facets and seams instead of drawing new geometry.
	float energy = smoothstep(0.55,0.95,brightness);
	float pulse = pow(0.5 + 0.5 * sin(UV.y * 26.0 + UV.x * 9.0 + energy_phase * 2.4), 5.0);
	vec3 live = ink.rgb * (1.0 + 0.24 * pulse * energy);
	float ghost_alpha = ink.a * (0.12 + 0.16 * brightness);
	COLOR = vec4(mix(blueprint,live,installed),mix(ghost_alpha,ink.a,installed));
}
