shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(0.8,0.8,0.7,1.0);
uniform int surface_role = 0; // coated armor / alloy / dark paint / ceramic / glass / copper / hot refractory
uniform float refractory_temperature=0.0;
varying vec3 world_normal;
void vertex(){
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
 float arris=clamp(length(dFdx(world_normal))+length(dFdy(world_normal)),0.0,1.0);
 float edged_finish=(surface_role==0 || surface_role==1 || surface_role==5)?1.0:0.0;
 ALBEDO=mix(base_color.rgb,base_color.rgb*1.12+vec3(.015),arris*edged_finish*.20);
 ROUGHNESS=surface_role==1?0.32:((surface_role==3 || surface_role==6)?0.82:(surface_role==4?0.35:(surface_role==2?0.68:0.46)));
 METALLIC=surface_role==1?0.55:(surface_role==5?0.50:(surface_role==0?.08:0.0));
 SPECULAR=surface_role==1?.5:(surface_role==5?.4:((surface_role==3 || surface_role==6)?.1:(surface_role==2?.08:(surface_role==4?.18:.32))));
 CLEARCOAT=surface_role==0?.12:0.0;
 CLEARCOAT_ROUGHNESS=.50;
 AO=COLOR.r;
 AO_LIGHT_AFFECT=.28;
 if(surface_role==6){
  float heat=clamp(COLOR.g,0.0,1.0);
  EMISSION=mix(vec3(.65,.045,.004),vec3(2.0,.55,.04),heat)*pow(heat,1.4)*.8*refractory_temperature;
 }
}
