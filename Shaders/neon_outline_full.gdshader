// neon_outline_full.gdshader
shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform vec4 base_color : source_color = vec4(1.0);  // <-- НОВЫЙ ПАРАМЕТР
uniform float outline_width = 1.0;
uniform float pulse_speed = 2.0;
uniform float pulse_offset = 0.0;
uniform float inner_glow = 0.01;  // Как сильно внутренность тоже светится

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    
    // Применяем базовый цвет к текстуре (умножаем)
    vec4 tinted_color = color * base_color;  // <-- УМНОЖЕНИЕ НА base_color
    float alpha = color.a;
    
    // Полноценный outline с оптимизациями
    float outline = 0.0;
    float step_px = outline_width;
    vec2 tex_size = TEXTURE_PIXEL_SIZE;
    
    // Сканируем квадрат вокруг пикселя
    for (float x = -step_px; x <= step_px; x++) {
        for (float y = -step_px; y <= step_px; y++) {
            // Пропускаем центральный пиксель (оптимизация)
            if (abs(x) < 0.5 && abs(y) < 0.5) continue;
            
            vec2 offset = vec2(x, y) * tex_size;
            float sample_alpha = texture(TEXTURE, UV + offset).a;
            outline = max(outline, sample_alpha);
            
            // Ранний выход (оптимизация)
            if (outline > 0.5) break;
        }
        if (outline > 0.5) break;
    }
    
    // Пульсация (с индивидуальным смещением для каждого объекта)
    float pulse = sin((TIME + pulse_offset) * pulse_speed) * 0.2 + 0.8;
    
    // Три случая:
    if (alpha < 0.1 && outline > 0.5) {
        // 1. Пиксель пустой, но рядом есть объект - рисуем контур
        COLOR = vec4(glow_color.rgb * pulse, 1.0);
    } else if (alpha > 0.1) {
        // 2. Пиксель принадлежит объекту - используем tinted_color (уже с base_color)
        vec3 neon = mix(tinted_color.rgb, glow_color.rgb, inner_glow);
        COLOR = vec4(neon * pulse, alpha);
    } else {
        // 3. Пустота
        COLOR = vec4(0.0);
    }
}