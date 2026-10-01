shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D explored : filter_linear, repeat_disable;
uniform float drift = 0.0;
varying vec2 space_position;
void vertex() { space_position=VERTEX.xz; }
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
	vec2 map_uv=space_position/260.0+vec2(0.5);
	vec2 centered=(map_uv-0.5)*2.0;
	float radius=length(centered);
	float angle=atan(centered.y,centered.x);
	float arm=0.5+0.5*sin(angle*2.0-radius*13.0+drift*0.002);
	float cloud=pow(arm,4.0)*exp(-radius*radius*2.8);
	vec2 p=map_uv*12.0;
	float control=texture(explored,map_uv).r;
	float filament=pow(clamp(0.5+0.5*sin(p.x*1.9+p.y+cloud*4.0),0.0,1.0),4.0)*cloud;
	vec3 base=vec3(0.008,0.014,0.03)+vec3(0.030,0.048,0.070)*cloud;
	base+=vec3(0.012,0.022,0.026)*filament;
	base+=vec3(0.006,0.03,0.055)*control*(0.25+cloud*0.75);
	vec2 star_cell=floor(map_uv*250.0);
	float star=step(0.993,hash(star_cell))*pow(max(0.0,1.0-length(fract(map_uv*250.0)-0.5)*2.0),5.0);
	ALBEDO=base+vec3(0.36,0.45,0.5)*star;
}
