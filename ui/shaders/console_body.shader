shader_type canvas_item;

uniform vec4 top_color : hint_color = vec4(0.12, 0.16, 0.23, 0.95);
uniform vec4 bottom_color : hint_color = vec4(0.06, 0.09, 0.16, 1.0);
uniform float border_width : hint_range(0.0, 5.0) = 1.0;
uniform vec4 border_color : hint_color = vec4(1.0, 1.0, 1.0, 0.15);
uniform float blur_amount : hint_range(0.0, 5.0) = 4.0;

void fragment() {
    float gradient_t = UV.y;
    vec4 final_color = mix(top_color, bottom_color, gradient_t);
    
    // Simulación de borde superior brillante
    float border = 0.0;
    if (UV.y < border_width / 100.0) {
        border = 1.0;
    }
    
    final_color = mix(final_color, border_color, border * border_color.a);
    
    COLOR = final_color;
}
