uniform float glass_reflectance=.10;
uniform float glass_thickness=2.5;
uniform float glass_absorption=.006;
uniform vec3 glass_tint=vec3(.018,.045,.065);
uniform vec4 glass_sky_top:source_color=vec4(.1,.2,.3,1.0);
uniform vec4 glass_sky_horizon:source_color=vec4(.5,.6,.7,1.0);
uniform vec4 glass_ground_horizon:source_color=vec4(.5,.4,.3,1.0);
uniform vec4 glass_ground_bottom:source_color=vec4(.05,.1,.15,1.0);
uniform vec2 glass_environment_energy=vec2(.45,.30);
uniform float glass_exposure=.85;
uniform vec3 glass_lamp0_point=vec3(0.0);
uniform vec3 glass_lamp1_point=vec3(0.0);
uniform vec4 glass_lamp0_color:source_color=vec4(1.0);
uniform vec4 glass_lamp1_color:source_color=vec4(1.0);
uniform vec3 glass_lamp0_shape=vec3(1.35,650.0,1.35);
uniform vec3 glass_lamp1_shape=vec3(1.35,650.0,1.35);
uniform vec3 glass_key_direction=vec3(-.5,.4,.7);
uniform vec4 glass_key_color:source_color=vec4(1.0);
uniform float glass_key_energy=1.0;
varying vec4 glass_surface;
vec3 glass_lamp_reflection(vec3 point,vec3 ray,vec3 lamp_point,vec3 lamp_color,vec3 shape){
 vec3 delta=lamp_point-point;float distance=max(length(delta),1.0);
 float align=max(0.0,dot(ray,delta/distance));float a2=align*align;float a4=a2*a2;float a8=a4*a4;
 float lobe=a8*a8*a8;
 float falloff=pow(clamp(1.0-distance/shape.y,0.0,1.0),shape.z);
 return lamp_color*shape.x*falloff*lobe;
}
uniform sampler2D plasma_atlas:source_color,filter_linear,repeat_disable;
uniform vec2 plasma_grid=vec2(8.0,4.0);
uniform int plasma_frames=32;
uniform vec3 plasma_source=vec3(594.0,-340.0,300.0);
uniform float plasma_gain=2.0;
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
uniform mat4 author_from_source=mat4(1.0);
uniform mat4 source_from_author=mat4(1.0);
uniform float growth_base=0.0;
uniform vec3 seed_origin=vec3(1017.0,-592.0,78.0);
uniform float mechanism_growth=1.0;
uniform float pulse_strength=1.0;
uniform vec3 transport_origin=vec3(0.0);
uniform vec3 transport_start=vec3(0.0);
uniform vec3 transport_middle=vec3(0.0);
uniform vec3 transport_end=vec3(0.0);
uniform float transport_split=.5;
uniform float transport_progress=0.0;
uniform sampler2D body_depth:filter_nearest;
varying vec3 world_point;
varying vec3 authored_point;
varying vec2 plasma_uv;
varying vec3 facing_normal;
varying float axial_position;
void vertex(){
 axial_position=0.0;glass_surface=vec4(0.0);
 vec4 data=COLOR;
 vec2 planar=data.ba*2.0-1.0;
 facing_normal=normalize(vec3(planar,sqrt(max(0.0,1.0-dot(planar,planar)))));
 if(work_kind==6 || work_kind==1){facing_normal=normalize(vec3(planar,UV.x));}
 vec2 screen=(stage_from_canvas*MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;
 float s=835.0/1326.0;
 world_point=vec3((screen.x-(808.0-1187.0*s)*0.5)/s,-screen.y/s,(data.r*255.0*256.0+data.g*255.0)/65535.0*1024.0-256.0);
 plasma_uv=vec2(.5);
 if(work_kind==3){plasma_uv=(world_point.xy-assembly_offset.xy-plasma_source.xy)/vec2(plasma_source.z,-plasma_source.z)+.5;}
 float cycle=fract(phase/4.8);
 float charge=smoothstep(0.0,0.43,cycle);
 float compression=smoothstep(0.43,0.60,cycle);
 vec3 center=vec3(594.0,-340.0,70.0)+assembly_offset;
 if(work_kind==6 && (mechanism_growth<.9999 || work_zone==1)){
  vec3 authored=(author_from_source*vec4(world_point-assembly_offset,1.0)).xyz;
  if(work_zone==1){
   float t=transport_progress;
   vec3 position=t<transport_split?mix(transport_start,transport_middle,t/transport_split):mix(transport_middle,transport_end,(t-transport_split)/(1.0-transport_split));
   authored+=position-transport_origin;
  }else{
   authored.y=growth_base+(authored.y-growth_base)*mechanism_growth;
   vec3 normal_local=transpose(mat3(source_from_author))*facing_normal;
   normal_local.y/=max(.01,mechanism_growth);
   facing_normal=normalize(transpose(mat3(author_from_source))*normal_local);
  }
  vec3 moved=(source_from_author*vec4(authored,1.0)).xyz+assembly_offset;
  VERTEX+=vec2(moved.x-world_point.x,world_point.y-moved.y);
  world_point=moved;
 }else if(work_kind==8 && work_zone==0){
  vec3 authored=(author_from_source*vec4(world_point-assembly_offset,1.0)).xyz;
  authored+=mix(transport_start,transport_end,transport_progress)-transport_origin;
  vec3 moved=(source_from_author*vec4(authored,1.0)).xyz+assembly_offset;
  VERTEX+=vec2(moved.x-world_point.x,world_point.y-moved.y);
  world_point=moved;
 }else if(work_kind==3){
  float scale=cycle<0.60?0.94+charge*.03-compression*.18:mix(.79,1.02,smoothstep(.60,.72,cycle));
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
  axial_position=dot(delta.xy,axis)/8.0;
  float size=cycle<.43?mix(1.60,.65,charge):cycle<.60?mix(.65,.35,compression):1.25;
  float stretch=cycle<.60?1.55:2.1;
  vec2 shaped=axis*dot(delta.xy,axis)*stretch+across*dot(delta.xy,across)*.78;
  vec3 moved=position+vec3(shaped,delta.z)*size;
  VERTEX+=vec2(moved.x-world_point.x,world_point.y-moved.y);
  world_point=moved;
 }
 authored_point=world_point-assembly_offset;
 if(work_kind==4 || work_kind==5 || work_kind==6 || work_kind==16){authored_point=(author_from_source*vec4(authored_point,1.0)).xyz;}
 if(work_kind==1){
  vec3 normal=normalize(facing_normal);vec3 ray=reflect(vec3(0.0,0.0,-1.0),normal);
  float view=max(normal.z,0.0);float edge=1.0-view;float e2=edge*edge;
  float fresnel=glass_reflectance+(1.0-glass_reflectance)*e2*e2*edge;
  float path=glass_thickness/max(view,.16);
  float absorption=1.0-1.0/(1.0+glass_absorption*path);
  float absorbed_transmission=(1.0-fresnel)*absorption;
  float alpha=clamp(fresnel+absorbed_transmission,.04,1.0);
  vec3 sky=mix(glass_sky_horizon.rgb,glass_sky_top.rgb,max(ray.y,0.0))*glass_environment_energy.x;
  vec3 ground=mix(glass_ground_horizon.rgb,glass_ground_bottom.rgb,max(-ray.y,0.0))*glass_environment_energy.y;
  vec3 reflected=mix(ground,sky,smoothstep(-.08,.08,ray.y));
  float key_alignment=max(0.0,dot(ray,glass_key_direction));
  float k2=key_alignment*key_alignment;float k4=k2*k2;float k8=k4*k4;
  reflected+=glass_key_color.rgb*glass_key_energy*k8*k8*k8;
  reflected+=glass_lamp_reflection(world_point,ray,glass_lamp0_point,glass_lamp0_color.rgb,glass_lamp0_shape);
  reflected+=glass_lamp_reflection(world_point,ray,glass_lamp1_point,glass_lamp1_color.rgb,glass_lamp1_shape);
  glass_surface=vec4((reflected*glass_exposure*fresnel+glass_tint*absorbed_transmission)/alpha,alpha);
 }
}
void fragment(){
 if((work_kind==6 || work_kind==1) && facing_normal.z<=0.0){discard;}
 if(depth_ready){
  float s=835.0/1326.0;
  vec2 local=vec2(world_point.x*s+(808.0-1187.0*s)*0.5,-world_point.y*s);
  vec2 bytes=texture(body_depth,local/vec2(808.0,835.0)).rg*255.0;
  float front=(bytes.r*256.0+bytes.g)/65535.0*1024.0-256.0;
  if(world_point.z+0.25<front){discard;}
 }
 vec3 point=authored_point;
 float cycle=fract(phase/4.8);
 if(work_kind==2){
  vec2 r=point.xy-vec2(594.0,-340.0);
  float squared=dot(r,r);
  if(squared<784.0 && point.z<100.0+sqrt(784.0-squared)){discard;}
 }

 float strength=(work_kind!=1 && load_fraction>0.0)?mix(0.58,1.0,sqrt(load_fraction)):0.0;
 vec3 color=base_color.rgb;float opacity=1.0;
 float received_age=1.0;
 float response=0.0;
 if((work_kind==4 && work_zone==0) || (work_kind==5 && work_zone==1) || work_kind==6 || work_kind==16 || (work_kind==8 && work_zone==1) || work_kind==11){
  float arrival=.72+.28*(receiver_u+.08)/1.16;
  float elapsed=phase/4.8-arrival;
  float event_time=(floor(elapsed)+arrival)*4.8;
  if(elapsed>=0.0 && event_time+0.001>=powered_at){received_age=fract(elapsed);}
  response=smoothstep(.045,.085,received_age)*(1.0-smoothstep(.13,.22,received_age));
 }
 if(work_kind==1){
  color=glass_surface.rgb;opacity=glass_surface.a;
 }else if(work_kind==2){
  float radius=length(point.xy-vec2(594.0,-340.0));
  float charge=smoothstep(0.0,.43,cycle);
  float head=exp(-pow((radius-118.0*(1.0-charge))/18.0,2.0));
  color=mix(vec3(.06,.65,.90),vec3(.82,1.20,1.30),head*.85)*strength;
  opacity=(.24+head*.70)*(1.0-smoothstep(.60,.72,cycle))*pow(abs(facing_normal.z),.8);
  opacity*=mix(.35,1.0,smoothstep(50.0,155.0,point.z));
 }else if(work_kind==3){
  float frame=cycle*float(plasma_frames);
  float first=floor(frame);float next=mod(first+1.0,float(plasma_frames));
  vec2 local=clamp(plasma_uv,vec2(.003),vec2(.997));
  vec2 a=(vec2(mod(first,plasma_grid.x),floor(first/plasma_grid.x))+local)/plasma_grid;
  vec2 b=(vec2(mod(next,plasma_grid.x),floor(next/plasma_grid.x))+local)/plasma_grid;
  vec4 volume=mix(texture(plasma_atlas,a),texture(plasma_atlas,b),fract(frame));
  float compression=smoothstep(.43,.60,cycle)*(1.0-smoothstep(.66,.80,cycle));
  color=volume.rgb*plasma_gain*strength*(1.0+compression*.18);
  opacity=smoothstep(.01,.18,abs(facing_normal.z));
 }else if(work_kind==4){
  float radius=UV.x;
  float front=formation;
  float mask=1.0-smoothstep(front-.025,front,radius);
  float panel=pow(1.0-abs(facing_normal.z),2.0);
  float rim=smoothstep(front-.085,front-.025,radius);
  opacity=work_zone==1?mask*(0.50+panel*0.35+rim*0.45):0.6;
  float lit_face=clamp(dot(facing_normal,normalize(vec3(-.48,.55,.82))),0.0,1.0);
  float transmission=.15+.50*lit_face+.35*panel;
  color=mix(vec3(.012,.16,.31),vec3(.20,.80,1.0),clamp(transmission+rim*.45,0.0,1.0))*strength;
  if(work_zone==0){color=mix(color,vec3(.65,.97,1.0),response*.70);}
  else{
   // Stationary constraint cells live on the actual bowed field surface.
   vec2 p=vec2(point.x-1045.0+(point.z-104.0)*.25,point.y+177.0)/22.0;
   vec2 spacing=vec2(1.0,1.7320508);
   vec2 a=mod(p,spacing)-spacing*.5;
   vec2 b=mod(p-spacing*.5,spacing)-spacing*.5;
   vec2 cell=dot(a,a)<dot(b,b)?a:b;
   float border=.5-max(dot(abs(cell),vec2(.5,.8660254)),abs(cell.x));
   float grid=1.0-smoothstep(.035,.070,abs(border));
   color=mix(color,vec3(.30,.87,1.0)*strength,grid*.45);
   opacity=clamp(opacity+grid*mask*.12,0.0,1.0);
  }
 }else if(work_kind==5){
  float face=max(0.0,dot(facing_normal,normalize(vec3(-0.2,0.6,1.0))));
  float thermal=face*0.50+0.12;
  if(work_zone==1){thermal=clamp(1.0-length((point.xy-vec2(175.0,-501.0))/vec2(55.0,38.0)),0.0,1.0);}
  else if(work_zone==2){thermal=clamp(1.0-length((point.xy-vec2(176.0,-595.56))/vec2(78.0,38.0)),0.0,1.0);}
  color=mix(vec3(0.62,0.075,0.008),vec3(1.0,0.86,0.24),thermal)*strength;
  if(work_zone==0 || work_zone==3){
   float center_hot=pow(max(0.0,facing_normal.z),.5);
   color=mix(vec3(.92,.27,.015),vec3(1.0,.91,.36),center_hot*.80)*strength;
  }
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
  float seed=1.0-smoothstep(8.0,38.0,abs(point.y-seed_origin.y));
  color=mix(color,vec3(.75,.55,1.0),seed*response*.75);
  color=color*1.18+vec3(.42,.28,.55)*pow(face,10.0)*strength;
 }else if(work_kind==16){
  float face=max(0.0,dot(facing_normal,normalize(vec3(-.35,.45,.82))));
  color=mix(vec3(.22,.06,.40),vec3(.72,.48,1.0),.45+face*.55)*strength;
  color*=.65+.35*smoothstep(0.0,1.0,formation);
  color+=vec3(.28,.19,.35)*response*strength;
 }else if(work_kind==7){
  float progress=(cycle-.72)/.28*1.16-.08;
  float distance=UV.x-progress;
  float head=exp(-pow(distance/.085,2.0))*step(.72,cycle);
  float tail=smoothstep(-.28,-.12,distance)*(1.0-smoothstep(-.08,.02,distance))*step(.72,cycle);
  vec3 flow=vec3(.04,.72,.98)*tail+vec3(.96,1.0,1.0)*head;
  color=mix(vec3(.008,.15,.22),flow,clamp(head+tail,0.0,1.0))*max(strength,.92);
 }else if(work_kind==9){
  float compression=smoothstep(.43,.60,cycle);
  float release=smoothstep(.60,.64,cycle)*(1.0-smoothstep(.66,.72,cycle));
  float facing=max(0.0,dot(facing_normal,normalize(vec3(-.4,.6,.8))));
  float arris=1.0-abs(facing_normal.z);
  vec3 nucleus=mix(vec3(.05,.68,.96),vec3(.68,1.15,1.25),facing*.50+arris*.40);
  color=mix(nucleus,vec3(1.25),compression*.40+release*.30)*strength;
  opacity=(.22+arris*.25+compression*.14)*smoothstep(.01,.20,abs(facing_normal.z));
  if(work_zone==1){color=vec3(.55,1.15,1.25)*strength;opacity=.95;}
 }else if(work_kind==10){
  float facing=max(0.0,dot(facing_normal,normalize(vec3(-.4,.6,.8))));
  vec3 dark=transfer_layer>0.0?vec3(.05,.40,.62):vec3(.015,.20,.36);
  vec3 hot=transfer_layer>0.0?vec3(.80,1.0,1.0):vec3(.20,.74,.91);
  float head=smoothstep(-.65,.80,axial_position);
  color=mix(dark,hot,.10+head*.70+facing*.20)*strength;
  float tip=smoothstep(-1.0,-.45,axial_position)*(1.0-smoothstep(.82,1.0,axial_position));
  opacity=cycle<.72 && (cycle<.60 || outlet_enabled)?tip:0.0;
 }else if(work_kind==12){
  float compression=smoothstep(.43,.60,cycle);
  color=mix(vec3(.12,.78,.98),vec3(.60,1.0,1.0),compression*.55)*strength;
  opacity=.66+compression*.18;
 }else if(work_kind==14){
  float gathering=smoothstep(0.0,.43,cycle);
  float compression=smoothstep(.43,.60,cycle)*(1.0-smoothstep(.66,.80,cycle));
  float distance_from_nucleus=abs(point.y+340.0);
  float arrival=exp(-pow((distance_from_nucleus-136.0*(1.0-gathering))/16.0,2.0));
  color=mix(vec3(.07,.66,.91),vec3(.85,1.0,1.0),arrival*.72+compression*.25)*strength;
  opacity=.40+arrival*.40+compression*.15;
 }else if(work_kind==11){
  float fill=smoothstep(0.0,.06,received_age);
  float envelope=smoothstep(0.0,.012,received_age)*(1.0-smoothstep(.15,.22,received_age));
  float lit=1.0-smoothstep(fill-.08,fill+.02,UV.x);
  float leading=exp(-pow((UV.x-fill)/.10,2.0));
  color=mix(vec3(.04,.62,.86),vec3(.90,1.0,1.0),leading)*max(strength,.92);
  opacity=envelope*lit*.95;
 }else{
  color*=strength*(0.55+0.45*max(0.0,dot(facing_normal,normalize(vec3(-0.4,0.4,0.8)))));
  if(work_kind==8 && work_zone==1){
   float electric_face=pow(max(0.0,dot(facing_normal,normalize(vec3(-.3,.5,1.0)))),5.0);
   color=mix(vec3(.02,1.10,1.20),vec3(.70,1.25,1.35),electric_face*.60+response*.30)*strength;
  }else if(work_kind==8 && work_zone==2){color=vec3(.40,.92,1.0)*strength;opacity=pulse_strength;}
 }
 if(work_kind!=1 && load_fraction<=0.0){opacity=0.0;}
 if(work_kind==3){opacity*=smoothstep(0.01,0.15,abs(facing_normal.z));}
 COLOR=vec4(color,opacity);
}
