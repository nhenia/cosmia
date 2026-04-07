shader_type canvas_item;

uniform float turbulence : hint_range(0.0, 1.0) = 0.0;
uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

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
    float dist = length(uv);

    // Circle mask
    float alpha = smoothstep(0.5, 0.48, dist);

    // Turbulence effect
    float n = noise(uv * (5.0 + turbulence * 20.0) + TIME * (0.5 + turbulence * 5.0));
    n += 0.5 * noise(uv * 10.0 - TIME);

    vec3 color = base_color.rgb;
    // Add boiling effect based on turbulence
    color += mix(vec3(0.0), vec3(0.5, 0.7, 1.0), n * turbulence);

    COLOR = vec4(color, alpha * base_color.a);
}
