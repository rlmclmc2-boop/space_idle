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
// Both authored maps already meet at their horizontal edges. Let the sampler's
// repeat mode interpolate those edge texels instead of remapping to an inland
// column, which brings unrelated bright islands onto the longitude seam.
vec4 map_sample(sampler2D map, vec2 uv) {
    return texture(map, uv);
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
        // Smooth spherical lighting preserves the new albedo's fine faceted relief.
        float diffuse = 0.28 + 0.72 * smoothstep(-0.18, 0.85, illumination);
        vec3 lit_terrain = terrain;
        vec3 night_tint = vec3(0.20, 0.38, 0.52);
        rgb = lit_terrain * mix(vec3(1.0), mix(night_tint * 0.52, vec3(diffuse), day), shadow_strength);
        float cloud_density = pow(smoothstep(0.24, 0.84, clouds), 1.35) * cloud_opacity;
        float cloud_relief = clamp(0.94 + (clouds - cloud_shadow) * 0.8, 0.84, 1.04);
        vec3 cloud_lit = vec3(0.95, 0.97, 0.94) * cloud_relief * (0.15 + 0.85 * day);
        rgb = mix(rgb, cloud_lit, cloud_density);
        float fresnel = pow(1.0 - normal.z, 3.0);
        rgb += atmosphere_color.rgb * fresnel * glow_strength * (0.3 + 0.7 * day);
        rgb += vec3(0.94, 0.98, 0.91) * pow(max(0.0, illumination), 16.0) * 0.055;
        if (emission > 0.0) {
            // Both detail layers belong to the same turning surface. Integer longitude
            // repeats keep a full rotation seamless even with fractional detail scale.
            vec2 star_uv = vec2((uv.x + phase.x) * max(1.0, round(detail_scale)), uv.y * max(0.1, detail_scale));
            float cells = map_sample(surface_map, star_uv).r;
            float detail = map_sample(surface_map, vec2(star_uv.x + 0.37, star_uv.y * 1.73)).r;
            float granules = clamp(mix(0.78, cells * 0.78 + detail * 0.22, detail_strength), 0.0, 1.0);
            granules = mix(granules, 0.32 + smoothstep(0.36, 0.53, granules) * 0.36
                + smoothstep(0.64, 0.78, granules) * 0.24, 0.65);
            // Broad, slowly advected plasma lanes keep a stellar photosphere
            // from reading as a smoothly painted solid globe.
            float lane = sin(star_uv.y * 15.0 + sin(star_uv.x * TAU * 5.0 + visual_clock * 0.04) * 1.7
                + visual_clock * 0.035);
            float eddy = sin(star_uv.x * TAU * 13.0 - star_uv.y * 22.0 + visual_clock * 0.065);
            granules = clamp(granules + lane * 0.13 + eddy * 0.045, 0.0, 1.0);
            // Compress authored brightness before output so compact stars keep
            // their blue limb and spherical depth instead of clipping to white.
            float exposure = emission / (1.0 + max(0.0, emission - 1.0) * 0.85);
            rgb = mix(shadow_tint.rgb, surface_tint.rgb, granules) * exposure;
            rgb *= 0.58 + 0.42 * pow(normal.z, 0.8);
            rgb += surface_tint.rgb * smoothstep(0.66, 0.9, granules) * 0.16;
            rgb += atmosphere_color.rgb * pow(1.0 - normal.z, 5.0) * glow_strength * 0.25;
        }
        // Atmosphere replaces the former black cartoon contour.
        rgb = mix(rgb, atmosphere_color.rgb * 1.12, smoothstep(0.982, 1.0, r) * 0.42 * (1.0 - min(1.0, emission)));
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
            float rays = 0.88 + 0.13 * sin(angle * 12.0 + phase.y * TAU) + 0.07 * sin(angle * 23.0 - phase.x * TAU);
            float flare = pow(max(0.0, sin(visual_clock * 0.37)), 24.0) * pow(max(0.0, cos(angle - visual_clock * 0.04)), 48.0);
            halo *= rays + flare * flare_strength;
            lit = 1.0;
        }
        rgb = atmosphere_color.rgb;
        alpha = halo * glow_strength * lit;
        if (emission > 0.0) {
            float outer = exp(-pow((r - 1.0) / max(0.12, width * 3.5), 1.4));
            alpha = max(alpha, outer * glow_strength * 0.10);
        }
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
