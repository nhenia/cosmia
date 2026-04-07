shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 5.0) = 2.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec4 color = textureLod(screen_texture, SCREEN_UV, blur_amount);

    // Add a slight "Ozone" tint
    color.rgb *= vec3(0.9, 0.95, 1.0);

    // Frosted glass effect highlights
    float noise = fract(sin(dot(UV, vec2(12.9898, 78.233))) * 43758.5453);
    color.rgb += noise * 0.02;

    COLOR = color;
}
