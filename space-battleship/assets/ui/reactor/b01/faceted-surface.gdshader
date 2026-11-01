shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(0.8,0.8,0.7,1.0);
uniform int surface_role = 0; // coated armor / alloy / dark paint / ceramic / glass / copper
uniform float core_power = 0.0;
uniform vec3 core_origin=vec3(594.0,-340.0,190.0);
varying vec3 world_point;
varying vec3 world_normal;
void vertex(){
 world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
 float arris=clamp(length(dFdx(world_normal))+length(dFdy(world_normal)),0.0,1.0);
 float edged_finish=(surface_role==0 || surface_role==1 || surface_role==5)?1.0:0.0;
 ALBEDO=mix(base_color.rgb,base_color.rgb*1.12+vec3(.015),arris*edged_finish*.20);
 ROUGHNESS=surface_role==1?0.32:(surface_role==3?0.82:(surface_role==4?0.22:0.50));
 METALLIC=surface_role==1?0.75:(surface_role==5?0.65:(surface_role==3?0.0:0.15));
 SPECULAR=surface_role==3?0.1:0.4;
 vec3 delta=core_origin-world_point;
 float bounce=max(0.0,dot(normalize(world_normal),normalize(delta)))*exp(-length(delta)/260.0)*core_power;
 EMISSION=vec3(0.06,0.52,0.77)*bounce;
}
void light(){
 float facing=dot(NORMAL,LIGHT);
 float band=.20+.67*smoothstep(.02,.85,facing)+.16*smoothstep(.75,1.0,facing);
 DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*ATTENUATION*band/3.14159265;
 float shine=max(0.0,dot(NORMAL,normalize(LIGHT+VIEW)));
 float broad=pow(shine,surface_role==1?26.0:12.0);
 float highlight=broad*.32+pow(shine,70.0)*.20;
 float finish=surface_role==1?.36:(surface_role==5?.24:(surface_role==3?.025:(surface_role==2?.06:.14)));
 SPECULAR_LIGHT+=ALBEDO*LIGHT_COLOR*ATTENUATION*highlight*finish;
}
