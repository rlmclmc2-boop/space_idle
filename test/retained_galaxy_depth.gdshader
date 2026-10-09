// Diagnostic transfer for Godot4.6.3 Compatibility; not a production material.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
uniform sampler2D transfer_lut : filter_nearest, repeat_disable;
vec3 retain_bytes(vec3 color) {
 vec3 index=(floor(color*255.0+0.5)+vec3(0.5))/256.0;
 return vec3(texture(transfer_lut,vec2(index.r,0.5)).r,texture(transfer_lut,vec2(index.g,0.5)).r,texture(transfer_lut,vec2(index.b,0.5)).r);
}
void fragment() {
 float value=floor(FRAGCOORD.z*16777215.0+0.5);
 vec3 bytes=vec3(floor(value/65536.0),floor(mod(value,65536.0)/256.0),mod(value,256.0));
 ALBEDO=retain_bytes(bytes/255.0);
}
