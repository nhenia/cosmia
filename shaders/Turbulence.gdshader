shader_type canvas_item;

uniform int star_type : hint_range(0, 2) = 0; // 0: Star, 1: Nebula, 2: Eclipse
uniform vec4 star_color : source_color = vec4(1.0, 0.66, 0.0, 1.0);
uniform float brightness : hint_range(0.0, 3.0) = 1.0;
uniform float turbulence : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.5, 1.5) = 1.0;
uniform float halo : hint_range(0.0, 1.0) = 0.0;

// Simple hash function for noise
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// 2D Noise
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
    vec2 uv = UV - 0.5;

    // For Nebula, we distort UVs
    if (star_type == 1) {
        float d = noise(uv * 3.0 + TIME * 0.2);
        uv += uv * d * 0.3;
    }

    float dist = length(uv);
    vec3 color = star_color.rgb;
    float alpha = 0.0;

    if (star_type == 0) { // Star
        alpha = smoothstep(0.5, 0.48, dist);
        float n = noise(uv * (10.0 + turbulence * 20.0) + TIME * (0.5 + turbulence * 5.0));
        color = mix(star_color.rgb * 0.8, star_color.rgb * 1.5, n);

        // Inner glow
        float inner_glow = pow(1.0 - dist * 2.0, 2.0) * 0.5;
        color += star_color.rgb * inner_glow;
    }
    else if (star_type == 1) { // Nebula
        // Larger, softer
        alpha = smoothstep(0.5, 0.0, dist);
        float n1 = noise(uv * 5.0 + TIME * 0.1);
        float n2 = noise(uv * 10.0 - TIME * 0.2);
        float combined_noise = (n1 + n2) * 0.5;

        alpha *= combined_noise * 1.5;
        color = mix(star_color.rgb, vec3(1.0), combined_noise * 0.3);

        // Nebula pulse effect
        alpha *= pulse;
    }
    else if (star_type == 2) { // Eclipse
        float corona = smoothstep(0.5, 0.3, dist);
        float black_hole = smoothstep(0.38, 0.4, dist);

        alpha = corona;

        // Corona noise
        float n = noise(uv * 15.0 + TIME * 2.0);
        vec3 corona_color = star_color.rgb * (1.0 + n * 0.5);

        color = mix(corona_color, vec3(0.0), black_hole);

        // Outer ring highlight
        float ring = smoothstep(0.4, 0.41, dist) * smoothstep(0.43, 0.42, dist);
        color += star_color.rgb * ring * 3.0;
    }

    // Apply global brightness
    color *= brightness;

    // Glow effect (optimized for mobile by doing it in-shader)
    float glow = exp(-dist * 4.0) * 0.4 * brightness;
    if (star_type == 2) glow *= 1.5; // Stronger corona glow

    // Silver Halo
    float halo_ring = smoothstep(0.6, 0.58, dist) * smoothstep(0.55, 0.57, dist);
    vec3 halo_color = vec3(0.8, 0.9, 1.0); // Silver/Blueish

    vec3 final_color = color + (star_color.rgb * glow) + (halo_color * halo_ring * halo);
    float final_alpha = clamp(alpha + glow * 0.5 + halo_ring * halo, 0.0, 1.0);

    COLOR = vec4(final_color, final_alpha * star_color.a);
}
