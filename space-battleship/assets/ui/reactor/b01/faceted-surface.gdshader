shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(0.8,0.8,0.7,1.0);
uniform float core_power = 0.0;
uniform vec3 core_origin=vec3(594.0,-340.0,100.0);
varying vec3 world_point;
varying vec3 world_normal;
void vertex(){
 world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
 ALBEDO=base_color.rgb;
 ROUGHNESS=0.48;
 METALLIC=0.22;
 SPECULAR=0.35;
 vec3 delta=core_origin-world_point;
 float bounce=max(0.0,dot(normalize(world_normal),normalize(delta)))*exp(-length(delta)/230.0)*core_power;
 EMISSION=vec3(0.045,0.32,0.46)*bounce;
}
void light(){
 float facing=dot(NORMAL,LIGHT);
 float band=facing>0.85?1.1:(facing>0.60?0.91:(facing>0.25?0.63:0.30));
 DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*ATTENUATION*band/3.14159265;
 float shine=max(0.0,dot(NORMAL,normalize(LIGHT+VIEW)));
 float highlight=pow(shine,24.0)*0.22+pow(shine,80.0)*0.18;
 SPECULAR_LIGHT+=ALBEDO*LIGHT_COLOR*ATTENUATION*highlight*0.16;
}
