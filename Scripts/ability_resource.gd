# ability_resource.gd
extends Resource
class_name AbilityResource

# Идентификация
@export var id: String = ""                    # Уникальный идентификатор
@export var display_name: String = ""           # Для UI
@export var description: String = ""            # Для UI
@export var icon: Texture2D                     # Для UI

# Типология (используем числа, потому что enum из другого файла не виден в Resource)
@export var ability_type: int = 0               # 0=ATTACK, 1=DEFENSE, 2=MOBILITY
@export var activation_type: int = 0            # 0=ACTIVE, 1=PASSIVE, 2=ULTIMATE

# Реализация
@export var ability_scene: PackedScene          # Сцена с логикой!
@export var ui_scene: PackedScene               # Для отображения в слотах

# Визуальные параметры
@export var neon_color: Color = Color.WHITE     # Цвет свечения

# Базовые параметры (заглушки)
@export var base_damage: int = 10
@export var base_cooldown: float = 1.0
