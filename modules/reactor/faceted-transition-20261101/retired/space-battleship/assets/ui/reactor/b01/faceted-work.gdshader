shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;
uniform vec4 base_color : source_color = vec4(0.05,0.7,0.95,1.0);
uniform int work_kind = 0;
uniform int work_zone = 0;
uniform float phase = 0.0;
uniform float load_fraction = 0.0;
uniform float formation = 1.0;
varying vec3 world_point;
varying vec3 facing_normal;
void vertex(){
 if(work_kind==3){
  float warp=sin(VERTEX.x*0.07+phase*2.1)*sin(VERTEX.y*0.08-phase*1.7);
  VERTEX+=NORMAL*warp*6.0;
 }
 world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 facing_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
 float strength=load_fraction>0.0?mix(0.58,1.0,sqrt(load_fraction)):0.0;
 vec3 color=base_color.rgb;float opacity=1.0;
 if(work_kind==1){
  float rim=pow(1.0-abs(facing_normal.z),2.0);
  color=mix(vec3(0.01,0.12,0.22),vec3(0.05,0.65,0.9),rim);
  opacity=0.06+rim*(0.12+0.30*strength);
 }else if(work_kind==2){
  float travel=fract(abs(world_point.y+340.0)/170.0+phase*0.65);
  float pulse=smoothstep(0.48,0.78,travel)*(1.0-smoothstep(0.87,1.0,travel));
  color=mix(vec3(0.01,0.18,0.35),vec3(0.45,0.95,1.0),pulse)*strength;
 }else if(work_kind==3){
  float facing=dot(facing_normal,normalize(vec3(-0.4,0.6,0.8)));
  float inner=sin(world_point.x*0.075+world_point.z*0.09+phase*2.7)*sin(world_point.y*0.063-phase*1.8);
  color=mix(vec3(0.03,0.40,0.75),vec3(0.65,1.0,1.0),clamp(facing*0.48+0.45+inner*0.15,0.0,1.0))*strength;
  float discharge=pow(max(0.0,cos((phase*0.65-0.8)*6.2831853)),8.0);
  color+=vec3(0.18,0.24,0.25)*discharge*strength;
 }else if(work_kind==4){
  float radius=length(world_point.xy-vec2(1045.0,-177.0));
  opacity=work_zone==1?(1.0-smoothstep(16.0+106.0*formation,20.0+106.0*formation,radius))*0.68:0.75;
  float panel=pow(1.0-abs(facing_normal.z),2.0);
  color=mix(vec3(0.035,0.50,0.72),vec3(0.30,0.90,1.0),panel)*strength;
 }else if(work_kind==5){
  float face=max(0.0,dot(facing_normal,normalize(vec3(-0.2,0.6,1.0))));
  color=mix(vec3(0.9,0.13,0.006),vec3(1.0,0.72,0.10),face*0.68+0.18)*strength;
  // Transport highlights stay inside the actual falling stream / outlet.
  // The furnace throat and catch pool never receive a scrolling wave layer.
  if(work_zone==0 || work_zone==3){
   float distance_axis=work_zone==0?world_point.y:dot(world_point.xy,vec2(0.7,-0.7));
   float glint=pow(max(0.0,cos((distance_axis+phase*70.0)*0.055)),14.0);
   color+=vec3(0.25,0.20,0.04)*glint*strength;
  }
 }else if(work_kind==6){
  float face=max(0.0,dot(facing_normal,normalize(vec3(-0.6,0.4,0.8))));
  color=mix(vec3(0.13,0.035,0.28),base_color.rgb,0.35+face*0.65)*mix(0.65,1.0,strength);
 }else if(work_kind==7){
  float head=fract(phase*0.65-UV.x*1.4);
  float flow=smoothstep(0.50,0.78,head)*(1.0-smoothstep(0.88,1.0,head));
  color=mix(vec3(0.005,0.12,0.18),vec3(0.30,0.92,1.0),flow)*strength;
 }else{
  color*=strength;
 }
 if(work_kind!=1 && load_fraction<=0.0){opacity=0.0;}
 ALBEDO=color;
 ALPHA=opacity;
}
