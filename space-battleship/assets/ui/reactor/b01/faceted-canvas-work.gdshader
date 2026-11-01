shader_type canvas_item;
uniform vec4 base_color:source_color=vec4(0.05,0.7,0.95,1.0);
uniform int work_kind=0;
uniform int work_zone=0;
uniform float phase=0.0;
uniform float load_fraction=0.0;
uniform float formation=1.0;
uniform bool depth_ready=false;
uniform mat4 stage_from_canvas=mat4(1.0);
uniform sampler2D body_depth:filter_nearest;
varying vec3 world_point;
varying vec3 facing_normal;
vec3 srgb_encode(vec3 c){c=max(c,vec3(0.0));return mix(c*12.92,1.055*pow(c,vec3(1.0/2.4))-0.055,step(vec3(0.0031308),c));}
void vertex(){
 vec4 data=COLOR;
 vec2 planar=data.ba*2.0-1.0;
 facing_normal=normalize(vec3(planar,sqrt(max(0.0,1.0-dot(planar,planar)))));
 vec2 screen=(stage_from_canvas*MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;
 float s=835.0/1326.0;
 world_point=vec3((screen.x-(808.0-1187.0*s)*0.5)/s,-screen.y/s,(data.r*255.0*256.0+data.g*255.0)/65535.0*1024.0-256.0);
 if(work_kind==3){
  float warp=sin(world_point.x*0.07+phase*2.1)*sin(world_point.y*0.08-phase*1.7)*6.0*abs(facing_normal.z);
  VERTEX+=vec2(facing_normal.x,-facing_normal.y)*warp;
  world_point+=facing_normal*warp;
 }
}
void fragment(){
 if(depth_ready){
  float s=835.0/1326.0;
  vec2 local=vec2(world_point.x*s+(808.0-1187.0*s)*0.5,-world_point.y*s);
  vec2 bytes=texture(body_depth,local/vec2(808.0,835.0)).rg*255.0;
  float front=(bytes.r*256.0+bytes.g)/65535.0*1024.0-256.0;
  if(world_point.z+0.25<front){discard;}
 }
 if(work_kind==2){
  vec2 r=world_point.xy-vec2(594.0,-340.0);
  float squared=dot(r,r);
  if(squared<784.0 && world_point.z<100.0+sqrt(784.0-squared)){discard;}
 }

 float strength=load_fraction>0.0?mix(0.58,1.0,sqrt(load_fraction)):0.0;
 vec3 color=base_color.rgb;float opacity=1.0;
 if(work_kind==1){
  float rim=pow(1.0-abs(facing_normal.z),2.0);
  color=mix(vec3(0.01,0.12,0.22),vec3(0.05,0.65,0.9),rim);
  opacity=0.025+rim*(0.12+0.22*strength);
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
  color=mix(vec3(1.0),color,smoothstep(12.0,98.0,length(world_point.xy-vec2(594.0,-340.0))));
  opacity=0.65;
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
   float glint=pow(max(0.0,cos((distance_axis+(work_zone==0?phase*70.0:-phase*70.0))*0.055)),14.0);
   color+=vec3(0.25,0.20,0.04)*glint*strength;
  }
 }else if(work_kind==6){
  float face=max(0.0,dot(facing_normal,normalize(vec3(-0.6,0.4,0.8))));
  color=mix(vec3(0.13,0.035,0.28),base_color.rgb,0.35+face*0.65)*mix(0.65,1.0,strength);
 }else if(work_kind==7){
  float head=fract(phase*0.65-UV.x*1.4);
  float flow=smoothstep(0.50,0.78,head)*(1.0-smoothstep(0.88,1.0,head));
  color=mix(vec3(0.005,0.12,0.18),vec3(0.30,0.92,1.0),flow)*strength;
 }else if(work_kind==9){
  float discharge=pow(max(0.0,cos((phase*0.65-0.8)*6.2831853)),8.0);
  color=mix(vec3(0.78,0.98,1.0),vec3(1.0),discharge)*strength;
  opacity=smoothstep(0.01,0.50,abs(facing_normal.z));
 }else{
  color*=strength*(0.55+0.45*max(0.0,dot(facing_normal,normalize(vec3(-0.4,0.4,0.8)))));
 }
 if(work_kind!=1 && load_fraction<=0.0){opacity=0.0;}
 if(work_kind==3){opacity*=smoothstep(0.01,0.15,abs(facing_normal.z));}
 COLOR=vec4(color,opacity);
}
