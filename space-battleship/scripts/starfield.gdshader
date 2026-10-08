shader_type canvas_item;
render_mode unshaded;
uniform float travel = 0.0;
uniform float streak = 0.0;
uniform float speed = 1.0;
uniform float flight_time = 0.0;
uniform float far_speed = 3.0;
uniform float mid_speed = 18.0;
uniform float near_speed = 90.0;
uniform float density = 1.0;
uniform float mid_opacity = 0.16;
uniform float fog_opacity = 0.22;
uniform float hyperspace = 0.0;
uniform sampler2D route_atlas : source_color, filter_linear, repeat_disable;
uniform vec2 route_origin = vec2(0.0);
// Slow, pause-aware motion is evaluated once by the caller, not per pixel.
uniform vec2 scene_motion = vec2(0.0);
varying vec2 scenery_uv;
varying vec2 local_pos;
varying float radius;
varying float tail;
varying float opacity;
varying float layer;

void vertex() {
	// Atlas gutters are created by sampling an inset, not by rebuilding art.
	// Motion stays inside that inset, including bilinear filtering at seams.
	scenery_uv = route_origin + (vec2(0.025) + UV*0.95 + scene_motion*0.008)*0.5;
	float seed = COLOR.r;
	layer = COLOR.a < 0.5 ? -1.0 : (seed > 0.965 ? 1.0 : (seed > 0.87 ? 2.0 : 0.0));
	radius = seed * 1.25;
	tail = seed * (5.0 + 9.0 * speed * streak);
	opacity = (0.13 + seed * 0.34) * step(COLOR.g, density);
	float velocity = far_speed * (0.5 + seed);
	if (layer == 1.0) { radius = 4.0 + COLOR.g * 5.0; tail = radius; velocity = mid_speed; opacity = mid_opacity; }
	if (layer == 2.0) { radius = 0.7; velocity = near_speed; opacity *= 0.48; }
	local_pos = vec2(mix(-radius-0.5,radius+0.5,UV.x),mix(-max(radius,tail)-0.5,radius+0.5,UV.y));
	if (layer >= 0.0) {
		float scroll = flight_time * velocity + travel * seed * 0.18;
		VERTEX = vec2(COLOR.g*572.0,mod(COLOR.b*990.0+scroll,990.0)-15.0)+local_pos;
	}
}
void fragment() {
	if (layer < 0.0) {
		vec4 fog = vec4(0.0);
		if (hyperspace < 1.0) {
			// Low-frequency periodic fog drifts without a wrap seam or TIME.
			vec2 p = UV * vec2(3.0,5.0);
			p.y -= flight_time * far_speed / 960.0;
			float cloud = sin(p.x*1.7+sin(p.y*1.3))*sin(p.y*0.8+p.x*0.4);
			float haze = clamp(cloud*0.5+0.5,0.0,1.0);
			// Same cubic density curve; no general-purpose fragment pow.
			haze = haze*haze*haze;
			fog = vec4(mix(vec3(0.055,0.10,0.18),vec3(0.14,0.11,0.24),UV.y),haze*fog_opacity);
		}
		COLOR = fog;
		if (hyperspace > 0.0) {
			float presence = smoothstep(0.0,1.0,hyperspace);
			// All environment detail is baked into the fixed ImageGen atlas.
			vec4 destination = vec4(texture(route_atlas,scenery_uv).rgb*0.52,0.94);
			// Mix premultiplied colors, then restore straight alpha for blend_mix.
			float alpha = mix(fog.a,destination.a,presence);
			COLOR = vec4(mix(fog.rgb*fog.a,destination.rgb*destination.a,presence)/max(alpha,0.0001),alpha);
		}
	} else if (layer == 1.0) {
		vec2 p = local_pos / radius;
		float shape = max(abs(p.x)*0.85+abs(p.y)*0.4,abs(p.y));
		float edge = 1.0-smoothstep(0.75,0.95,shape);
		COLOR = vec4(mix(vec3(0.18,0.26,0.32),vec3(0.37,0.47,0.53),step(p.x+p.y,0.1)),edge*opacity*density);
	} else {
		float dot_alpha = (1.0-smoothstep(radius-0.35,radius+0.35,length(local_pos)))*opacity;
		float line_alpha = (1.0-smoothstep(0.25,0.75,abs(local_pos.x)))*step(-tail,local_pos.y)*step(local_pos.y,0.0)*opacity*(layer == 2.0 ? 0.5 : streak*0.3);
		float a = line_alpha+dot_alpha*(1.0-line_alpha);
		COLOR = vec4(vec3(0.65,0.81,0.95),a);
	}
}
