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
    if (module_kind == 1) q.x *= 307.0/265.0;
    float load = sqrt(load_fraction);
    vec4 surface = texture(work_surface, UV);
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
        float establish = smoothstep(0.03,0.88,clamp(phase*0.18,0.0,1.0));
        float front_radius = 0.025+establish*0.19;
        float front = band(r,front_radius,0.012);
        // Bend the three line families across the convex lens rather than
        // projecting a flat wire grid over a circular decal.
        vec2 dome = d*(1.0+0.72*pow(r/0.22,2.0));
        float grid = band(fract(dome.x*13.0+dome.y*7.5),0.5,0.055)
                   + band(fract(dome.x*13.0-dome.y*7.5),0.5,0.055)
                   + band(fract(dome.y*15.0),0.5,0.045);
        float facing = 0.40+0.60*sqrt(max(0.0,1.0-pow(r/0.23,2.0)));
        float lattice = min(grid,1.0)*facing*(1.0-smoothstep(front_radius-0.01,front_radius+0.015,r));
        float curved = band(d.y+0.42*d.x*d.x, -0.052+establish*0.075,0.012);
        float glancing = band(d.x-0.33*d.y*d.y,-0.11+establish*0.09,0.009);
        float sweep_y = (q.y-0.412)/0.31;
        float visible_arc = 1.0-smoothstep(0.82,1.0,abs(sweep_y));
        float bow = sqrt(max(0.0,1.0-sweep_y*sweep_y));
        float dome_x = 0.642+(0.045+0.370*establish)*bow;
        float shield_shell = band(q.x,dome_x,0.010)*visible_arc;
        float shell_depth = band(q.x,dome_x-0.030,0.008)*visible_arc;
        float shell_volume = smoothstep(0.65,0.79,q.x)
                             *(1.0-smoothstep(dome_x-0.035,dome_x+0.012,q.x))*visible_arc;
        float canopy = surface.a*smoothstep(0.73,0.89,q.x);
        float lens = surface.a;
        material = 0.04+0.16*lattice;
        action = ((front*0.95+lattice*0.16+curved*0.25+glancing*0.12)*lens
                  +shield_shell*1.04+shell_depth*0.29+shell_volume*0.38
                  +canopy*1.18)*load;
        hue = vec3(0.08,0.72,1.0);
    } else if (module_kind == 2) {
        // The refractory throat loads at the crown and pours discrete drops.
        float pour = 0.55+0.45*smoothstep(0.18,0.43,fract(phase*0.29));
        // These coordinates are measured in the aligned rendered work crop,
        // after the Blender camera and shared port translation.
        vec2 throat=vec2(0.49,0.35);
        vec2 elbow=vec2(0.49,0.46);
        vec2 tap=vec2(0.61,0.54);
        float pool=disk(q,vec2(0.55,0.49),vec2(0.105,0.055));
        float slot=conduit(q,elbow,tap,0.010);
        float fall=fract(phase*0.72);
        vec2 bead_pos=fall<0.28 ? mix(throat,elbow,fall/0.28)
                                  : mix(elbow,tap,(fall-0.28)/0.72);
        float drop=disk(q,bead_pos,vec2(0.017,0.019))*surface.a;
        float heat_ribbons = 0.5+0.5*sin(q.x*66.0+phase*2.4)*sin(q.y*38.0-phase*3.2);
        material = 0.14+pour*(0.29+0.72*heat_ribbons);
        float heat_bounce = disk(q,vec2(0.54,0.47),vec2(0.27,0.23))
                            -disk(q,vec2(0.54,0.47),vec2(0.16,0.12));
        float inlet_glow=disk(q,vec2(0.51,0.49),vec2(0.028,0.024));
        float outlet_glow=disk(q,vec2(0.69,0.57),vec2(0.03,0.023));
        float flow_t=fract(phase*0.47);
        vec2 flow_pos=mix(vec2(0.51,0.49),vec2(0.68,0.56),flow_t);
        float moving_heat=disk(q,flow_pos,vec2(0.027,0.015))*surface.a;
        action = (pool*surface.a*0.04+slot*surface.a*0.08+drop*0.42
                  +inlet_glow*surface.a*0.25+outlet_glow*surface.a*0.34
                  +moving_heat*0.42+heat_bounce*0.04)*pour*load;
        hue = vec3(1.0,0.30,0.025);
    } else {
        // Five seed sockets feed a growth front up distinct crystal columns.
        // The crystal remains condensed after the front reaches its crown;
        // facet reflections continue to move over the solid volume.
        float growth = clamp(phase*0.12,0.0,1.0);
        float front_y = 0.75-growth*0.37;
        float grown = smoothstep(front_y-0.05,front_y+0.07,q.y);
        float facets = pow(max(0.0,cos(q.x*62.0-q.y*37.0+phase*1.5)),18.0);
        float seeds = 0.0;
        float climbing = 0.0;
        float feed = 0.0;
        for (int i=0;i<5;i++) {
            float column = 0.51+float(i)*0.063;
            seeds += disk(q,vec2(column,0.72),vec2(0.012,0.015));
            climbing += band(q.x,column,0.008)*band(q.y,front_y,0.018);
            feed += band(q.x,column,0.003)*smoothstep(front_y-0.015,front_y+0.015,q.y)
                    *(1.0-smoothstep(0.72,0.75,q.y));
        }
        material = 0.04+1.10*grown+0.25*facets*grown;
        action = ((seeds*0.28+climbing*0.62)*surface.a+feed*0.30)*load;
        hue = vec3(0.68,0.34,1.0);
    }
    vec3 working = surface.rgb*surface.a*material*load*(module_kind == 3 ? 0.88 : 1.65) + hue*action;
    COLOR = vec4(working,1.0);
}
