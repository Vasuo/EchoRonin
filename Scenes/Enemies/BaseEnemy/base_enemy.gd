# base_enemy.gd
extends CharacterBody2D
class_name BaseEnemy

# Сигналы
signal died(ability_resource: Resource)
signal health_changed(current: int, max: int)

# Экспортируемые параметры (только самое базовое)
@export var ability_drop: AbilityResource
@export var max_health: int = 30
@export var heal_on_kill: int = 5  # Сколько здоровья даёт при убийстве

# Ссылки (опционально, могут быть не у всех врагов)
var player: Node2D = null
var health: int

func _ready():
	health = max_health
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("players")

# Добавь в BaseEnemy.gd
func scale_difficulty(wave: int):
	"""Увеличивает характеристики врага в зависимости от волны"""
	var scale_factor = 1.0 + (wave - 1) * 0.2  # +20% за волну
	
	# Увеличиваем здоровье
	max_health = int(max_health * scale_factor)
	health = max_health
	
	# Можно добавить другие улучшения:
	# speed = speed * (1.0 + (wave - 1) * 0.1)
	# damage = int(damage * scale_factor)
	

func take_damage(amount: int, source: Node2D = null):
	health -= amount
	emit_signal("health_changed", health, max_health)
	
	# ЗВУК: враг получил урон
	if AudioManager and AudioManager.sound_effects.has("enemy_hit"):
		AudioManager.play_sound("enemy_hit", global_position)
	
	if health <= 0:
		die()

# base_enemy.gd - функция die()
# base_enemy.gd - функция die()
func die():
	# В base_enemy.gd, функция die()
	if VFXManager:
		VFXManager.create_death_sparks(global_position, Color(1.0, 0.5, 0.0))
	# Вспышка при смерти
	if VFXManager:
		# Вместо обычной вспышки - быстрый взрыв
		VFXManager.create_rapid_explosion(
			global_position,
			Color(1.0, 0.5, 0.0),  # Оранжевый
			25.0,                    # Мощность
			0.2,                     # Длительность каждой вспышки
			3,                       # Количество вспышек
			0.15                     # Пауза между вспышками
		)
	
	if heal_on_kill > 0:
		var player = get_tree().get_first_node_in_group("players")
		if player and player.has_method("heal"):
			player.heal(heal_on_kill)
	
	# ЗВУК: смерть врага
	if AudioManager:
		if AudioManager.sound_effects.has("enemy_death_1"):
			var variation = randi() % 3 + 1
			AudioManager.play_sound("enemy_death_" + str(variation), global_position)
	
	emit_signal("died", ability_drop)
	queue_free()
