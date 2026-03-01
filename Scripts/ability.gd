# ability.gd
extends Node
class_name Ability

# Вызывается сразу после создания и добавления в дерево
# direction - вектор направления взгляда/движения игрока в момент активации
func activate(player: Player, direction: Vector2) -> void:
	# Базовая реализация может быть пустой или выдавать ошибку
	push_error("Ability.activate() не реализован в дочернем классе")
	pass

# Вызывается из анимации игрока в момент, когда должен быть нанесен урон/применен эффект
func apply_damage(player: Player, direction: Vector2) -> void:
	push_error("Ability.apply_damage() не реализован в дочернем классе")
	pass

# Возвращает имя анимации, которую должен проиграть игрок
# direction_string - строковое представление направления ("up", "down", "left", "right")
func get_animation_name(direction_string: String) -> String:
	push_error("Ability.get_animation_name() не реализован в дочернем классе")
	return ""

# Вызывается после окончания анимации (опционально, для очистки)
func cleanup() -> void:
	# Базовая реализация может быть пустой
	pass
