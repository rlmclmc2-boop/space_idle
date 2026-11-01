shader_type canvas_item;
render_mode blend_disabled;
uniform sampler2D resting_surface:filter_linear;
uniform sampler2D working_surface:filter_linear;
uniform sampler2D local_surfaces:filter_linear,repeat_disable;
uniform float core_power=0.0;
uniform float defence_power=0.0;
uniform float smelting_power=0.0;
uniform vec3 defence_light_bounds=vec3(0.0);
uniform vec3 smelting_light_bounds=vec3(0.0);
void fragment(){
 vec3 rest=texture(resting_surface,UV).rgb;
 vec3 result=mix(rest,texture(working_surface,UV).rgb,core_power);
 vec2 point=UV*vec2(808.0,835.0);
 vec2 bounded=clamp(UV,vec2(.5/808.0,.5/835.0),vec2(1.0-.5/808.0,1.0-.5/835.0));
 if(defence_power>0.0 && distance(point,defence_light_bounds.xy)<defence_light_bounds.z){
  result+=max(texture(local_surfaces,vec2(bounded.x*.5,bounded.y)).rgb-rest,vec3(0.0))*defence_power;
 }
 if(smelting_power>0.0 && distance(point,smelting_light_bounds.xy)<smelting_light_bounds.z){
  result+=max(texture(local_surfaces,vec2(.5+bounded.x*.5,bounded.y)).rgb-rest,vec3(0.0))*smelting_power;
 }
 COLOR=vec4(result,1.0);
}
