shader_type canvas_item;
render_mode unshaded;
varying vec2 point;
varying vec4 event;
const vec3 SMOKE=vec3(0.666666667,0.643137255,0.631372549);
const vec3 AMBER=vec3(1.0,0.678431373,0.298039216);
const vec3 HOT=vec3(1.0,0.941176471,0.745098039);
void vertex(){event=COLOR;COLOR=vec4(1.0);point=(UV-vec2(0.5))*48.0;VERTEX=point;}
float line_mask(vec2 p,vec2 a,vec2 b,float width){
 vec2 delta=b-a;float len=length(delta);vec2 axis=delta/max(0.0001,len);vec2 q=p-a;
 float across=abs(dot(q,vec2(-axis.y,axis.x)))-width*0.5;
 float along=max(-dot(q,axis),dot(q,axis)-len);
 return clamp(1.0-max(across,along),0.0,1.0);
}
vec4 over(vec4 dst,vec3 rgb,float alpha){float a=clamp(alpha,0.0,1.0);return vec4(rgb*a+dst.rgb*(1.0-a),a+dst.a*(1.0-a));}
float disc(vec2 p,float r){return step(length(p),r);}
void fragment(){
 float age=event.x;float budget=clamp(event.y,0.0,1.0);vec4 c=vec4(0.0);
 if(event.w>0.5){
  if(age>=0.0&&age<0.10){float fade=(1.0-age/0.10)*mix(0.40,1.0,budget);float hot=clamp(1.0-age/0.045,0.0,1.0);c=over(c,HOT,hot*fade*line_mask(point,vec2(-3.0,0.0),vec2(5.0,0.0),2.5));}
 }else if(age>=0.0&&age<0.22){
  float t=age/0.22;float decoration=mix(0.45,1.0,budget);float fade=(1.0-t)*(1.0-t)*decoration;float size=event.z>0.5?1.12:1.0;
  for(int i=0;i<3;i++){
   float angle=float(i)*6.28318530718/3.0+0.4;vec2 radial=vec2(cos(angle),sin(angle));vec2 q=point-radial*(2.0+6.0*t);float radius=4.0+3.0*t;
   c=over(c,SMOKE,fade*0.32*disc(q,radius));c=over(c,AMBER,clamp(1.0-age/0.13,0.0,1.0)*decoration*disc(q,radius*0.8));
  }
  for(int i=0;i<3;i++){
   float angle=float(i)*6.28318530718/3.0;vec2 radial=vec2(cos(angle),sin(angle));vec2 end=radial*(4.0+14.0*t)*size;
   c=over(c,AMBER,fade*0.6*line_mask(point,end-radial*3.0,end,1.3));
  }
  c=over(c,HOT,clamp(1.0-age/0.065,0.0,1.0)*decoration*disc(point,(4.0+t)*size));
 }
 COLOR=vec4(c.rgb/max(c.a,0.00001),c.a);
}
