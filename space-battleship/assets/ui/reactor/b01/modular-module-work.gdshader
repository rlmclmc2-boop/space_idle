shader_type canvas_item;
render_mode unshaded, blend_add;

uniform int module_kind = 0; // 0 weapon, 1 shield, 2 smelter, 3 crystal
uniform float load_fraction : hint_range(0.0,1.0) = 0.0;
uniform float phase = 0.0;

float ellipse(vec2 p, vec2 c, vec2 r) {
    return 1.0 - smoothstep(0.88, 1.0, length((p-c)/r));
}

void fragment() {
    vec2 p = UV;
    float load = sqrt(load_fraction);
    vec3 tint = vec3(0.0);
    float a = 0.0;
    if (module_kind == 0) {
        // Two independent muzzle chambers fire in short synchronized bursts.
        float burst = pow(max(0.0, cos(phase*7.4)), 18.0);
        float twin = ellipse(p,vec2(0.08,0.27),vec2(0.085,0.018))
                   + ellipse(p,vec2(0.11,0.38),vec2(0.085,0.018));
        a = min(0.55, burst*twin*load*0.55);
        tint = vec3(1.0,0.48,0.08);
    } else if (module_kind == 1) {
        // A constrained shield face rotates tracers inside its circular rim.
        vec2 d = (p-vec2(0.77,0.39))*vec2(1.0,1.08);
        float r = length(d);
        float angle = atan(d.y,d.x);
        float rim = (1.0-smoothstep(0.012,0.025,abs(r-0.265)));
        float sector = pow(max(0.0,cos(angle*8.0-phase*1.5)),8.0);
        a = rim*sector*load*0.60;
        tint = vec3(0.12,0.72,1.0);
    } else if (module_kind == 2) {
        // Molten material falls in the furnace's central pouring slot.
        float throat = ellipse(p,vec2(0.53,0.62),vec2(0.055,0.18));
        float fall = pow(max(0.0,cos((p.y*7.0-phase*0.65)*6.2831853)),6.0);
        a = throat*(0.20+0.40*fall)*load;
        tint = vec3(1.0,0.32,0.035);
    } else {
        // Crystal growth rises in the chamber and hits facets independently.
        float vessel = ellipse(p,vec2(0.60,0.52),vec2(0.14,0.25));
        float growth = pow(max(0.0,cos((p.y*5.0+phase*0.46)*6.2831853)),8.0);
        float facet = pow(max(0.0,cos(p.x*35.0+phase*0.27)),12.0);
        a = vessel*(0.18*facet+0.42*growth)*load;
        tint = vec3(0.65,0.25,1.0);
    }
    COLOR = vec4(tint,a);
}
