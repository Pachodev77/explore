shader_type spatial;

uniform sampler2D grass_tex;
uniform sampler2D sand_tex;
uniform sampler2D snow_tex;
uniform sampler2D jungle_tex;

uniform float tiling = 0.5; // Ajustado para mejor detalle

void fragment() {
    // Calculamos UVs escalados
    vec2 scaled_uv = UV * tiling * 150.0;
    
    vec3 color_grass = texture(grass_tex, scaled_uv).rgb;
    vec3 color_sand = texture(sand_tex, scaled_uv).rgb;
    vec3 color_snow = texture(snow_tex, scaled_uv).rgb;
    vec3 color_jungle = texture(jungle_tex, scaled_uv).rgb;
    
    // Pesos de mezcla desde Vertex Color
    float w_grass = COLOR.r;
    float w_sand = COLOR.g;
    float w_snow = COLOR.b;
    // La selva es donde no hay ninguno de los otros pesos predominantemente
    float w_jungle = clamp(1.0 - (w_grass + w_sand + w_snow), 0.0, 1.0);
    
    // Normalizar pesos para evitar sobre-exposición o zonas oscuras
    float total_w = w_grass + w_sand + w_snow + w_jungle;
    if (total_w > 0.0) {
        w_grass /= total_w;
        w_sand /= total_w;
        w_snow /= total_w;
        w_jungle /= total_w;
    }
    
    vec3 final_color = (color_grass * w_grass) + 
                       (color_sand * w_sand) + 
                       (color_snow * w_snow) + 
                       (color_jungle * w_jungle);
                       
    ALBEDO = final_color;
    ROUGHNESS = 0.8;
    SPECULAR = 0.1;
}
