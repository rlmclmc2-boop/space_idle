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
 METALLIC=surface_role==1?0.55:(surface_role==5?0.50:(surface_role==3?0.0:0.10));
 SPECULAR=surface_role==3?0.1:0.4;
 vec3 delta=core_origin-world_point;
 float bounce=max(0.0,dot(normalize(world_normal),normalize(delta)))*exp(-length(delta)/350.0)*core_power;
 EMISSION=vec3(0.055,0.55,0.82)*bounce;
}
