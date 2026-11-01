shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D baked_surface : filter_linear;
uniform sampler2D baked_core_light : filter_linear;
uniform float core_power=0.0;
void fragment(){
 vec3 resting=texture(baked_surface,SCREEN_UV).rgb;
 vec3 working=texture(baked_core_light,SCREEN_UV).rgb;
 ALBEDO=mix(resting,working,core_power);
}
