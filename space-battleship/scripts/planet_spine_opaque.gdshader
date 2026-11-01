shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color;
uniform bool textured = false;
uniform bool luminous = false;
uniform float hull_roughness = 0.68;
uniform float hull_metallic = 0.10;
uniform vec2 panel_grid = vec2(0.0);
uniform float facade_gradient = 0.0;
uniform float armor_reflection = 0.0;
uniform float emission_boost = 1.0;
uniform vec3 body_scale = vec3(1.0);
uniform vec3 stellar_field_tint = vec3(1.0);
uniform float stellar_field_strength = 0.0;

varying vec3 world_point;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// The globe is painted by the 2D planet shader. Clip this opaque spine
	// against the same 3D ellipsoid so its rear arc disappears at true depth,
	// without putting overlapping armor through transparent sorting.
	vec3 segment = world_point - CAMERA_POSITION_WORLD;
	float fragment_distance = length(segment);
	vec3 origin = CAMERA_POSITION_WORLD / body_scale;
	vec3 direction = segment / (fragment_distance * body_scale);
	float a = dot(direction, direction);
	float b = 2.0 * dot(origin, direction);
	float c = dot(origin, origin) - 9.0;
	float discriminant = b * b - 4.0 * a * c;
	if (discriminant > 0.0) {
		float near_hit = (-b - sqrt(discriminant)) / (2.0 * a);
		if (near_hit > 0.0 && near_hit < fragment_distance - 0.005) {
			discard;
		}
	}
	vec3 color = tint.rgb;
	if (textured) {
		color *= texture(albedo_tex, UV).rgb;
	}
	// Only authored broad armor surfaces opt in to a restrained inset seam.
	// Authored armor UVs keep detail on selected faces without a noisy world grid.
	if (panel_grid.x > 0.5) {
		vec2 cell = abs(fract(UV * panel_grid) - vec2(0.5));
		float border = max(cell.x, cell.y);
		float recess = smoothstep(0.455, 0.485, border);
		float lip = smoothstep(0.405, 0.442, border) * (1.0 - smoothstep(0.445, 0.474, border));
		color = color * (1.0 - recess * 0.23) + vec3(lip * 0.035);
	}
	if (facade_gradient > 0.0) {
		color *= 1.0 - facade_gradient * (1.0 - smoothstep(0.05, 0.90, UV.y));
	}
	float inner_field = (1.0 - smoothstep(0.025, 0.22, UV.x)) * stellar_field_strength;
	// Let bright armor turn to a dark faceted edge at grazing angles. The
	// pressure hull stays navy while its structural silhouette gains definition.
	float bright_armor = smoothstep(0.20, 0.42, dot(color, vec3(0.30, 0.59, 0.11)));
	float edge = 1.0 - smoothstep(0.12, 0.56, abs(dot(normalize(NORMAL), normalize(VIEW))));
	vec3 faceted = color * (1.0 - 0.52 * bright_armor * edge);
	faceted += vec3(0.015, 0.027, 0.032) * (1.0 - bright_armor) * smoothstep(0.48, 0.86, edge);
	ALBEDO = mix(faceted, stellar_field_tint, inner_field * 0.22);
	// Broad armored shells have a controlled satin return; recessed machinery
	// keeps its original diffuse response. This reads at the actual page scale.
	float return_light = armor_reflection * pow(max(dot(reflect(-normalize(VIEW), normalize(NORMAL)),
		normalize(vec3(0.35, 0.72, 0.61))), 0.0), 6.0);
	ALBEDO += vec3(0.032, 0.044, 0.049) * return_light;
	ROUGHNESS = max(0.36, hull_roughness - (panel_grid.x > 0.5 ? 0.10 : 0.0) - armor_reflection * 0.14);
	METALLIC = hull_metallic;
	SPECULAR = mix(0.35, 0.78, armor_reflection);
	if (luminous) {
		EMISSION = color * emission_boost;
	} else if (textured) {
		EMISSION = color * 0.35 + stellar_field_tint * inner_field * 0.42;
	}
}
