shader_type canvas_item;
render_mode unshaded, blend_disabled;

// Only battlefield.gd's opaque, untextured background rectangles use this.
varying vec4 solid_color;

void vertex() {
	solid_color = COLOR;
}

void fragment() {
	COLOR = solid_color;
}
