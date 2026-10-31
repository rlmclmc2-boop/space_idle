shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float load_fraction : hint_range(0.0,1.0) = 0.0;
uniform float phase = 0.0;
uniform sampler2D core_work_surface : source_color, filter_linear;

float hash21(vec2 p) {
    return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}

void fragment() {
    vec2 centered = (UV-vec2(0.5,0.5))*vec2(1.0,1.06);
    float radius = length(centered);
    if (radius > 0.48) {
        COLOR = vec4(0.0);
    } else {
        float azimuth = atan(centered.y,centered.x);
        // Thin orbital constraint tracks, with a phase progression distinct
        // from the directed packets travelling through each conduit.
        float ring = 1.0-smoothstep(0.009,0.021,abs(radius-(0.18+0.11*sin(azimuth*2.0+phase*0.35))));
        float cage = 1.0-smoothstep(0.011,0.024,abs(sin(azimuth*7.0-phase*0.27)));
        float marker = pow(max(0.0,cos(azimuth*5.0+phase*0.8)),18.0);
        vec2 grid = centered*36.0 + vec2(phase*0.38,-phase*0.23);
        vec2 cell = floor(grid);
        vec2 jitter = vec2(hash21(cell),hash21(cell+vec2(7.1,3.8)));
        float particle = 1.0-smoothstep(0.05,0.13,length(fract(grid)-jitter));
        float generated = step(0.73,hash21(cell+floor(phase*0.35)));
        float outlet = 0.0;
        for (int i=0; i<4; i++) {
            float bearing = 0.785398+float(i)*1.570796;
            vec2 direction = vec2(cos(bearing),sin(bearing));
            float along = dot(centered,direction);
            float across = abs(dot(centered,vec2(-direction.y,direction.x)));
            float path = (1.0-smoothstep(0.007,0.02,across))
                       *smoothstep(0.13,0.18,along)*(1.0-smoothstep(0.39,0.44,along));
            float pulse = 1.0-smoothstep(0.08,0.35,fract(along*4.0-phase*0.35));
            outlet += path*pulse;
        }
        float ignition = (1.0-smoothstep(0.035,0.11,radius))
                       *pow(max(0.0,sin(phase*3.8)),8.0);
        float strength = load_fraction * (0.34*ring+0.13*cage+0.37*marker
                                          +0.46*particle*generated+0.55*outlet
                                          +0.70*ignition);
        vec4 material_light = texture(core_work_surface,UV);
        float shimmer = 0.82+0.18*sin(phase*1.8+UV.y*12.0);
        vec3 emissive = material_light.rgb*material_light.a*sqrt(load_fraction)*shimmer*1.32;
        COLOR = vec4(emissive+vec3(0.08,0.54,1.0)*strength,1.0);
    }
}
