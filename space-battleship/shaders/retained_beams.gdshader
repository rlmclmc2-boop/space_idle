shader_type canvas_item;
render_mode unshaded;
uniform float clock=0.0;
uniform vec4 evolution_color=vec4(1.0,1.0,1.0,0.0);
varying float beam_length;
varying vec4 state; // width, power, actual hit pulse, charge (-1 active)
varying vec4 timing; // presentation clock, full cue age, orientation, link mode
varying vec2 point;
const vec3 CORE=vec3(0.9294118,1.0,0.9764706);
const vec3 ENERGY=vec3(0.5529412,0.9176471,1.0);
void vertex(){
 beam_length=COLOR.r;timing=vec4(clock,COLOR.g,COLOR.b,COLOR.a);state=INSTANCE_CUSTOM;
 COLOR=vec4(1.0);
 float body=max(0.7,state.x)*mix(0.65,1.8,clamp(state.y,0.0,1.0));
 float pad=max(24.0,body*3.0+10.0);
 point=vec2(mix(-pad,beam_length+pad,UV.x),mix(-pad,pad,UV.y));
 VERTEX=point;
}
float coverage(float d,float aa){return clamp(0.5-d/aa,0.0,1.0);}
float line_mask(vec2 p,vec2 a,vec2 b,float width,float aa){
 vec2 d=b-a;float len=length(d);vec2 axis=d/max(len,0.0001);vec2 q=p-a;
 return coverage(max(max(-dot(q,axis),dot(q,axis)-len),abs(dot(q,vec2(-axis.y,axis.x)))-width*0.5),aa);
}
float disc(vec2 p,float radius,float aa){return coverage(length(p)-radius,aa);}
float ring(vec2 p,float radius,float width,float aa){return coverage(abs(length(p)-radius)-width*0.5,aa);}
vec4 over(vec4 dst,vec3 rgb,float alpha){float a=clamp(alpha,0.0,1.0);return vec4(rgb*a+dst.rgb*(1.0-a),a+dst.a*(1.0-a));}
vec3 ramp(float p){if(p>=0.999999)return vec3(0.9411765,0.2901961,1.0);if(p<0.5)return mix(ENERGY,vec3(0.1490196,0.5333333,1.0),p*2.0);return mix(vec3(0.1490196,0.5333333,1.0),vec3(0.572549,0.3568627,1.0),(p-0.5)*2.0);}
void fragment(){
 vec2 p=point;float aa=max(0.35,max(length(dFdx(p)),length(dFdy(p))));
 float beam_clock=timing.x;float power=clamp(state.y,0.0,1.0);float pulse=clamp(state.z,0.0,1.0);
 vec4 c=vec4(0.0);vec2 end=vec2(beam_length,0.0);
 if(timing.w>0.5){
  vec3 light=vec3(0.654902,1.0,0.9411765);
  c=over(c,light,0.28*line_mask(p,vec2(0.0),end,4.0,aa));
  c=over(c,light,line_mask(p,vec2(0.0),end,1.4,aa));
  c=over(c,vec3(0.9490196,1.0,0.9882353),disc(p-end*fract(beam_clock*2.0),2.3,aa));
 }else if(state.w>=0.0){
  float progress=clamp(state.w,0.0,1.0);float radius=mix(14.0,6.0,progress);
  c=over(c,ENERGY,(0.12+progress*0.16)*disc(p,4.0+progress*3.0,aa));
  c=over(c,CORE,(0.45+progress*0.5)*disc(p,1.3+progress*1.3,aa));
  for(int i=0;i<2;i++){
   float side=float(i)*2.0-1.0;vec2 a=vec2(-4.0,side*radius);vec2 b=vec2(2.0,side*radius*0.5);
   float mask=max(line_mask(p,a,b,1.3,aa),line_mask(p,b,vec2(0.0),1.3,aa));
   c=over(c,ENERGY,(0.3+progress*0.5)*mask);
  }
  float relative=mod(atan(p.y,p.x)-(beam_clock*1.2-timing.z)+6.28318530718,6.28318530718);
  c=over(c,ENERGY,0.45*ring(p,radius,1.2,aa)*step(relative,3.14159265359*(0.3+progress*0.6)));
 }else if(state.w>-1.5 && beam_length>=0.5){
  bool full=power>=0.999999;vec3 energy=ramp(power);
  float body=max(0.7,state.x)*mix(0.65,1.8,power);float core=max(0.35,body*(full?0.40:0.28));
  c=over(c,energy,(0.025+power*0.14)*line_mask(p,vec2(0.0),end,body*2.1,aa));
  c=over(c,energy,(0.15+power*0.60)*line_mask(p,vec2(0.0),end,body,aa));
  c=over(c,CORE,(0.22+power*0.73+pulse*0.05)*line_mask(p,vec2(0.0),end,core,aa));
  float segment=min(14.0,beam_length*0.07);
  for(int i=0;i<3;i++){
   float phase=fract(beam_clock*0.85+float(i)/3.0);float along=phase*max(0.0,beam_length-segment);
   vec2 start=vec2(along,sin(beam_clock*2.0+float(i)*2.1)*body*0.22);
   c=over(c,CORE,(0.06+power*0.16)*line_mask(p,start,start+vec2(segment,0.0),max(0.7,core*0.55),aa));
  }
  c=over(c,energy,0.27*disc(p,body*0.63,aa));
  c=over(c,CORE,(0.25+power*0.65)*disc(p,core*0.75,aa));
  vec2 q=p-end;float radius=1.8+body*0.40+power*3.0+pulse*0.35;
  c=over(c,energy,(0.11+pulse*0.07)*disc(q,radius*1.25,aa));
  vec2 radii=vec2(radius*0.42,radius);float k0=length(q/radii);float k1=length(q/(radii*radii));
  float ellipse=abs(k0*(k0-1.0)/max(k1,0.0001));
  c=over(c,energy,(0.56+pulse*0.18)*coverage(ellipse-0.6,aa));
  c=over(c,CORE,(0.25+power*0.70)*disc(q,0.7+body*0.12+power*1.2+pulse*0.15,aa));
  for(int i=0;i<2;i++){
   float side=float(i)*2.0-1.0;float shift=sin(beam_clock*3.0+side)*0.8;
   c=over(c,energy,(0.4+pulse*0.25)*line_mask(q,vec2(0.0,side*radius*0.65),vec2(-(1.5+shift),side*radius*1.3),1.0,aa));
  }
  if(timing.y>=0.0 && timing.y<=0.18){float t=timing.y/0.18;c=over(c,vec3(0.9607843,0.6784314,1.0),(1.0-t)*0.65*ring(q,8.0+10.0*t,1.8,aa));}
 }
 vec3 rgb=c.rgb/max(c.a,0.00001);
 rgb=mix(rgb,evolution_color.rgb,0.72*evolution_color.a);
 COLOR*=vec4(rgb,c.a);
}
