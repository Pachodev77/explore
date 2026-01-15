shader_type canvas_item;

uniform float radius = 20.0;
varying vec2 local_pos;

void vertex() {
    local_pos = VERTEX;
}

void fragment() {
    vec2 center = vec2(radius, radius);
    float dist = length(local_pos - center);
    
    if (dist > radius) {
        discard;
    }
    
    // Suavizado del borde (Antialiasing)
    float edge = smoothstep(radius, radius - 1.0, dist);
    vec4 tex = texture(TEXTURE, UV);
    COLOR = vec4(tex.rgb, tex.a * edge);
}
