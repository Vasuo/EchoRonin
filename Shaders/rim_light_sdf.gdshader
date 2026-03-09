shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Новые uniform'ы для преобразования координат
uniform vec4 camera_rect;  // x, y = top_left, z, w = size
uniform vec2 player_uv;    // позиция игрока в UV (0-1)

uniform bool enable_shadows = true;
uniform float shadow_distance = 150.0;
uniform int shadow_steps = 16;
uniform float shadow_bias = 5.0;

// Новые параметры для затухания
uniform float max_glow_distance = 300.0;  // Максимальная дистанция свечения
uniform float falloff_power = 2.0;        // Степень затухания (2.0 = квадратичное)

varying vec2 vertex_world;  // ← переименовали, чтобы избежать конфликта

void vertex() {
    // Получаем мировые координаты вершины
    vertex_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float get_shadow(vec2 world_pos, vec2 light_world, vec2 screen_pixel_size) {
    vec2 ray_dir = normalize(world_pos - light_world);
    float dist_to_pixel = distance(world_pos, light_world);
    
    float current_dist = shadow_bias * 2.0;
    
    for (int i = 0; i < shadow_steps; i++) {
        float step_size = 10.0 + (current_dist / dist_to_pixel) * 20.0;
        
        vec2 sample_world = light_world + ray_dir * current_dist;
        vec2 sample_uv = (sample_world - camera_rect.xy) / camera_rect.zw;
        vec2 sdf_sample_pos = screen_uv_to_sdf(sample_uv);
        float sample_dist = texture_sdf(sdf_sample_pos);
        
        if (current_dist < dist_to_pixel && sample_dist < 2.0) {
            float shadow_strength = 1.0 - (current_dist / dist_to_pixel);
            return shadow_strength;
        }
        
        current_dist += step_size;
        if (current_dist > dist_to_pixel) break;
    }
    return 0.0;
}

void fragment() {
    vec4 scene_color = texture(SCREEN_TEXTURE, SCREEN_UV);
    
    // SDF данные
    vec2 sdf_pos = screen_uv_to_sdf(SCREEN_UV);
    float dist = texture_sdf(sdf_pos);
    vec2 gradient = texture_sdf_normal(sdf_pos);
    
    // Конвертируем UV в мировые координаты (используем camera_rect)
    vec2 world_pos = camera_rect.xy + SCREEN_UV * camera_rect.zw;
    
    // Расстояние до игрока в UV-координатах
    float dist_to_player_uv = distance(SCREEN_UV, player_uv);
    float dist_to_player = dist_to_player_uv * length(camera_rect.zw);  // Примерный перевод в пиксели
    
    // Направление к игроку (в мировых координатах)
    vec2 player_world = camera_rect.xy + player_uv * camera_rect.zw;
    vec2 to_player = normalize(player_world - world_pos);
    
    // Стабилизация градиента
    float gradient_strength = length(gradient);
    float side = 0.0;
    
    if (gradient_strength > 0.1) {
        side = dot(gradient, to_player);
        side = clamp(side, 0.0, 1.0);
    }
    
    float glow = 0.0;
    float rim_width = 4.0;
    float angle_threshold = 0.2;
    
    // НОВАЯ ЛОГИКА ЗАТУХАНИЯ
    if (dist_to_player < max_glow_distance && abs(dist) < rim_width) {
        
        // Коэффициент затухания по расстоянию (1.0 у игрока, 0.0 на max_glow_distance)
        float distance_falloff = 1.0 - (dist_to_player / max_glow_distance);
        distance_falloff = pow(distance_falloff, falloff_power);  // Применяем степень для плавности
        
        // Коэффициент затухания по углу
        float side_weight = smoothstep(0.1, 0.5, side);
        
        // Тени
        float shadow = get_shadow(world_pos, player_world, SCREEN_PIXEL_SIZE);
        
        if (shadow < 0.5) {
            // Затухание по расстоянию от границы объекта
            float edge_weight = 1.0 - (abs(dist) / rim_width);
            
            // Финальный glow с учетом всех затуханий
            glow = edge_weight * side_weight * (1.0 - shadow) * distance_falloff;
            
            // Дополнительное затухание к краям экрана (опционально)
            float screen_edge_falloff = 1.0;
            vec2 screen_center = vec2(0.5, 0.5);
            float dist_from_center_uv = distance(SCREEN_UV, screen_center);
            
            // Затухание в последних 20% экрана
            if (dist_from_center_uv > 0.4) {
                screen_edge_falloff = 1.0 - ((dist_from_center_uv - 0.4) / 0.6);
                screen_edge_falloff = clamp(screen_edge_falloff, 0.0, 1.0);
                screen_edge_falloff = pow(screen_edge_falloff, 1.5);
            }
            
            glow *= screen_edge_falloff;
        }
    }
    
    // Цвет контура
    vec4 rim_color = vec4(0.0, 1.0, 1.0, 1.0);
    COLOR = mix(scene_color, rim_color, glow);
}