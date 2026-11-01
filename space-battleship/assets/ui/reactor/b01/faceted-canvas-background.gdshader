shader_type canvas_item;
render_mode blend_disabled;
uniform sampler2D resting_surface:filter_linear;
uniform sampler2D working_surface:filter_linear;
uniform float core_power=0.0;
void fragment(){COLOR=vec4(mix(texture(resting_surface,UV).rgb,texture(working_surface,UV).rgb,core_power),1.0);}
