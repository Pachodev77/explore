shader_type canvas_item;

uniform float value : hint_range(0.0, 1.0) = 0.75;
uniform vec4 color_start : hint_color = vec4(0.86, 0.15, 0.15, 1.0);
uniform vec4 color_end : hint_color = vec4(0.97, 0.44, 0.44, 1.0);
uniform vec4 bg_color : hint_color = vec4(0.05, 0.05, 0.05, 0.4);
uniform float aspect_ratio = 4.0;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.0;

// Función de distancia para un segmento redondeado (cápsula)
float sdCapsule(vec2 p, vec2 a, vec2 b, float r) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

void fragment() {
    vec2 uv = UV;
    
    // Coordenadas normalizadas para el SDF usando el aspect_ratio real
    vec2 p = uv * vec2(aspect_ratio, 1.0);
    float radius = 0.45; // Radio de la cápsula (casi el alto total)
    float d = sdCapsule(p, vec2(radius, 0.5), vec2(aspect_ratio - radius, 0.5), radius);
    
    if (d > 0.0) {
        discard;
    }

    float pulse = (sin(TIME * pulse_speed) * 0.5 + 0.5) * 0.1;
    float mask = step(uv.x, value);
    
    // Color base
    vec3 base_color = mix(color_start.rgb, color_end.rgb, uv.x / max(value, 0.01));
    base_color += pulse * mask;
    
    // Brillo líquido / Glossy highlight superior
    float gloss = smoothstep(0.1, 0.0, abs(uv.y - 0.25)) * 0.3;
    gloss += smoothstep(0.4, 0.0, d + radius) * 0.1;
    
    // Mezcla final
    vec3 final_rgb = mix(bg_color.rgb, base_color, mask);
    final_rgb += vec3(1.0) * gloss;
    
    // Scanlines sutiles
    final_rgb += sin(uv.x * 80.0 - TIME * 5.0) * 0.02 * mask;
    
    // Glow en la punta del llenado
    float edge_glow = smoothstep(0.03, 0.0, abs(uv.x - value)) * mask;
    final_rgb += vec3(1.0) * edge_glow * 0.4;
    
    // Borde oscuro sutil para profundidad
    float border = smoothstep(-0.02, 0.0, d);
    final_rgb = mix(final_rgb, vec3(0.0), border * 0.5);

    COLOR = vec4(final_rgb, bg_color.a + mask * 0.6);
}
