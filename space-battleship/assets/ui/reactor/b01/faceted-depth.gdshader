shader_type spatial;
render_mode unshaded,cull_disabled;
varying float source_z;
vec3 srgb_decode(vec3 c){return mix(c/12.92,pow((c+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),c));}
void vertex(){source_z=(MODEL_MATRIX*vec4(VERTEX,1.0)).z;}
void fragment(){
 float packed=floor(clamp((source_z+256.0)/1024.0,0.0,1.0)*65535.0+0.5);
 vec3 bytes=vec3(floor(packed/256.0),mod(packed,256.0),0.0)/255.0;
 ALBEDO=OUTPUT_IS_SRGB?bytes:srgb_decode(bytes);
}
