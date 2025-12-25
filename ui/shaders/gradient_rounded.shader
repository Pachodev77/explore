shader_type canvas_item;

uniform vec4 color1 : hint_color = vec4(0.86, 0.15, 0.15, 0.9);
uniform vec4 color2 : hint_color = vec4(0.72, 0.11, 0.11, 0.95);
uniform float borderRadius : hint_range(0.0, 0.5) = 0.5;
uniform float brightness : hint_range(0.5, 2.0) = 1.0;

float roundedBoxSDF(vec2 centerPos, vec2 size, float radius) {
    return length(max(abs(centerPos) - size + radius, 0.0)) - radius;
}

void fragment() {
    vec2 uv = UV - 0.5;
    float distance = roundedBoxSDF(uv, vec2(0.5), borderRadius);
    float alpha = 1.0 - smoothstep(0.0, 0.01, distance);
    
    vec4 gradient = mix(color1, color2, UV.y + UV.x);
    COLOR = vec4(gradient.rgb * brightness, gradient.a * alpha);
}
