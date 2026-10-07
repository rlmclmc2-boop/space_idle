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
uniform vec3 route_color = vec3(0.5,0.8,0.9);
varying vec2 local_pos;
varying float radius;
varying float tail;
varying float opacity;
varying float layer;

void vertex() {
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
		// Low-frequency periodic fog drifts without a visible wrap seam or TIME.
		vec2 p = UV * vec2(3.0,5.0);
		p.y -= flight_time * far_speed / 960.0;
		float cloud = sin(p.x*1.7+sin(p.y*1.3))*sin(p.y*0.8+p.x*0.4);
		float haze = pow(clamp(cloud*0.5+0.5,0.0,1.0),3.0);
		COLOR = vec4(mix(vec3(0.055,0.10,0.18),vec3(0.14,0.11,0.24),UV.y),haze*fog_opacity);
		if (hyperspace > 0.5) {
			// Quiet central void and a wide transverse rift; no extra particles,
			// textures or full-screen postprocess pass.
			float rim = smoothstep(0.18,0.49,abs(UV.x-0.5));
			float rift = exp(-abs(UV.y-0.19)*22.0);
			COLOR = vec4(mix(vec3(0.012,0.016,0.035),route_color*0.23,clamp(rim*0.7+rift*0.5,0.0,1.0)),0.94);
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
