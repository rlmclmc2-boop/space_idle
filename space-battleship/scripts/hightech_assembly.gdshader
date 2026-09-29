shader_type canvas_item;
render_mode unshaded;
uniform vec2 atlas_cell = vec2(0.0);
uniform vec2 atlas_grid = vec2(2.0);
uniform sampler2D assembly_order : filter_linear, repeat_disable;
uniform float progress = 0.0;
uniform float part_count = 1.0;
uniform float energy_phase = 0.0;
uniform bool working = false;
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
	// All recipes retain their complete silhouette at zero progress. The
	// blueprint is neutral and stationary; progress only adds material/light.
	vec3 blueprint = vec3(0.22,0.40,0.53) * (0.65 + brightness * 0.35);
	// The moving highlight is gated by existing bright ink, so energy follows
	// the artist's filaments, facets and seams instead of drawing new geometry.
	float energy = smoothstep(0.55,0.95,brightness);
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
	float ghost_alpha = ink.a * (0.54 + 0.22 * brightness);
	COLOR = vec4(mix(blueprint,live,installed),mix(ghost_alpha,ink.a,installed));
}
