shader_type canvas_item;

// Radios independientes
uniform float radius_top = 0.4; // Mucho más redondeado arriba
uniform float radius_bottom = 0.15; // Estándar abajo
uniform float aspect = 2.72; // Relación de aspecto (600/220)

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    
    // UV centrado: Y va de -0.5 (Arriba) a 0.5 (Abajo)
    vec2 uv = (UV - 0.5) * vec2(aspect, 1.0);
    vec2 half_size = vec2(aspect * 0.5, 0.5);
    
    // Seleccionar radio: Si estamos en la mitad superior (uv.y < 0), usar radio grande
    float r = (uv.y < 0.0) ? radius_top : radius_bottom;
    
    // SDF (Signed Distance Field) adaptable
    vec2 d = abs(uv) - (half_size - r);
    float dist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
    
    // Suavizado de bordes (Antialiasing)
    float mask = 1.0 - smoothstep(-0.01, 0.01, dist);
    
    color.a *= mask;
    COLOR = color;
}
