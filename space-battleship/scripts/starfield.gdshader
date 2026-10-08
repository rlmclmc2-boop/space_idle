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
uniform int route_index = 0;
// Slow, pause-aware motion is evaluated once by the caller, not per pixel.
uniform vec3 scene_motion = vec3(0.0);
varying vec2 local_pos;
varying float radius;
varying float tail;
varying float opacity;
varying float layer;

float ridge(float distance_to_edge, float width) {
	return 1.0-smoothstep(width,width+1.6,abs(distance_to_edge));
}

vec3 route_scenery(vec2 uv) {
	vec2 p = uv*vec2(572.0,960.0)-scene_motion.xy*vec2(5.0,8.0);
	vec3 ink = vec3(0.012,0.023,0.039);
	vec3 scene = ink;
	if (route_index == 0) {
		// Pulse-laser route: immense nested optical rings, seen obliquely.
		vec2 lens = (p-vec2(-34.0,144.0))*vec2(0.78,1.0);
		float radial_distance = length(lens);
		float housing = ridge(radial_distance-218.0,17.0);
		float glass = 1.0-smoothstep(179.0,184.0,radial_distance);
		float rings = ridge(radial_distance-195.0,2.5)+ridge(radial_distance-245.0,3.0);
		float braces = ridge(lens.y,7.0)*step(171.0,radial_distance)*step(radial_distance,272.0);
		float pulse = ridge(radial_distance-(183.0+scene_motion.z*9.0),1.4);
		scene += vec3(0.028,0.075,0.083)*glass;
		scene += vec3(0.05,0.105,0.116)*(housing+braces);
		scene += vec3(0.06,0.18,0.19)*(rings*0.7+pulse*glass*0.45);
		vec2 remote = (p-vec2(581.0,352.0))*vec2(1.0,0.65);
		scene += vec3(0.034,0.10,0.12)*ridge(length(remote)-101.0,6.0);
	} else if (route_index == 1) {
		// Missile route: a fractured ochre world and sparse angular debris.
		vec2 q = p-vec2(-58.0,90.0);
		float radial_distance = length(q);
		float planet = 1.0-smoothstep(279.0,281.0,radial_distance);
		float daylight = clamp(0.7-q.x/510.0-q.y/740.0,0.1,0.8);
		float scar = ridge(q.x*0.76+q.y*0.65-112.0+abs(q.y-95.0)*0.24,5.0);
		float crater = ridge(length((q-vec2(121.0,89.0))*vec2(1.0,1.3))-38.0,4.0);
		scene = mix(scene,vec3(0.24,0.135,0.075)*daylight,planet);
		scene = mix(scene,ink,planet*clamp(scar+crater*0.65,0.0,1.0));
		scene += vec3(0.13,0.077,0.04)*ridge(radial_distance-284.0,2.0);
		vec2 debris = vec2(p.x-552.0+scene_motion.y*4.0,mod(p.y+34.0,173.0)-86.5);
		float rock = 1.0-smoothstep(29.0,31.0,abs(debris.x)*0.95+abs(debris.y)*0.65);
		scene += vec3(0.10,0.071,0.055)*rock*(0.7+0.3*step(debris.x,0.0));
	} else if (route_index == 2) {
		// Railgun route: paired receding accelerator spines and cross supports.
		float perspective = p.y*0.13;
		float spine = abs(p.x-286.0)-(205.0+perspective);
		float steel = ridge(spine,21.0);
		float rail = ridge(spine-12.0,2.0)+ridge(spine+12.0,2.0);
		float segment = mod(p.y+scene_motion.y*6.0,148.0);
		float joint = 1.0-smoothstep(9.0,11.0,abs(segment-74.0));
		float rib = ridge(spine+34.0,15.0)*joint;
		scene += vec3(0.064,0.080,0.10)*steel+vec3(0.055,0.07,0.09)*rib;
		scene += vec3(0.13,0.155,0.18)*rail*(0.55+0.2*scene_motion.z);
		float gantry = ridge(p.y+abs(p.x-286.0)*0.19-97.0,13.0);
		scene += vec3(0.055,0.07,0.092)*gantry;
	} else {
		// Continuous-beam route: an eclipsed star inside a long accretion disk.
		vec2 q = p-vec2(425.0,121.0);
		float radial_distance = length(q);
		vec2 disk = vec2(q.x+q.y*0.45,q.y);
		float ellipse = length(disk/vec2(320.0,51.0));
		float accretion = ridge((ellipse-1.0)*51.0,5.0);
		scene += vec3(0.115,0.075,0.18)*accretion;
		scene += vec3(0.16,0.115,0.22)*ridge(radial_distance-144.0,3.0)*(0.85+0.1*scene_motion.z);
		float eclipse = 1.0-smoothstep(135.0,137.0,radial_distance);
		scene = mix(scene,vec3(0.008,0.013,0.027),eclipse);
		float jet = ridge(q.x+q.y*0.1,3.0)*smoothstep(151.0,170.0,abs(q.y));
		scene += vec3(0.047,0.063,0.12)*jet;
	}
	// Silhouettes stay readable: no bright terrain beneath the combat lane.
	float lane = (1.0-smoothstep(0.19,0.43,abs(uv.x-0.5)))*smoothstep(0.20,0.42,uv.y);
	return mix(scene,ink,lane*0.68);
}

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
			vec4 destination = vec4(route_scenery(UV),0.94);
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
