# wave_manager.gd
extends Node
class_name WaveManager

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal enemy_spawned(enemy: Node2D)

# Экспортируемые параметры
@export var spawn_points: Array[Marker2D] = []
@export var enemy_types: Array[PackedScene] = []

# Базовые настройки волн
@export var base_enemies_per_wave: int = 3      # Сколько врагов в первой волне
@export var enemies_increment: int = 2          # На сколько увеличивается каждую волну
@export var base_wave_duration: float = 20.0    # Длительность первой волны
@export var duration_decrease: float = 1.0      # На сколько уменьшается длительность (минимум 10 сек)
@export var max_enemies_per_wave: int = 20      # Максимум врагов за волну
@export var spawn_interval: float = 1.5         # Интервал между спавном врагов

# Текущее состояние
var current_wave: int = 0
var enemies_alive: int = 0
var is_wave_active: bool = false
var enemies_to_spawn: int = 0  # Сколько врагов нужно заспавнить в этой волне
var spawn_timer: Timer
var wave_timer: Timer

func _ready():
	spawn_timer = Timer.new()
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_spawn_enemy)
	add_child(spawn_timer)
	
	wave_timer = Timer.new()
	wave_timer.one_shot = true
	wave_timer.timeout.connect(_complete_wave)
	add_child(wave_timer)
	
	call_deferred("_refresh_spawn_points")
	call_deferred("start_wave", 1)

func start_wave(wave_number: int = -1):
	if wave_number > 0:
		current_wave = wave_number
	else:
		current_wave += 1
	
	# Рассчитываем параметры для этой волны
	enemies_to_spawn = _calculate_enemies_for_wave(current_wave)
	var wave_time = _calculate_wave_duration(current_wave)
	

	enemies_alive = 0
	is_wave_active = true
	
	# Настраиваем таймеры
	spawn_timer.wait_time = spawn_interval
	spawn_timer.start()
	
	wave_timer.wait_time = wave_time
	wave_timer.start()
	
	emit_signal("wave_started", current_wave)

func _calculate_enemies_for_wave(wave: int) -> int:
	"""Рассчитывает количество врагов для волны"""
	var enemies = base_enemies_per_wave + (wave - 1) * enemies_increment
	return min(enemies, max_enemies_per_wave)  # Не больше максимума

func _calculate_wave_duration(wave: int) -> float:
	"""Рассчитывает длительность волны"""
	var duration = base_wave_duration - (wave - 1) * duration_decrease
	return max(duration, 10.0)  # Не меньше 10 секунд

func _spawn_enemy():
	if not is_wave_active: 
		return
	
	if enemies_alive >= enemies_to_spawn:
		# Все враги заспавнены, останавливаем таймер
		spawn_timer.stop()
		return
	
	if enemy_types.is_empty() or spawn_points.is_empty():
		return
	
	# Выбираем случайного врага
	var enemy_scene = enemy_types[randi() % enemy_types.size()]
	var enemy = enemy_scene.instantiate()
	
	# Выбираем случайную точку спавна
	var spawn_point = spawn_points[randi() % spawn_points.size()]
	
	# Добавляем случайное смещение
	var offset = Vector2(
		randf_range(-50, 50),
		randf_range(-50, 50)
	)
	enemy.global_position = spawn_point.global_position + offset
	
	# Добавляем на сцену
	get_parent().add_child(enemy)
	
	# 👇 НОВЫЙ КОД: вспышка при спавне
	if VFXManager:
		# Слабая, быстрая вспышка
		VFXManager.create_flash(
			enemy.global_position,
			Color(1.0, 1.0, 1.0),  # Фиолетовый
			20.0,                    # Не очень ярко
			0.5                     # Короткая
		)
	# 👆 КОНЕЦ НОВОГО КОДАм
	
	# Подключаем сигнал смерти
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)
	
	# Немного увеличиваем здоровье врагов с каждой волной
	if enemy.has_method("scale_difficulty"):
		enemy.scale_difficulty(current_wave)
	
	enemies_alive += 1
	emit_signal("enemy_spawned", enemy)
	
	# Звук спавна
	if AudioManager and AudioManager.sound_effects.has("enemy_spawn"):
		call_deferred("_play_spawn_sound", enemy)

func _play_spawn_sound(enemy: Node2D):
	if AudioManager and is_instance_valid(enemy):
		AudioManager.play_sound_at_node("enemy_spawn", enemy)

func _on_enemy_died(ability_resource: AbilityResource):

	
	enemies_alive -= 1
	
	# Получаем игрока
	var player = get_tree().get_first_node_in_group("players")
	if not player or not player.ability_manager:
		return
	
	# Проверяем ресурс
	if ability_resource == null:
		return
	
	var ability_to_give = ability_resource
	
	# Для меча создаём уникальную версию с уровнем
	if ability_resource.id == "sword":
		
		# Создаём копию ресурса
		var new_resource = ability_resource.duplicate()
		
		# Базовый урон всегда от 10 до 20
		var base_damage = randi() % 11 + 10  # 10-20
		
		# Бонус за волну: +0 на 1-й волне, +5 на 2-й, +10 на 3-й и т.д.
		var wave_bonus = (current_wave - 1) * 5
		
		# Итоговый урон
		var total_damage = base_damage + wave_bonus
		
		new_resource.base_damage = total_damage
		new_resource.display_name = "меч lvl" + str(total_damage)
		
		# ВЫБИРАЕМ ИКОНКУ ПО УРОВНЮ
		if total_damage < 20:
			new_resource.icon = load("res://Art/Icons/sword_low.png")
		elif total_damage < 30:
			new_resource.icon = load("res://Art/Icons/sword_medium.png")
		else:
			new_resource.icon = load("res://Art/Icons/sword_high.png")
		
		ability_to_give = new_resource
	
	# Передаём способность игроку
	player.ability_manager.add_ability(ability_to_give)
	
	if enemies_alive == 0:
		_complete_wave()

func _complete_wave():
	is_wave_active = false
	spawn_timer.stop()
	wave_timer.stop()
	
	emit_signal("wave_completed", current_wave)
	
	# Звук завершения волны
	if AudioManager and AudioManager.sound_effects.has("ui_wave_complete"):
		AudioManager.play_sound("ui_wave_complete")
	
	# Пауза перед следующей волной
	await get_tree().create_timer(3.0).timeout
	start_wave()

func _refresh_spawn_points():
	if spawn_points.is_empty():
		var points = get_tree().get_nodes_in_group("spawn_points")
		for point in points:
			if point is Marker2D:
				spawn_points.append(point)
