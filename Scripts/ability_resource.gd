# ability_resource.gd
extends Resource
class_name AbilityResource

# Идентификация
@export var id: String = ""                    # Уникальный идентификатор
@export var display_name: String = ""           # Для UI
@export var description: String = ""            # Для UI
@export var icon: Texture2D                     # Базовая иконка (для всех способностей кроме меча)

# Для меча - добавим массив иконок под разные уровни
@export var level_icons: Array[Texture2D] = []  # Иконки для разных уровней (low, medium, high)

# Типология
@export var ability_type: int = 0               # 0=ATTACK, 1=DEFENSE, 2=MOBILITY
@export var activation_type: int = 0            # 0=ACTIVE, 1=PASSIVE, 2=ULTIMATE

# Реализация
@export var ability_scene: PackedScene          # Сцена с логикой!
@export var ui_scene: PackedScene               # Для отображения в слотах

# Визуальные параметры
@export var neon_color: Color = Color.WHITE     # Цвет свечения

# Базовые параметры
@export var base_damage: int = 10
@export var base_cooldown: float = 1.0

# Метод для получения иконки по уровню
func get_icon_for_level(level: int) -> Texture2D:
	if level_icons.size() == 0:
		return icon  # возвращаем базовую иконку если нет массива
	
	if level < 20 and level_icons.size() > 0:
		return level_icons[0]  # low
	elif level < 30 and level_icons.size() > 1:
		return level_icons[1]  # medium
	elif level_icons.size() > 2:
		return level_icons[2]  # high
	else:
		return level_icons[-1]  # последняя если что
