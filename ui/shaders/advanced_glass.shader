shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 5.0) = 4.0;
uniform vec4 bg_color : hint_color = vec4(0.06, 0.1, 0.13, 0.6); // #101922 darkened
uniform vec4 border_color : hint_color = vec4(1.0, 1.0, 1.0, 0.1);
uniform float corner_radius : hint_range(0.0, 1.0) = 0.5;
uniform float border_width : hint_range(0.0, 10.0) = 1.0;

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    vec2 dist = abs(UV - center) * 2.0;
    float d = length(max(dist - (1.0 - corner_radius), 0.0)) - corner_radius;
    
    if (d > 0.0) {
        discard;
    }

    vec4 background = textureLod(SCREEN_TEXTURE, SCREEN_UV, blur_amount);
    vec4 final_color = mix(background, bg_color, bg_color.a);
    
    // Borde sutil
    if (d > -border_width / 100.0) {
        final_color = mix(final_color, border_color, border_color.a);
    }
    
    COLOR = final_color;
}
