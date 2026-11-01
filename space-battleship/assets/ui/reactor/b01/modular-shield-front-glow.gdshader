shader_type canvas_item;
render_mode unshaded, blend_add;

uniform sampler2D front_surface : source_color, filter_linear;
uniform float load_fraction : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;

void fragment() {
    vec2 d = (UV-vec2(0.642,0.412))*vec2(1.0,1.06);
    float r = length(d);
    float metal = texture(front_surface,UV).a;
    float shoe = smoothstep(0.20,0.235,r)*(1.0-smoothstep(0.275,0.315,r));
    float incoming = max(0.0,dot(normalize(d+vec2(0.0001,0.0)),vec2(-0.78,0.62)));
    float pulse = 0.82+0.18*sin(phase*2.2-r*13.0);
    float light = metal*shoe*(0.25+0.75*incoming)*pulse*sqrt(load_fraction);
    COLOR = vec4(vec3(0.09,0.57,1.0)*light*0.48,1.0);
}
