shader_type canvas_item;
render_mode unshaded;
uniform sampler2D surface_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D cloud_map : filter_linear_mipmap, repeat_enable;
uniform vec2 phase = vec2(0.0);
uniform vec4 atmosphere_color : source_color = vec4(0.35, 0.78, 0.94, 1.0);
uniform float glow_strength = 0.30;
uniform float shadow_strength = 0.86;
uniform float cloud_opacity = 0.65;
uniform vec3 light_direction = vec3(0.65, -0.45, 0.62);
uniform float extent = 1.09;
uniform float visual_clock = 0.0;
uniform float completion_flash = 0.0;
uniform vec2 completion_spot = vec2(0.0);
uniform float emission = 0.0;
uniform float detail_scale = 1.0;
uniform float detail_strength = 1.0;
uniform float axis_ratio = 1.0;
uniform vec4 surface_tint : source_color = vec4(1.0);
uniform vec4 shadow_tint : source_color = vec4(0.47, 0.47, 0.47, 1.0);
uniform float corona_width = 0.02;
uniform float pulse_strength = 0.0;
uniform float pulse_speed = 0.08;
uniform float flare_strength = 0.0;
uniform float beam_length = 0.0;
uniform float beam_width = 0.13;
uniform float beam_speed = 1.6;
uniform float magnetosphere = 0.0;
// Crossfade a narrow overlap to close imperfect authored horizontal seams.
vec4 map_sample(sampler2D map, vec2 uv) {
    uv.x = fract(uv.x);
    vec4 a = texture(map, vec2(uv.x * 0.96, uv.y));
    vec4 b = texture(map, vec2(uv.x * 0.96 + 0.96, uv.y));
    return mix(b, a, smoothstep(0.0, 0.04, uv.x));
}
void fragment() {
    vec2 screen_p = (UV * 2.0 - 1.0) * extent;
    vec2 p = screen_p / vec2(1.0, max(0.5, axis_ratio));
    p /= 1.0 + min(pulse_strength, 0.05) * sin(visual_clock * TAU * pulse_speed);
    float r = length(p);
    vec3 light = normalize(light_direction);
    vec3 rgb;
    float alpha;
    if (r <= 1.0) {
        vec3 normal = vec3(p, sqrt(max(0.0, 1.0 - dot(p, p))));
        vec2 uv = vec2(atan(normal.x, normal.z) / TAU + 0.5, asin(clamp(normal.y, -1.0, 1.0)) / PI + 0.5);
        vec3 terrain = map_sample(surface_map, uv + vec2(phase.x, 0.0)).rgb;
        float clouds = map_sample(cloud_map, uv + vec2(phase.y, 0.0)).r;
        float cloud_shadow = map_sample(cloud_map, uv + vec2(phase.y + 0.002, 0.003)).r;
        terrain *= 1.0 - cloud_shadow * cloud_opacity * 0.18;
        float illumination = dot(normal, light);
        float day = smoothstep(-0.20, 0.80, illumination);
        // Broad, softly joined cel bands preserve spherical depth at window scale.
        float cel_day = 0.38 + smoothstep(-0.10, 0.10, illumination) * 0.30
            + smoothstep(0.48, 0.62, illumination) * 0.30;
        vec3 lit_terrain = mix(terrain, vec3(0.94, 0.93, 0.86), clouds * cloud_opacity);
        vec3 night_tint = vec3(0.22, 0.40, 0.52);
        rgb = lit_terrain * mix(vec3(1.0), mix(night_tint, vec3(cel_day), day), shadow_strength);
        rgb += vec3(0.93, 0.94, 0.81) * pow(max(0.0, illumination), 12.0) * 0.08;
        rgb += atmosphere_color.rgb * pow(1.0 - normal.z, 3.5) * glow_strength * (0.2 + 0.8 * day);
        if (emission > 0.0) {
            vec2 star_uv = uv * max(0.1, detail_scale);
            float cells = map_sample(surface_map, star_uv + vec2(phase.x, 0.0)).r;
            float detail = map_sample(surface_map, star_uv * 1.73 + vec2(phase.y, phase.x * 0.3)).r;
            float granules = clamp(mix(0.78, cells * 0.78 + detail * 0.22, detail_strength), 0.0, 1.0);
            granules = mix(granules, 0.32 + smoothstep(0.36, 0.53, granules) * 0.36
                + smoothstep(0.64, 0.78, granules) * 0.24, 0.65);
            rgb = mix(shadow_tint.rgb, surface_tint.rgb, granules) * emission;
            rgb *= 0.78 + 0.22 * pow(normal.z, 0.35);
            rgb += atmosphere_color.rgb * pow(1.0 - normal.z, 5.0) * glow_strength * 0.25;
        }
        // The contour belongs to the sphere: it does not spin with the map.
        float contour = smoothstep(0.965, 0.993, r) * (1.0 - min(1.0, emission));
        rgb = mix(rgb, vec3(0.12, 0.24, 0.31), contour * 0.75);
        // Completion lights only the body, leaving its corona and orbital space unchanged.
        float spot = 1.0 - smoothstep(0.0, 0.28, distance(p, completion_spot));
        rgb = mix(rgb, max(rgb, vec3(0.90, 0.97, 1.0)), completion_flash * spot);
        alpha = 1.0;
    } else {
        float width = clamp(corona_width, 0.005, 1.0);
        float halo = exp(-(r - 1.0) / width) * (1.0 - smoothstep(extent - 0.05, extent, r));
        float lit = 0.35 + 0.65 * max(0.0, dot(normalize(vec3(p, 0.2)), light));
        if (emission > 0.0) {
            float angle = atan(p.y, p.x);
            float rays = 0.82 + 0.12 * sin(angle * 19.0 + phase.y * TAU) + 0.06 * sin(angle * 41.0 - phase.x * TAU);
            float flare = pow(max(0.0, sin(visual_clock * 0.37)), 24.0) * pow(max(0.0, cos(angle - visual_clock * 0.04)), 48.0);
            halo *= rays + flare * flare_strength;
            lit = 1.0;
        }
        rgb = atmosphere_color.rgb;
        alpha = halo * glow_strength * lit;
    }
    if (beam_length > 0.0) {
        // A tilted bipolar axis makes a full revolution around vertical Y.
        // Slight camera elevation projects each tip's circular path as an ellipse.
        float sweep = visual_clock * TAU * beam_speed;
        float tilt = 0.48;
        float elevation = 0.22;
        vec3 jet = vec3(sin(tilt) * cos(sweep), -cos(tilt), sin(tilt) * sin(sweep));
        vec3 projected = vec3(jet.x, jet.y * cos(elevation) + jet.z * sin(elevation),
            -jet.y * sin(elevation) + jet.z * cos(elevation));
        float projected_length = length(projected.xy);
        vec2 axis = projected.xy / projected_length;
        float signed_along = dot(screen_p, axis) / projected_length;
        float along = abs(signed_along);
        float across = abs(dot(screen_p, vec2(axis.y, -axis.x)));
        float spread = max(0.03, beam_width) * (0.25 + along * 0.24);
        float cone = exp(-pow(across / spread, 2.0)) * smoothstep(0.98, 1.12, along)
            * (1.0 - smoothstep(1.1, beam_length, along));
        float depth = signed_along * projected.z;
        if (r <= 1.0) {
            // The near jet can cross the visible limb; the far jet stays behind it.
            cone *= step(sqrt(max(0.0, 1.0 - r * r)), depth);
        }
        float facing = 0.5 + 0.5 * sign(signed_along) * projected.z;
        float beam_alpha = cone * mix(0.40, 0.95, facing);
        float field = exp(-pow((length(screen_p / vec2(1.65, 2.7)) - 1.0) * 18.0, 2.0));
        if (r > 1.0) beam_alpha = max(beam_alpha, field * magnetosphere * 0.16);
        vec3 beam_color = mix(atmosphere_color.rgb, vec3(0.88, 0.97, 1.0), cone * 0.65);
        float combined_alpha = beam_alpha + alpha * (1.0 - beam_alpha);
        rgb = (beam_color * beam_alpha + rgb * alpha * (1.0 - beam_alpha)) / max(combined_alpha, 0.0001);
        alpha = combined_alpha;
    }
    COLOR = vec4(rgb, alpha);
}
