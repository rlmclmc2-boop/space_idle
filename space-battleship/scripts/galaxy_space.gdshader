shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D explored : filter_linear, repeat_disable;
uniform float drift = 0.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
	vec2 p=UV*12.0;
	float cloud=sin(p.x+sin(p.y*1.4))*sin(p.y*0.8-p.x*0.4+drift*0.008);
	cloud=pow(clamp(cloud*0.5+0.5,0.0,1.0),3.0);
	vec2 texel=1.0/vec2(textureSize(explored,0));
	float control=0.0;
	for(int x=-2;x<=2;x++)for(int y=-2;y<=2;y++)control+=texture(explored,UV+vec2(float(x),float(y))*texel*2.0).r/25.0;
	float filament=pow(clamp(0.5+0.5*sin(p.x*1.9+p.y+cloud*4.0),0.0,1.0),4.0)*cloud;
	vec3 base=vec3(0.008,0.014,0.03)+vec3(0.022,0.033,0.075)*cloud;
	base+=vec3(0.018,0.035,0.06)*filament;
	base+=vec3(0.006,0.03,0.055)*control*(0.25+cloud*0.75);
	vec2 star_cell=floor(UV*250.0);
	float star=step(0.993,hash(star_cell))*pow(max(0.0,1.0-length(fract(UV*250.0)-0.5)*2.0),5.0);
	ALBEDO=base+vec3(0.38,0.58,0.7)*star;
}
