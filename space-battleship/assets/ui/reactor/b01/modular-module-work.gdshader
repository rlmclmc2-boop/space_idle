shader_type canvas_item;
render_mode unshaded, blend_add;

uniform int module_kind = 0;
uniform sampler2D work_surface : source_color, filter_linear;
uniform float load_fraction : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;

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
        float mouths = disk(q,vec2(0.20,0.125),vec2(0.025,0.023))
                     + disk(q,vec2(0.20,0.285),vec2(0.025,0.023));
        float coil = band(q.x,0.38-0.26*charge,0.022)*
                     (band(q.y,0.125,0.018)+band(q.y,0.285,0.018));
        float shot = fire*(disk(q,vec2(0.18-0.07*fract((cycle-0.92)*9.0),0.125),vec2(0.024,0.019))
                         +disk(q,vec2(0.18-0.07*fract((cycle-0.92)*9.0),0.285),vec2(0.024,0.019)));
        action = (mouths*fire*1.7+coil*0.34+shot)*load;
        hue = vec3(1.0,0.55,0.14);
    } else if (module_kind == 1) {
        // Curved face receives a travelling pressure front and several grazing
        // reflections. The lens mesh, rather than a full rectangle, clips it.
        vec2 d = (q-vec2(0.642,0.412))*vec2(1.0,1.06);
        float r = length(d);
        float establish = smoothstep(0.03,0.88,fract(phase*0.18));
        float front_radius = 0.025+establish*0.19;
        float front = band(r,front_radius,0.012);
        float grid = band(fract(q.x*13.0+q.y*7.5),0.5,0.055)
                   + band(fract(q.x*13.0-q.y*7.5),0.5,0.055)
                   + band(fract(q.y*15.0),0.5,0.045);
        float lattice = min(grid,1.0)*(1.0-smoothstep(front_radius-0.01,front_radius+0.015,r));
        float curved = band(d.y+0.42*d.x*d.x, -0.052+establish*0.075,0.012);
        float glancing = band(d.x-0.33*d.y*d.y,-0.11+establish*0.09,0.009);
        float lens = surface.a;
        material = 0.04+0.22*lattice;
        action = (front*1.15+lattice*0.62+curved*0.36+glancing*0.16)*lens*load;
        hue = vec3(0.08,0.72,1.0);
    } else if (module_kind == 2) {
        // The refractory throat loads at the crown and pours discrete drops.
        float pour = 0.25+0.75*smoothstep(0.18,0.43,fract(phase*0.29));
        vec2 throat=vec2(0.42,0.64);
        vec2 tap=vec2(0.63,0.79);
        float pool=disk(q,vec2(0.42,0.65),vec2(0.105,0.055));
        float slot=conduit(q,vec2(0.48,0.70),tap,0.010);
        float drop=0.0;
        for (int i=0;i<3;i++) {
            float fall=fract(phase*0.72+float(i)/3.0);
            drop += disk(q,mix(throat,tap,fall),vec2(0.012,0.017));
        }
        float heat_ribbons = 0.5+0.5*sin(q.x*41.0+phase*2.4)*sin(q.y*32.0-phase*3.2);
        material = 0.07+pour*(0.38+0.85*heat_ribbons);
        action = (pool*0.20+slot*0.14+drop*0.54)*pour*load;
        hue = vec3(1.0,0.30,0.025);
    } else {
        // Five seed sockets feed a growth front up distinct crystal columns.
        float growth = fract(phase*0.19);
        float front_y = 0.79-growth*0.35;
        float grown = smoothstep(front_y-0.05,front_y+0.07,q.y);
        float facets = pow(max(0.0,cos(q.x*62.0-q.y*37.0+phase*1.5)),18.0);
        float seeds = 0.0;
        float climbing = 0.0;
        float feed = 0.0;
        for (int i=0;i<5;i++) {
            float column = 0.46+float(i)*0.07;
            seeds += disk(q,vec2(column,0.77),vec2(0.012,0.015));
            climbing += band(q.x,column,0.008)*band(q.y,front_y,0.018);
            feed += band(q.x,column,0.003)*smoothstep(front_y-0.015,front_y+0.015,q.y)
                    *(1.0-smoothstep(0.77,0.79,q.y));
        }
        material = 0.04+1.10*grown+0.25*facets*grown;
        action = ((seeds*0.28+climbing*0.62)*surface.a+feed*0.30)*load;
        hue = vec3(0.68,0.34,1.0);
    }
    vec3 working = surface.rgb*surface.a*material*load*(module_kind == 3 ? 0.88 : 1.65) + hue*action;
    COLOR = vec4(working,1.0);
}
