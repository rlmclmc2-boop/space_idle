shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform vec4 base_color : source_color = vec4(0.8,0.8,0.7,1.0);
uniform float core_power = 0.0;
varying vec3 world_point;
varying vec3 world_normal;
void vertex(){
 world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
 ALBEDO=base_color.rgb;
 ROUGHNESS=0.8;
 vec3 delta=vec3(594.0,-340.0,100.0)-world_point;
 float bounce=max(0.0,dot(normalize(world_normal),normalize(delta)))*exp(-length(delta)/230.0)*core_power;
 EMISSION=vec3(0.008,0.055,0.085)*bounce;
}
void light(){
 float facing=dot(NORMAL,LIGHT);
 float band=facing>0.60?1.0:(facing>0.05?0.63:0.10);
 DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*ATTENUATION*band/3.14159265;
}
