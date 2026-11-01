shader_type canvas_item;
uniform vec4 base_color:source_color=vec4(0.05,0.7,0.95,1.0);
uniform int work_kind=0;
uniform int work_zone=0;
uniform float phase=0.0;
uniform vec3 assembly_offset=vec3(0.0);
uniform vec3 transfer_target=vec3(594.0,-340.0,28.0);
uniform float transfer_layer=1.0;
uniform float receiver_u=0.8;
uniform float powered_at=0.0;
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
 float cycle=fract(phase/4.8);
 float charge=smoothstep(0.0,0.43,cycle);
 float compression=smoothstep(0.43,0.60,cycle);
 vec3 center=vec3(594.0,-340.0,70.0)+assembly_offset;
 if(work_kind==3){
  float scale=cycle<0.60?0.80+charge*.12-compression*.26:mix(.66,.95,smoothstep(.60,.72,cycle));
  vec3 delta=world_point-center;
  vec3 shaped=delta*vec3(scale*(1.0-compression*.18),scale*.90,scale);
  VERTEX+=vec2(shaped.x-delta.x,delta.y-shaped.y);
  world_point=center+shaped;
 }else if(work_kind==9){
  vec3 nucleus=vec3(594.0,-340.0,100.0)+assembly_offset;
  float size=.80+charge*.40;
  vec3 scale=mix(vec3(size),vec3(.52,1.35,.66),compression);
  if(cycle>=.60){scale=mix(vec3(.52,1.35,.66),vec3(.72),smoothstep(.60,.72,cycle));}
  vec3 delta=world_point-nucleus;
  vec3 moved=nucleus+delta*scale;
  VERTEX+=vec2(moved.x-world_point.x,world_point.y-moved.y);
  world_point=moved;
 }else if(work_kind==10){
  vec3 nucleus=vec3(594.0,-340.0,100.0)+assembly_offset;
  vec3 exit_point=transfer_target+assembly_offset;
  vec3 intake=nucleus+(exit_point-nucleus)*0.62;
  intake.z=100.0+transfer_layer*38.0;
  vec3 position=cycle<.43?mix(intake,nucleus,charge):cycle<.60?nucleus:mix(nucleus,exit_point,smoothstep(.60,.72,cycle));
  vec3 delta=world_point-nucleus;
  vec2 axis=normalize(exit_point.xy-nucleus.xy);
  vec2 across=vec2(-axis.y,axis.x);
  float size=cycle<.43?mix(1.60,.65,charge):cycle<.60?mix(.65,.35,compression):1.25;
  float stretch=cycle<.60?1.55:2.1;
  vec2 shaped=axis*dot(delta.xy,axis)*stretch+across*dot(delta.xy,across)*.78;
  vec3 moved=position+vec3(shaped,delta.z)*size;
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
 float cycle=fract(phase/4.8);
 if(work_kind==2){
  vec2 r=point.xy-vec2(594.0,-340.0);
  float squared=dot(r,r);
  if(squared<784.0 && point.z<100.0+sqrt(784.0-squared)){discard;}
 }

 float strength=load_fraction>0.0?mix(0.58,1.0,sqrt(load_fraction)):0.0;
 vec3 color=base_color.rgb;float opacity=1.0;
 float received_age=1.0;
 float response=0.0;
 if((work_kind==4 && work_zone==0) || (work_kind==5 && work_zone==1) || work_kind==6 || (work_kind==8 && work_zone==1) || work_kind==11){
  float arrival=.72+.28*(receiver_u+.08)/1.16;
  float elapsed=phase/4.8-arrival;
  float event_time=(floor(elapsed)+arrival)*4.8;
  if(elapsed>=0.0 && event_time+0.001>=powered_at){received_age=fract(elapsed);}
  response=smoothstep(.045,.085,received_age)*(1.0-smoothstep(.13,.22,received_age));
 }
 if(work_kind==1){
  float rim=pow(1.0-abs(facing_normal.z),2.0);
  color=mix(vec3(0.01,0.12,0.22),vec3(0.05,0.65,0.9),rim);
  opacity=0.025+rim*(0.12+0.22*strength);
 }else if(work_kind==2){
  float radius=length(point.xy-vec2(594.0,-340.0));
  float charge=smoothstep(0.0,.43,cycle);
  float head=exp(-pow((radius-118.0*(1.0-charge))/18.0,2.0));
  color=vec3(.08,.46,.68)*strength;
  opacity=(.025+head*.10)*(1.0-smoothstep(.60,.72,cycle))*pow(abs(facing_normal.z),.8);
 }else if(work_kind==3){
  float facing=max(0.0,dot(normalize(facing_normal),normalize(vec3(-.5,.6,.75))));
  float charged=smoothstep(0.0,.43,cycle);
  float release=1.0-smoothstep(.60,.76,cycle);
  color=mix(vec3(.015,.13,.26),vec3(.18,.67,.85),facing*.75+charged*.15)*strength;
  opacity=(.32+release*.20+charged*.06)*smoothstep(.01,.25,abs(facing_normal.z));
 }else if(work_kind==4){
  float radius=length(point.xy-vec2(1045.0,-177.0));
  float front=20.0+106.0*formation;
  float mask=1.0-smoothstep(front-4.0,front,radius);
  float panel=pow(1.0-abs(facing_normal.z),2.0);
  float rim=smoothstep(front-12.0,front-4.0,radius);
  opacity=work_zone==1?mask*(0.10+panel*0.45+rim*0.28):0.6;
  color=mix(vec3(0.035,0.42,0.65),vec3(0.30,0.90,1.0),panel+rim*0.4)*strength;
  if(work_zone==0){color=mix(color,vec3(.65,.97,1.0),response*.70);}
 }else if(work_kind==5){
  float face=max(0.0,dot(facing_normal,normalize(vec3(-0.2,0.6,1.0))));
  float thermal=face*0.50+0.12;
  if(work_zone==1){thermal=clamp(1.0-length((point.xy-vec2(175.0,-501.0))/vec2(55.0,38.0)),0.0,1.0);}
  else if(work_zone==2){thermal=clamp(1.0-length((point.xy-vec2(175.0,-594.0))/vec2(78.0,38.0)),0.0,1.0);}
  color=mix(vec3(0.34,0.045,0.008),vec3(1.0,0.76,0.20),thermal)*strength;
  if(work_zone==1){
   float travel=clamp((received_age-.045)/.10,0.0,1.0);
   vec2 impact=mix(vec2(210.0,-490.0),vec2(175.0,-504.0),travel);
   float reaction=1.0-smoothstep(.35,1.0,length((point.xy-impact)/vec2(28.0,18.0)));
   color+=vec3(.55,.43,.14)*reaction*response;
  }
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
  float seed=1.0-smoothstep(8.0,38.0,abs(point.y+592.0));
  color=mix(color,vec3(.75,.55,1.0),seed*response*.75);
 }else if(work_kind==7){
  float progress=(cycle-.72)/.28*1.16-.08;
  float distance=UV.x-progress;
  float head=exp(-pow(distance/.085,2.0))*step(.72,cycle);
  float tail=smoothstep(-.28,-.12,distance)*(1.0-smoothstep(-.08,.02,distance))*step(.72,cycle);
  vec3 flow=vec3(.04,.72,.98)*tail+vec3(.96,1.0,1.0)*head;
  color=mix(vec3(.003,.045,.075),flow,clamp(head+tail,0.0,1.0))*max(strength,.92);
 }else if(work_kind==9){
  float compression=smoothstep(.43,.60,cycle);
  float release=smoothstep(.60,.64,cycle)*(1.0-smoothstep(.66,.72,cycle));
  float facing=max(0.0,dot(facing_normal,normalize(vec3(-.4,.6,.8))));
  vec3 nucleus=mix(vec3(.22,.58,.78),vec3(.82,.99,1.0),facing);
  color=mix(nucleus,vec3(1.0),compression*.55+release*.45)*strength;
  opacity=smoothstep(.01,.50,abs(facing_normal.z));
 }else if(work_kind==10){
  float facing=max(0.0,dot(facing_normal,normalize(vec3(-.4,.6,.8))));
  vec3 dark=transfer_layer>0.0?vec3(.05,.40,.62):vec3(.015,.20,.36);
  vec3 hot=transfer_layer>0.0?vec3(.80,1.0,1.0):vec3(.20,.74,.91);
  color=mix(dark,hot,.20+facing*.80)*strength;
  opacity=cycle<.72 && (cycle<.60 || outlet_enabled)?1.0:0.0;
 }else if(work_kind==11){
  float fill=smoothstep(0.0,.06,received_age);
  float envelope=smoothstep(0.0,.012,received_age)*(1.0-smoothstep(.15,.22,received_age));
  float lit=1.0-smoothstep(fill-.08,fill+.02,UV.x);
  float leading=exp(-pow((UV.x-fill)/.10,2.0));
  color=mix(vec3(.04,.62,.86),vec3(.90,1.0,1.0),leading)*max(strength,.92);
  opacity=envelope*lit*.95;
 }else{
  color*=strength*(0.55+0.45*max(0.0,dot(facing_normal,normalize(vec3(-0.4,0.4,0.8)))));
  if(work_kind==8 && work_zone==1){color=mix(color,vec3(1.0,.90,.48),response*.48);}
 }
 if(work_kind!=1 && load_fraction<=0.0){opacity=0.0;}
 if(work_kind==3){opacity*=smoothstep(0.01,0.15,abs(facing_normal.z));}
 COLOR=vec4(color,opacity);
}
