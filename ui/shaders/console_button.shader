shader_type canvas_item;

uniform vec4 color_top : hint_color = vec4(0.2, 0.25, 0.33, 1.0);
uniform vec4 color_bottom : hint_color = vec4(0.12, 0.16, 0.23, 1.0);
uniform float corner_radius : hint_range(0.0, 0.5) = 0.5;
uniform float glow : hint_range(0.0, 2.0) = 0.0;

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    vec2 dist = abs(UV - center) - (vec2(0.5) - corner_radius);
    float d = length(max(dist, 0.0)) - corner_radius;
    
    // Gradiente angular (aproximado 145deg)
    float angle_t = (UV.x + UV.y) * 0.5;
    vec4 final_color = mix(color_top, color_bottom, angle_t);
    
    // Aplicar Glow
    final_color.rgb += final_color.rgb * glow;
    
    // Brillo interno superior
    float highlight = smoothstep(0.48, 0.45, length(UV - vec2(0.5, 0.4)));
    final_color = mix(final_color, vec4(1.0, 1.0, 1.0, 0.1), highlight);
    
    if (d > 0.0) {
        discard;
    }
    
    COLOR = final_color;
}
