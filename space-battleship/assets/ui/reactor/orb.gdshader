shader_type canvas_item;
uniform float phase = 0.0;
uniform float power : hint_range(0.0, 1.0) = 0.0;
void fragment() {
 vec2 p = (UV*2.0-1.0)/0.625;
 float r=length(p);
 float edge=1.0-smoothstep(0.96,1.02,r);
 float z=sqrt(max(0.0,1.0-r*r));
 vec3 normal=normalize(vec3(p,z));
 float light=max(0.0,dot(normal,normalize(vec3(-0.45,-0.65,1.0))));
 float swirl=sin(p.x*6.0+p.y*4.0+phase*1.7+sin(p.y*7.0-phase));
 float ribbon=pow(max(0.0,1.0-abs(swirl)),5.0)*power;
 float center=exp(-dot(p,p)*6.0);
 float fresnel=pow(1.0-z,3.0);
 vec3 body=mix(vec3(0.035,0.14,0.22),vec3(0.28,0.70,0.73),light*0.70);
 body+=vec3(0.20,0.59,0.57)*ribbon*0.55;
 body=mix(body,vec3(1.0,0.63,0.29),center*sqrt(power)*0.85);
 body+=vec3(0.51,0.93,0.89)*fresnel*(0.2+0.35*power);
 float shine=exp(-dot(p-vec2(-0.29,-0.36),p-vec2(-0.29,-0.36))*35.0);
 body+=vec3(0.77,0.95,0.85)*shine*(0.28+power*0.35);
 // Small plasma packets converge inside the sphere, then join the outlet axis.
 for(int i=0;i<5;i++) {
  float t=fract(phase*0.34+float(i)/5.0);
  float side=sin(float(i)*2.4+phase*0.25);
  vec2 start=vec2(side*0.67,-0.45+cos(float(i))*0.23);
  vec2 packet=mix(start,vec2(0.0,0.88),t);
  float spark=exp(-dot(p-packet,p-packet)*300.0)*sin(t*3.14159)*power;
  body+=vec3(0.60,0.88,0.60)*spark*0.6;
 }
 COLOR=vec4(body*(0.65+0.35*sqrt(power)),edge);
}
