shader_type canvas_item;
render_mode unshaded;
uniform int kind = 0;
uniform float phase = 0.0;
uniform float power : hint_range(0.0, 1.0) = 0.0;
float band(float d, float width) { return 1.0 - smoothstep(width, width + 0.035, abs(d)); }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	vec3 teal = vec3(0.20, 0.76, 0.73);
	float alpha = 0.0;
	float glow = 0.0;
	if (kind == 0) {
		float z = sqrt(max(0.0, 1.0 - r*r));
		float strand_wave = sin(p.x*10.0+p.y*3.0+sin(p.y*8.0-phase*0.8)+2.0*sin(p.y*4.0+phase*0.3)+phase*0.65);
		float vein_wave = sin(p.y*11.0-p.x*4.0+sin(p.x*7.0+phase*0.6)+2.0*cos(p.x*5.0-phase*0.3));
		float strands = 1.0-smoothstep(0.035,max(0.12,fwidth(strand_wave)*1.3),abs(strand_wave));
		float veins = 1.0-smoothstep(0.035,max(0.11,fwidth(vein_wave)*1.3),abs(vein_wave));
		float edge = 1.0 - smoothstep(0.94, 1.0, r);
		glow = (strands*0.84 + veins*0.54 + pow(1.0-z, 3.0)*0.45) * power;
		teal = mix(vec3(0.018,0.10,0.14), teal, 0.12 + glow);
		teal += vec3(0.35,0.64,0.59)*pow(max(0.0,strands+veins-1.0),2.0)*power*0.4;
		teal += vec3(0.15,0.48,0.40)*exp(-dot(p,p)*16.0)*power;
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
