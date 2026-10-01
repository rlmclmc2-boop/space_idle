shader_type canvas_item;
// Opaque, bounded core: motion and warm working cells follow actual load.
uniform float phase = 0.0;
uniform float power : hint_range(0.0, 1.0) = 0.0;
void fragment() {
 vec2 p = UV * 2.0 - 1.0;
 float r = length(p);
 float a = atan(p.y,p.x);
 float mask = 1.0-smoothstep(0.615,0.635,r);
 float face = 1.0-smoothstep(0.51,0.53,r);
 vec3 color = mix(vec3(0.38,0.62,0.65),vec3(0.08,0.19,0.26),face);
 float cell = step(0.28,fract((a+phase*0.4)*6.0/6.283185));
 float ring = smoothstep(0.35,0.37,r)*(1.0-smoothstep(0.46,0.48,r));
 float lit = step(fract((a+3.141593)/6.283185),power);
 color = mix(color, mix(vec3(0.20,0.35,0.39),vec3(0.51,0.81,0.79),lit),ring*cell);
 float heart = 1.0-smoothstep(0.21,0.23,r);
 vec3 warm = mix(vec3(0.25,0.37,0.41),vec3(1.0,0.66,0.34),sqrt(power));
 color = mix(color,warm,heart);
 float glint = (1.0-smoothstep(0.045,0.06,abs(p.y+0.09)))*(1.0-smoothstep(0.08,0.15,abs(p.x+0.045)));
 color = mix(color,vec3(1.0,0.93,0.76),glint*heart*(0.2+0.55*power));
 COLOR = vec4(color,mask);
}
