shader_type canvas_item;
render_mode unshaded;
uniform int kind = 0;
uniform float phase = 0.0;
uniform float power : hint_range(0.0, 1.0) = 0.0;
float band(float d, float width) { return 1.0 - smoothstep(width, width + 0.035, abs(d)); }
float field_hash(vec3 p) {
	vec3 q = fract(p * vec3(0.1057,0.1113,0.0973));
	q += dot(q,q.zxy+vec3(17.9,33.1,29.7));
	return fract(q.x*q.y+q.z);
}
float field_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(mix(field_hash(i),field_hash(i+vec3(1,0,0)),f.x),
		mix(field_hash(i+vec3(0,1,0)),field_hash(i+vec3(1,1,0)),f.x),f.y),
		mix(mix(field_hash(i+vec3(0,0,1)),field_hash(i+vec3(1,0,1)),f.x),
		mix(field_hash(i+vec3(0,1,1)),field_hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	vec3 teal = vec3(0.20, 0.76, 0.73);
	float alpha = 0.0;
	float glow = 0.0;
	if (kind == 0) {
		float z = sqrt(max(0.0, 1.0 - r*r));
		vec3 normal = vec3(p,z);
		float turn = phase*0.12;
		vec3 q = vec3(p.x*cos(turn)+z*sin(turn),p.y,z*cos(turn)-p.x*sin(turn));
		float cloud = field_noise(q*3.6+vec3(phase*0.07,0.0,phase*0.04));
		float detail = field_noise(q*8.0-vec3(0.0,phase*0.11,phase*0.05));
		float inner = field_noise(vec3(p*2.4,z*0.6)+vec3(0.0,phase*0.08,phase*0.09));
		float density = cloud+detail*0.28-0.60;
		float thickness = max(0.024,fwidth(density)*1.5);
		float strands = 1.0-smoothstep(thickness*0.2,thickness,abs(density));
		float veins = pow(max(0.0,1.0-abs(inner-0.49)*8.0),3.0);
		float edge = 1.0 - smoothstep(0.94, 1.0, r);
		float light = max(0.0,dot(normal,normalize(vec3(-0.45,-0.6,0.75))));
		glow = (strands*(0.35+z*0.65)+veins*0.24+pow(1.0-z,3.0)*0.4)*power;
		teal = vec3(0.012,0.065,0.095)+vec3(0.025,0.12,0.13)*light;
		teal += vec3(0.12,0.63,0.62)*glow;
		teal += vec3(0.32,0.68,0.60)*pow(strands,4.0)*power*0.45;
		teal += vec3(0.12,0.42,0.36)*exp(-dot(p,p)*14.0)*veins*power;
		alpha = edge * (0.82 + glow*0.15);
	} else if (kind == 1) {
		glow = band(r-0.62,0.025)*(0.4+0.6*pow(0.5+0.5*cos(a*3.0-phase*2.0),8.0));
		glow += band(r-0.25-0.06*sin(phase*1.4),0.025)*0.38;
		alpha = glow * power * 0.72;
	} else if (kind == 2) {
		vec2 q = p * vec2(6.0, 4.0);
		q.x += mod(floor(q.y), 2.0)*0.5;
		vec2 f = abs(fract(q)-0.5);
		float grid = band(max(f.x*0.86+f.y*0.5,f.y)-0.39,0.025);
		glow = grid*0.23 + band(r-0.78,0.02)*0.45;
		alpha = glow*(1.0-smoothstep(0.8,0.95,r))*power*(0.75+0.25*sin(phase*0.9));
	} else if (kind == 3) {
		teal = vec3(0.91,0.60,0.24);
		float scan = band(p.y-(fract(phase*0.17)*2.0-1.0),0.035);
		glow = scan*0.42 + band(p.x-0.13*sin(p.y*7.0+phase),0.055)*0.16;
		alpha = glow * power * (1.0-smoothstep(0.70,0.95,abs(p.x))) * (1.0-smoothstep(0.83,1.0,abs(p.y)));
	} else if (kind == 4) {
		teal = vec3(0.28,0.65,0.88);
		float diamond = abs(p.x)*1.8+abs(p.y);
		glow = band(diamond-0.70-0.035*sin(phase),0.03)*0.55;
		for(int i=0;i<3;i++) {
			float t = fract(phase*0.15 + float(i)/3.0);
			vec2 packet = vec2(sin(float(i)*2.1)*0.55, -0.8)*(1.0-t);
			glow += exp(-dot(p-packet,p-packet)*220.0)*sin(t*3.14159)*0.45;
		}
		alpha = glow*power;
	} else {
		float packet = pow(0.5+0.5*cos(UV.x*14.0-phase*3.0),16.0);
		alpha = (0.13+packet*0.55)*power*(1.0-smoothstep(0.22,0.8,abs(p.y)));
	}
	COLOR = vec4(teal, clamp(alpha,0.0,0.9));
}
