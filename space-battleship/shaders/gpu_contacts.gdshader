shader_type canvas_item;
render_mode unshaded;
uniform float clock = 0.0;
// Geometry and fade follow combat_presentation.draw_contacts, with its simulation clock.
vec2 ortho(vec2 p) { return vec2(p.y,-p.x); }
vec2 ring_point(int op,int index,float radius) {
 if(op==3){float a=float(index)*6.28318530718/11.0;return vec2(cos(a),sin(a))*radius;}
 if(index==0)return vec2(radius*0.65,0.0);
 if(index==1)return vec2(0.0,-radius);
 if(index==2)return vec2(-radius*0.65,0.0);
 return vec2(0.0,radius);
}
void vertex() {
 // Other feedback primitives retain their original vertex/color/texture path.
 if(INSTANCE_CUSTOM.z>=9.0){
 int op=int(UV.x+0.5);float point_index=VERTEX.x;float side=VERTEX.y;float feather_alpha=COLOR.a;
 float age=clock-INSTANCE_CUSTOM.x;
 bool physical=INSTANCE_CUSTOM.y>50.0;bool launch=INSTANCE_CUSTOM.z>10.5;bool critical=INSTANCE_CUSTOM.w>0.5;
 bool enemy=op<6;float t=clamp(age/(enemy?0.12:(launch?0.075:0.13)),0.0,1.0);float fade=1.0-t;
 vec4 cyan=vec4(0.2588235294,0.9294117647,0.9333333333,1.0);
 vec4 blue=vec4(0.2235294118,0.5450980392,0.8745098039,1.0);
 vec4 white=vec4(0.9450980392,1.0,1.0,1.0);
 vec4 tint=physical?vec4(1.0,0.6862745098,0.3803921569,fade):vec4(0.3921568627,0.7098039216,1.0,fade);
 vec2 a=vec2(0.0),b=vec2(0.0),p=vec2(0.0);float width=1.0;bool visible_part=true;
 float radius=3.0+4.0*t;
 if(enemy){
  visible_part=launch?(physical?op==0:(op==1||op==2)):(physical?op==3:(op==4||op==5));
  if(op==0){a=vec2(-2.0,0.0);b=vec2(4.0,0.0);width=2.5;}
  if(op==1||op==2){a=vec2(0.0,op==1?2.0:-2.0);b=vec2(4.0,0.0);width=1.0;}
  if(op==4){a=vec2(0.0,radius);b=vec2(0.0,-radius);width=1.2;}
  if(op==5){a=vec2(-radius*0.6,0.0);b=vec2(radius*0.6,0.0);width=1.0;}
 }else{
  visible_part=launch?(op>=6&&op<=9):op>=10;
  if(launch&&age>=0.075)visible_part=false;
  tint=cyan;tint.a=fade;
  float kick=-3.0*sin(t*3.14159265359);
  if(op==6||op==7){
   if(point_index<0.5)p=vec2(kick-2.0,0.0);
   else if((op==6&&point_index<1.5)||(op==7&&point_index>1.5))p=vec2(kick+15.0*fade,op==6?-4.0*fade:4.0*fade);
   else p=vec2(kick+9.0*fade,0.0);
  }
  if(op==8){a=vec2(kick,4.0+3.0*t);b=vec2(kick,-4.0-3.0*t);width=2.3;tint=blue;tint.a=fade*0.9;}
  if(op==9){a=vec2(kick,0.0);b=vec2(kick+11.0*fade,0.0);width=3.0*fade+0.5;tint=white;tint.a=fade;}
  if(op==10){radius=(4.0+10.0*t)*(critical?1.15:1.0);tint.a=fade*0.9;}
  if(op==11){
   if(t>=0.45)visible_part=false;
   int i=int(point_index+0.5);p=i==0?vec2(5.0,0.0):(i==1?vec2(0.0,-4.0):(i==2?vec2(-5.0,0.0):vec2(0.0,4.0)));
   tint=white;tint.a=fade;
  }
  if(op>=12){float i=float(op-12);float angle=(-1.5+i)*0.7;vec2 d=-vec2(cos(angle),sin(angle));a=d*(4.0+8.0*t);b=d*(8.0+14.0*t);width=1.8;tint=(op%2==0)?cyan:blue;tint.a=fade;}
 }
 if(op==3||op==10){
  int count=op==3?11:4;int i=int(point_index+0.5);
  p=ring_point(op,i,radius);
  vec2 prev=normalize(p-ring_point(op,(i+count-1)%count,radius));
  vec2 next=normalize(ring_point(op,(i+1)%count,radius)-p);
  vec2 bisector=normalize(prev-next);float sine=dot(bisector,ortho(prev));
  float miter=abs(sine)>0.000001?clamp(1.0/sine,-3.0,3.0):1.0;
  vec2 base=bisector*miter;
  float half_requested=(op==3?1.2:2.0*fade+0.5)*0.5;
  float border=half_requested<1.0?1.25*half_requested:1.25;
  p+=base*side*(half_requested*0.5+UV.y*border);
 }else if(op!=6&&op!=7&&op!=11){
  width=width<=2.5?width*0.5:(width<=5.0?mix(width*0.5,width-0.625,(width-2.5)/2.5):width-0.625);
  vec2 diff=a-b;float length_value=length(diff);vec2 direction=length_value>0.000001?diff/length_value:vec2(0.0);
  float border=width<1.0?1.25*width:1.25;
  float cap=floor(UV.y/2.0)-1.0;float outer=mod(UV.y,2.0);
  p=mix(a,b,point_index)+ortho(direction)*side*(width*0.5+outer*border)+direction*cap*border;
 }
 if(op==3){float angle=INSTANCE_CUSTOM.y-100.0;float c=cos(angle);float sn=sin(angle);p=mat2(vec2(c,-sn),vec2(sn,c))*p;}
 if(!visible_part){p=vec2(0.0);tint.a=0.0;}
 VERTEX=p;COLOR=vec4(tint.rgb,tint.a*feather_alpha);
}
}
