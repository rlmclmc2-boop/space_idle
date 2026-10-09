// Diagnostic transfer for Godot4.6.3 Compatibility; not a production material.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
uniform sampler2D cached_color : filter_nearest, repeat_disable;
uniform sampler2D cached_depth : filter_nearest, repeat_disable;
void vertex() { POSITION=vec4(VERTEX.xy,1.0,1.0); }
uniform sampler2D transfer_lut : filter_nearest, repeat_disable;
vec3 retain_bytes(vec3 color) {
 vec3 index=(floor(color*255.0+0.5)+vec3(0.5))/256.0;
 return vec3(texture(transfer_lut,vec2(index.r,0.5)).r,texture(transfer_lut,vec2(index.g,0.5)).r,texture(transfer_lut,vec2(index.b,0.5)).r);
}
void fragment() {
 ALBEDO=retain_bytes(texture(cached_color,SCREEN_UV).rgb);
 vec3 bytes=round(texture(cached_depth,SCREEN_UV).rgb*255.0);
 DEPTH=dot(bytes,vec3(65536.0,256.0,1.0))/16777215.0;
}
