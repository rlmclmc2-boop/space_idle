shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float load_fraction : hint_range(0.0,1.0) = 0.0;
uniform vec4 route_loads = vec4(0.0);
uniform float phase = 0.0;
uniform sampler2D core_work_surface : source_color, filter_linear;

float line_segment(vec2 p, vec2 a, vec2 b, float width) {
    vec2 axis = b-a;
    float t = clamp(dot(p-a,axis)/dot(axis,axis),0.0,1.0);
    return 1.0-smoothstep(width*0.65,width,length(p-mix(a,b,t)));
}
float disk(vec2 p,vec2 c,float r) {
    return 1.0-smoothstep(r*0.65,r,length(p-c));
}

void fragment() {
    vec2 p=(UV-vec2(0.5))*vec2(1.0,1.10);
    float r=length(p);
    float load=sqrt(load_fraction);
    vec3 light=vec3(0.0);
    if (r < 0.465) {
        // Broken spiral filaments collapse into the ignition point. A complete
        // rotating ring reads as a dashboard dial inside the glass chamber.
        float angle=atan(p.y,p.x);
        float spiral=pow(max(0.0,sin(angle*7.0+r*36.0-phase*2.8)),8.0);
        float folds=0.35+0.65*pow(max(0.0,sin(r*23.0+angle*3.0+phase*1.7)),4.0);
        float compression=spiral*folds*smoothstep(0.07,0.13,r)
                          *(1.0-smoothstep(0.31,0.44,r));
        float ignition=disk(p,vec2(0.0),0.09)*(0.45+0.55*pow(max(0.0,sin(phase*2.95)),4.0));
        light += vec3(0.16,0.70,1.0)*(compression*0.37+ignition*1.14)*load;
        // Each outlet has its own Owner-driven packet travelling outward.
        vec2 ends[4]=vec2[4](vec2(-0.38,-0.24),vec2(0.39,-0.24),
                              vec2(-0.36,0.31),vec2(0.36,0.31));
        float powers[4]=float[4](route_loads.x,route_loads.y,route_loads.z,route_loads.w);
        for (int i=0;i<4;i++) {
            vec2 start=normalize(ends[i])*0.10;
            float progress=fract(phase*0.52-float(i)*0.17);
            float guide=line_segment(p,start,ends[i],0.017)*0.23;
            float packet=disk(p,mix(start,ends[i],progress),0.028);
            light += vec3(0.06,0.76,1.0)*(guide+packet*1.25)*powers[i];
        }
        vec4 source=texture(core_work_surface,UV);
        light += source.rgb*source.a*load*0.25;
    }
    COLOR=vec4(light,1.0);
}
