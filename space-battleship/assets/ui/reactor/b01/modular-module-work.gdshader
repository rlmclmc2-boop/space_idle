shader_type canvas_item;
render_mode unshaded, blend_add;

uniform int module_kind = 0;
uniform sampler2D work_surface : source_color, filter_linear;
uniform float load_fraction : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform vec2 work_origin_px = vec2(0.0);
uniform vec2 work_size_px = vec2(1.0);
uniform vec2 work_view_size_px = vec2(808.0, 835.0);

float disk(vec2 p, vec2 c, vec2 r) {
    return 1.0 - smoothstep(0.82, 1.0, length((p-c)/r));
}
float band(float x, float center, float half_width) {
    return 1.0-smoothstep(half_width*0.58, half_width, abs(x-center));
}
float conduit(vec2 p,vec2 a,vec2 b,float width) {
    vec2 axis=b-a;
    float t=clamp(dot(p-a,axis)/dot(axis,axis),0.0,1.0);
    return 1.0-smoothstep(width*0.6,width,length(p-mix(a,b,t)));
}

void fragment() {
    vec2 q = UV;
    float load = sqrt(load_fraction);
    vec4 surface = texture(work_surface, q);
    float material = 0.0;
    float action = 0.0;
    vec3 hue = vec3(1.0);
    if (module_kind == 0) {
        // The two charge rails refill; both mouths fire a short, sharp shot.
        float cycle = fract(phase*0.61);
        float charge = smoothstep(0.07,0.72,cycle)*(1.0-smoothstep(0.78,0.92,cycle));
        float fire = pow(1.0-smoothstep(0.0,0.075,abs(cycle-0.92)),2.0);
        material = 0.25+charge*0.95+fire*1.4;
        float left = disk(q,vec2(0.18,0.14),vec2(0.075,0.043))
                   + disk(q,vec2(0.18,0.34),vec2(0.075,0.043));
        float bolt = disk(q,vec2(0.18+0.32*fract((cycle-0.92)*9.0),0.14),vec2(0.065,0.030))
                   + disk(q,vec2(0.18+0.32*fract((cycle-0.92)*9.0),0.34),vec2(0.065,0.030));
        action = (left*fire*1.8+bolt*fire)*load;
        hue = vec3(1.0,0.55,0.14);
    } else if (module_kind == 1) {
        // Eight radial conductors are energized one after another on a contained face.
        vec2 d = (q-vec2(0.52,0.53))*vec2(1.0,1.0);
        float angle = atan(d.y,d.x);
        float r = length(d);
        float segment = pow(max(0.0,cos(angle*8.0-phase*2.5)),14.0);
        float rim = band(r,0.38,0.045);
        float spoke = segment*(1.0-smoothstep(0.25,0.41,r))*smoothstep(0.08,0.17,r);
        material = 0.2+1.15*segment;
        action = (rim*segment*0.65+spoke*0.38)*load;
        hue = vec3(0.08,0.72,1.0);
    } else if (module_kind == 2) {
        // The refractory throat loads at the crown and pours discrete drops.
        float pour = 0.25+0.75*smoothstep(0.18,0.43,fract(phase*0.29));
        float falling = fract(phase*0.72);
        vec2 throat=vec2(0.36,0.35);
        vec2 tap=vec2(0.95,0.88);
        float slot=conduit(q,throat,tap,0.035);
        float drop=disk(q,mix(throat,tap,falling),vec2(0.06,0.065));
        material = 0.3+pour*0.85;
        action = slot*(0.18+drop*0.95)*load;
        hue = vec3(1.0,0.30,0.025);
    } else {
        // Seed energy climbs inside the vessel and illuminates crystal facets.
        float growth = fract(phase*0.19);
        float climb = 1.0-smoothstep(growth-0.10,growth+0.06,1.0-q.y);
        float center = disk(q,vec2(0.52,0.54),vec2(0.39,0.48));
        float sparkle = pow(max(0.0,cos(q.x*54.0-q.y*31.0+phase*2.0)),26.0);
        material = 0.17+0.95*climb+0.25*sparkle;
        action = center*band(q.y,0.90-growth*0.70,0.026)*0.50*load;
        hue = vec3(0.68,0.34,1.0);
    }
    vec3 working = surface.rgb*surface.a*material*load*1.65 + hue*action;
    COLOR = vec4(working,1.0);
}
