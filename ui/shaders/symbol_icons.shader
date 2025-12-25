shader_type canvas_item;

uniform int symbol_type : hint_range(0, 1) = 0; // 0: Diamond, 1: Coin
uniform vec4 color : hint_color = vec4(1.0);
uniform float glow : hint_range(0.0, 2.0) = 1.0;

float sdDiamond(vec2 p, float r) {
    p = abs(p);
    return (p.x + p.y) - r;
}

float sdCircle(vec2 p, float r) {
    return length(p) - r;
}

void fragment() {
    vec2 uv = UV - 0.5;
    float d = 0.0;
    
    if (symbol_type == 0) {
        d = sdDiamond(uv, 0.4);
    } else {
        d = sdCircle(uv, 0.45);
    }
    
    float mask = smoothstep(0.01, 0.0, d);
    float edge = smoothstep(0.1, 0.0, abs(d)); // Brillo en el borde
    
    vec3 final_color = color.rgb;
    
    // Gradiente interno simple
    final_color *= (1.0 - length(uv) * 0.5);
    
    // Añadir brillo
    final_color += color.rgb * edge * glow;
    
    // Reflexión superior
    float reflection = smoothstep(0.1, 0.0, length(uv - vec2(-0.15, -0.15))) * 0.4;
    final_color += vec3(1.0) * reflection;
    
    COLOR = vec4(final_color, mask * color.a);
}
