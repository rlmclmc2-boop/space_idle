shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color;
uniform bool textured = false;
uniform bool luminous = false;
uniform vec3 body_scale = vec3(1.0);

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
	ALBEDO = min(color * 1.35, vec3(1.0));
	ROUGHNESS = 0.68;
	METALLIC = 0.10;
	if (luminous) {
		EMISSION = color * 1.0;
	} else if (textured) {
		EMISSION = color * 0.78;
	}
}
