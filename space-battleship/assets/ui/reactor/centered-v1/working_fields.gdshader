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
		vec3 q = vec3(p * 2.5, z * 1.5);
		float cloud = field_noise(q + vec3(phase * 0.10, phase * 0.035, phase * 0.06));
		float cloud2 = field_noise(q * 2.1 - vec3(phase * 0.06, phase * 0.08, 0.0));
		float luminous_gas = smoothstep(0.22, 0.83, cloud * 0.70 + cloud2 * 0.30);
		float centre = exp(-dot(p,p) * 6.0);
		float specular = pow(max(0.0, dot(normal, normalize(vec3(-0.52,-0.53,0.68)))), 13.0);
		float rim = pow(1.0-z, 2.5);
		float spiral = sin(a * 2.0 + r * 11.0 - phase * 0.65 + cloud * 1.5);
		float ribbon = pow(max(0.0, spiral), 8.0) * smoothstep(0.12,0.4,r) * (1.0-smoothstep(0.74,0.98,r));
		teal = vec3(0.012,0.09,0.13) + vec3(0.025,0.23,0.28) * luminous_gas;
		teal += vec3(0.035,0.43,0.46) * (0.32 + 0.68 * luminous_gas) * power;
		teal += vec3(0.22,0.79,0.76) * (centre * 0.50 + specular * 0.55 + ribbon * 0.22) * power;
		teal += vec3(0.17,0.70,0.67) * rim * power;
		alpha = 1.0 - smoothstep(0.965,1.0,r);
	} else if (kind == 1) {
		float focus = exp(-dot(p,p)*8.0);
		float blades = pow(0.5+0.5*cos(a*3.0-phase*2.0),8.0);
		glow = band(r-0.63,0.09)*(0.45+0.55*blades) + focus*(0.55+0.25*sin(phase*2.0));
		teal = vec3(0.13,0.67,0.75)+vec3(0.31,0.30,0.19)*focus;
		alpha = glow * (0.4+0.6*power) * (1.0-smoothstep(0.85,1.0,r));
	} else if (kind == 2) {
		vec2 q = p * vec2(6.0, 4.0);
		q.x += mod(floor(q.y), 2.0)*0.5;
		vec2 f = abs(fract(q)-0.5);
		float grid = band(max(f.x*0.86+f.y*0.5,f.y)-0.39,0.025);
		float shield = 1.0-smoothstep(0.56,0.78,max(abs(p.x)*0.72+abs(p.y)*0.42,abs(p.y)));
		glow = (0.20+grid*0.38+band(r-0.70,0.04)*0.24)*shield;
		teal = vec3(0.10,0.48,0.69);
		alpha = glow*(0.45+0.55*power)*(0.88+0.12*sin(phase*0.9));
	} else if (kind == 3) {
		teal = vec3(0.91,0.60,0.24);
		float molten = 1.0-smoothstep(-0.15,0.38,p.y+0.12*sin(p.x*5.0+phase));
		float sparks = pow(max(0.0,sin(p.x*17.0+phase*3.0)*sin(p.y*13.0-phase*2.0)),16.0);
		glow = molten*0.72+sparks*0.42;
		alpha = glow * (0.40+0.60*power) * (1.0-smoothstep(0.70,0.95,abs(p.x))) * (1.0-smoothstep(0.83,1.0,abs(p.y)));
	} else if (kind == 4) {
		teal = vec3(0.28,0.65,0.88);
		float diamond = abs(p.x)*1.8+abs(p.y);
		glow = band(diamond-0.70-0.035*sin(phase),0.08)*0.55;
		for(int i=0;i<3;i++) {
			float t = fract(phase*0.15 + float(i)/3.0);
			vec2 packet = vec2(sin(float(i)*2.1)*0.55, -0.8)*(1.0-t);
			glow += exp(-dot(p-packet,p-packet)*220.0)*sin(t*3.14159)*0.45;
		}
		alpha = glow*(0.4+0.6*power);
	} else {
		float packet = pow(0.5+0.5*cos(UV.x*14.0-phase*3.0),18.0);
		alpha = (0.18+packet*0.66)*(0.4+0.6*power)*(1.0-smoothstep(0.20,0.8,abs(p.y)));
	}
	COLOR = vec4(teal, clamp(alpha,0.0,0.9));
}
