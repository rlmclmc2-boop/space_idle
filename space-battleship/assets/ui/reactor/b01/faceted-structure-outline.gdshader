shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;
// Geometric silhouette of the same closed housing. Used only in the static
// room/structure bake; it is disabled for depth used by the working meshes.
uniform float stroke_width = 1.5;
void vertex(){ VERTEX += NORMAL * stroke_width; }
void fragment(){ ALBEDO = vec3(.012,.024,.036); }
