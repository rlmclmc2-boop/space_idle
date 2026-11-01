shader_type canvas_item;
uniform vec4 base_color:source_color=vec4(0.05,0.7,0.95,1.0);
uniform int work_kind=0;
uniform int work_zone=0;
uniform float phase=0.0;
uniform vec3 assembly_offset=vec3(0.0);
uniform vec3 transfer_target=vec3(594.0,-340.0,28.0);
uniform float transfer_layer=1.0;
uniform bool outlet_enabled=true;
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
 float cycle=fract(phase/3.0);
 float charge=smoothstep(0.0,0.50,cycle);
 float compression=smoothstep(0.50,0.65,cycle);
 vec3 center=vec3(594.0,-340.0,70.0)+assembly_offset;
 if(work_kind==3){
  float scale=cycle<0.65?0.78+charge*0.16-compression*0.27:mix(0.67,1.05,smoothstep(0.65,0.78,cycle));
  vec3 delta=world_point-center;
  VERTEX+=vec2(delta.x,-delta.y)*(scale-1.0);
  world_point=center+delta*scale;
 }else if(work_kind==9){
  vec3 nucleus=vec3(594.0,-340.0,100.0)+assembly_offset;
  float scale=cycle<0.75?0.65+charge*0.5+compression*0.35:0.65;
  vec3 delta=world_point-nucleus;
  VERTEX+=vec2(delta.x,-delta.y)*(scale-1.0);
  world_point=nucleus+delta*scale;
 }else if(work_kind==10){
  vec3 nucleus=vec3(594.0,-340.0,100.0)+assembly_offset;
  vec3 exit_point=transfer_target+assembly_offset;
  vec3 intake=nucleus+(exit_point-nucleus)*0.62;
  intake.z=100.0+transfer_layer*38.0;
  vec3 position=cycle<0.50?mix(intake,nucleus,charge):cycle<0.65?nucleus:mix(nucleus,exit_point,smoothstep(0.65,0.75,cycle));
  vec3 delta=world_point-nucleus;
  float scale=cycle<0.50?1.0-charge*0.45:cycle<0.65?0.55-compression*0.20:0.85;
  vec3 moved=position+delta*scale;
  VERTEX+=vec2(moved.x-world_point.x,world_point.y-moved.y);
  world_point=moved;
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
 vec3 point=world_point-assembly_offset;
 float cycle=fract(phase/3.0);
 if(work_kind==2){
  vec2 r=point.xy-vec2(594.0,-340.0);
  float squared=dot(r,r);
  if(squared<784.0 && point.z<100.0+sqrt(784.0-squared)){discard;}
 }

 float strength=load_fraction>0.0?mix(0.58,1.0,sqrt(load_fraction)):0.0;
 vec3 color=base_color.rgb;float opacity=1.0;
 if(work_kind==1){
  float rim=pow(1.0-abs(facing_normal.z),2.0);
  color=mix(vec3(0.01,0.12,0.22),vec3(0.05,0.65,0.9),rim);
  opacity=0.025+rim*(0.12+0.22*strength);
 }else if(work_kind==2){
  float radius=length(point.xy-vec2(594.0,-340.0));
  float charge=smoothstep(0.0,0.5,cycle);
  float head=exp(-pow((radius-118.0*(1.0-charge))/21.0,2.0));
  float heat=1.0-smoothstep(15.0,115.0,radius);
  float fade=1.0-smoothstep(0.65,0.79,cycle);
  color=mix(vec3(0.015,0.18,0.40),vec3(0.50,0.95,1.0),clamp(head*.65+heat*.45,0.0,1.0))*strength;
  opacity=(0.06+head*.24+heat*charge*.10)*fade*pow(abs(facing_normal.z),0.7);
 }else if(work_kind==3){
  float facing=dot(facing_normal,normalize(vec3(-0.4,0.6,0.8)));
  float charge=smoothstep(0.0,0.5,cycle);
  float compression=smoothstep(0.5,0.65,cycle);
  // Advected three-dimensional plasma cells, not a screen-space wave or
  // concentric ripple. Density, normal and depth retain the confined volume.
  float cells=sin(point.x*.071+point.z*.083+phase*1.2)*sin(point.y*.063-phase*.7)+sin(point.z*.091-point.x*.037+phase*.43)*.38;
  float density=smoothstep(-.35,.75,cells);
  float temperature=clamp(density*.50+max(0.0,facing)*.30+charge*.13+compression*.18,0.0,1.0);
  color=mix(vec3(0.012,0.12,0.30),vec3(0.58,0.96,1.0),temperature)*strength;
  opacity=(.18+density*.46+charge*.10)*(1.0-smoothstep(.68,.83,cycle)*.55)*smoothstep(.02,.35,abs(facing_normal.z));
 }else if(work_kind==4){
  float radius=length(point.xy-vec2(1045.0,-177.0));
  float front=20.0+106.0*formation;
  float mask=1.0-smoothstep(front-4.0,front,radius);
  float panel=pow(1.0-abs(facing_normal.z),2.0);
  float rim=smoothstep(front-12.0,front-4.0,radius);
  opacity=work_zone==1?mask*(0.10+panel*0.45+rim*0.28):0.6;
  color=mix(vec3(0.035,0.42,0.65),vec3(0.30,0.90,1.0),panel+rim*0.4)*strength;
 }else if(work_kind==5){
  float face=max(0.0,dot(facing_normal,normalize(vec3(-0.2,0.6,1.0))));
  float thermal=face*0.50+0.12;
  if(work_zone==1){thermal=clamp(1.0-length((point.xy-vec2(175.0,-501.0))/vec2(55.0,38.0)),0.0,1.0);}
  else if(work_zone==2){thermal=clamp(1.0-length((point.xy-vec2(175.0,-594.0))/vec2(78.0,38.0)),0.0,1.0);}
  color=mix(vec3(0.34,0.045,0.008),vec3(1.0,0.76,0.20),thermal)*strength;
  // Transport highlights stay inside the actual falling stream / outlet.
  // The furnace throat and catch pool never receive a scrolling wave layer.
  if(work_zone==0 || work_zone==3){
   float distance_axis=work_zone==0?point.y:dot(point.xy,vec2(0.7,-0.7));
   float glint=pow(max(0.0,cos((distance_axis+(work_zone==0?phase*70.0:-phase*70.0))*0.055)),14.0);
   color+=vec3(0.25,0.20,0.04)*glint*strength;
  }
 }else if(work_kind==6){
  float face=max(0.0,dot(facing_normal,normalize(vec3(-0.6,0.4,0.8))));
  color=mix(vec3(0.13,0.035,0.28),base_color.rgb,0.35+face*0.65)*mix(0.65,1.0,strength);
 }else if(work_kind==7){
  float progress=(cycle-0.75)/0.23;
  float pulse=exp(-pow((UV.x-progress)*9.0,2.0))*step(0.75,cycle);
  color=mix(vec3(0.005,0.08,0.14),vec3(0.35,0.96,1.0),pulse)*strength;
 }else if(work_kind==9){
  float compression=smoothstep(0.50,0.65,cycle);
  float release=smoothstep(0.65,0.69,cycle)*(1.0-smoothstep(0.70,0.75,cycle));
  float facing=max(0.0,dot(facing_normal,normalize(vec3(-0.4,0.6,0.8))));
  vec3 nucleus=mix(vec3(0.20,0.55,0.75),vec3(0.85,1.0,1.0),facing);
  color=mix(nucleus,vec3(1.0),compression*.55+release*.45)*strength;
  opacity=smoothstep(0.01,0.50,abs(facing_normal.z));
 }else if(work_kind==10){
  color=mix(vec3(0.12,0.62,0.9),vec3(0.70,1.0,1.0),max(0.0,facing_normal.z))*strength;
  opacity=cycle<0.75 && (cycle<0.65 || outlet_enabled)?(point.z<100.0?0.45:0.95):0.0;
 }else{
  color*=strength*(0.55+0.45*max(0.0,dot(facing_normal,normalize(vec3(-0.4,0.4,0.8)))));
 }
 if(work_kind!=1 && load_fraction<=0.0){opacity=0.0;}
 if(work_kind==3){opacity*=smoothstep(0.01,0.15,abs(facing_normal.z));}
 COLOR=vec4(color,opacity);
}
