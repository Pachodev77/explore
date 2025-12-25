shader_type canvas_item;

uniform float value : hint_range(0.0, 1.0) = 0.75;
uniform vec4 bar_color : hint_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 bg_color : hint_color = vec4(0.0, 0.0, 0.0, 0.5);
uniform vec4 glow_color : hint_color = vec4(1.0, 0.3, 0.3, 0.6);

void fragment() {
    float mask = step(UV.x, value);
    vec4 final_color = mix(bg_color, bar_color, mask);
    
    // Efecto de glow en la barra rellena
    if (mask > 0.5) {
        float glow = (1.0 - UV.y) * 0.5;
        final_color = mix(final_color, glow_color, glow);
    }
    
    COLOR = final_color;
}
