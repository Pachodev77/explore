shader_type canvas_item;

uniform float rotation : hint_range(0.0, 6.28318) = 0.0;
uniform vec4 color_n : hint_color = vec4(1.0, 0.2, 0.2, 1.0);
uniform vec4 color_light : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 color_dark : hint_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 color_glow : hint_color = vec4(1.0, 0.9, 0.5, 0.4);

mat2 rot2d(float a) {
    float c = cos(a);
    float s = sin(a);
    return mat2(vec2(c, -s), vec2(s, c));
}

float sdStar(vec2 p, float r, float n, float m) {
    // n: number of points, m: pointyness
    float an = 3.14159 / n;
    float en = 3.14159 / m;
    vec2 acs = vec2(cos(an), sin(an));
    vec2 ecs = vec2(cos(en), sin(en));

    float bn = mod(atan(p.x, p.y), 2.0 * an) - an;
    p = length(p) * vec2(cos(bn), abs(sin(bn)));
    p -= r * acs;
    p += ecs * clamp(-dot(p, ecs), 0.0, r * acs.y / ecs.y);
    return length(p) * sign(p.x);
}

void fragment() {
    vec2 uv = UV - 0.5;
    vec2 p_rot = rot2d(rotation) * uv;
    
    // 1. Base shape SDF
    float d = sdStar(p_rot, 0.4, 4.0, 3.0);
    float star_mask = smoothstep(0.01, 0.0, d);
    
    // 2. Nautical shading logic (GLES2 Compatible)
    // Rotating p_rot by 45 degrees to align sectors for sin logic if needed, 
    // or just calculate angle and use sin.
    float angle = atan(p_rot.x, -p_rot.y); // North point is at 0
    
    // sin(angle * 4.0) will switch signs every 45 degrees.
    // At angle 0 (start of North point), sin is 0. 
    // We want the split to happen exactly down the middle of the point (at 0).
    bool is_right_side = sin(angle * 4.0) > 0.0;
    
    // North point detection (within +/- 45 degrees of 0)
    bool is_north_point = abs(angle) < 0.785; // pi / 4
    
    vec3 col;
    if (is_north_point) {
        col = is_right_side ? color_n.rgb : color_n.rgb * 0.6;
    } else {
        col = is_right_side ? color_light.rgb : color_dark.rgb;
    }
    
    // 3. Ring
    float ring_d = abs(length(uv) - 0.4) - 0.005;
    float ring = smoothstep(0.01, 0.0, ring_d);
    
    // 4. Detail shapes (inner star)
    float d2 = sdStar(p_rot, 0.15, 4.0, 2.0);
    float star2 = smoothstep(0.01, 0.0, d2);
    
    // 5. Center glow
    float glow = smoothstep(0.3, 0.0, length(uv)) * 0.5;
    
    // Final composition
    vec4 final_color = vec4(col, star_mask);
    
    // Contrast for inner star
    final_color.rgb = mix(final_color.rgb, vec3(0.5), star2 * 0.3);
    
    // Add ring with transparency blend
    final_color.rgb = mix(final_color.rgb, color_light.rgb, ring * 0.7);
    final_color.a = max(final_color.a, ring * 0.7);
    
    // Add glow
    final_color.rgb += color_glow.rgb * glow;
    
    COLOR = final_color;
}
