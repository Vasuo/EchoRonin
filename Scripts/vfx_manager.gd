# flash_manager.gd
extends Node

# Сигналы
signal flash_created(position: Vector2, color: Color)
signal flash_finished(position: Vector2)

# Экспортируемые параметры
@export var pool_size: int = 10
@export var default_duration: float = 0.3
@export var default_intensity: float = 8.0
@export var default_texture_scale: float = 20.0
@export var fade_in_time: float = 0.05

# В начале файла, после export-переменных

# Ссылка на сцену искр
var spark_particle_scene: PackedScene = preload("res://Scenes/Effects/SparkGPUParticles.tscn")

# Пул для искр
var spark_pool: Array[GPUParticles2D] = []

# Пул объектов
var light_pool: Array[PointLight2D] = []
var active_flashes: Array[PointLight2D] = []

# Текстура света
var light_texture: GradientTexture2D

func _ready():
	_create_light_texture()
	_initialize_pool()
	add_to_group("flash_managers")

func _create_light_texture():
	"""Создает плавную текстуру градиента"""
	light_texture = GradientTexture2D.new()
	
	# Создаем плавный градиент
	var gradient = Gradient.new()
	gradient.colors = [
		Color(1, 1, 1, 1),    # Центр - яркий белый
		Color(1, 1, 1, 0.8),  # 
		Color(1, 1, 1, 0.5),  # Плавное затухание
		Color(1, 1, 1, 0.2),  #
		Color(1, 1, 1, 0)     # Края - полностью прозрачные
	]
	gradient.offsets = [0.0, 0.3, 0.6, 0.8, 1.0]  # Распределение цветов
	
	light_texture.gradient = gradient
	light_texture.fill_from = Vector2(0.5, 0.5)  # От центра
	light_texture.fill_to = Vector2(0, 0)        # К краям (радиальный градиент)
	light_texture.width = 128                     # Размер текстуры
	light_texture.height = 128                    # 128x128 пикселей

func _initialize_pool():
	"""Создает пул PointLight2D"""
	
	for i in range(pool_size):
		var light = PointLight2D.new()
		light.name = "FlashLight_{0}".format([i])
		
		# Текстура с плавным градиентом
		light.texture = light_texture
		
		# Базовые настройки
		light.energy = default_intensity
		light.visible = false
		light.shadow_enabled = true
		light.texture_scale = default_texture_scale
		
		# Маска света - все важные слои
		light.light_mask = 1 | 2 | 4 | 8 | 16  # Слои 1-5
		
		# Режим смешивания Add для яркости
		light.blend_mode = Light2D.BLEND_MODE_ADD
		
		# Range настройки
		light.range_z_min = -1024
		light.range_z_max = 1024
		
		# Высокий приоритет
		light.z_index = 1000
		
		add_child(light)
		light_pool.append(light)

# Метод для получения частиц из пула или создания новых
func _get_spark_particles() -> GPUParticles2D:
	# Ищем неактивную частицу в пуле
	for p in spark_pool:
		if is_instance_valid(p) and not p.emitting:
			return p
	
	# Если не нашли — создаем новую
	var new_particles = spark_particle_scene.instantiate()
	add_child(new_particles)
	spark_pool.append(new_particles)
	return new_particles

func create_flash(position: Vector2, color: Color = Color.ORANGE, 
				  flash_power: float = -1.0, duration: float = -1.0) -> bool:
	"""Создает вспышку с анимацией"""
	
	if flash_power < 0:
		flash_power = default_intensity
	if duration < 0:
		duration = default_duration
	
	var light = _get_available_light()
	if not light:
		return false
	
	# Настраиваем
	light.global_position = position
	light.color = color
	
	# Начинаем с нуля
	light.energy = 0
	light.visible = true
	
	# Анимация
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Вспышка
	tween.tween_property(light, "energy", flash_power, fade_in_time)
	# Затухание
	tween.tween_property(light, "energy", 0.0, duration - fade_in_time).set_delay(fade_in_time)
	
	# После завершения
	tween.finished.connect(func():
		if is_instance_valid(light):
			light.visible = false
			light.energy = flash_power  # Сбрасываем для следующего использования
			active_flashes.erase(light)
			emit_signal("flash_finished", light.global_position)
	)
	
	active_flashes.append(light)
	emit_signal("flash_created", position, color)
	
	return true

func create_explosion(position: Vector2, color: Color = Color.ORANGE, 
					  power: float = -1.0, duration: float = -1.0):
	"""Создает эффект взрыва из нескольких вспышек"""
	
	if power < 0:
		power = default_intensity
	if duration < 0:
		duration = default_duration
	
	# Центральная вспышка (самая яркая)
	create_flash(position, color, power * 1.5, duration)
	
	# 4 вспышки по сторонам (поменьше)
	var offsets = [
		Vector2(30, 0),   # право
		Vector2(-30, 0),  # лево
		Vector2(0, 30),   # низ
		Vector2(0, -30)   # верх
	]
	
	for offset in offsets:
		create_flash(position + offset, color, power * 0.7, duration * 0.8)
	
	# 4 вспышки по диагоналям (еще меньше)
	var diagonal_offsets = [
		Vector2(20, 20),
		Vector2(-20, 20),
		Vector2(20, -20),
		Vector2(-20, -20)
	]
	
	for offset in diagonal_offsets:
		create_flash(position + offset, color, power * 0.5, duration * 0.6)

func create_rapid_explosion(position: Vector2, color: Color = Color.ORANGE,
						   power: float = -1.0, base_duration: float = 0.2,
						   flash_count: int = 5, pause: float = 0.2):
	"""Создает серию быстрых вспышек с паузами"""
	
	if power < 0:
		power = default_intensity
	if base_duration < 0:
		base_duration = default_duration
	
	# Запускаем корутину для последовательных вспышек
	_rapid_explosion_async(position, color, power, base_duration, flash_count, pause)

func _rapid_explosion_async(position: Vector2, color: Color, power: float, 
						   duration: float, count: int, pause: float):
	"""Асинхронная часть для последовательных вспышек"""
	
	for i in range(count):
		# Случайное смещение (чем дальше вспышка, тем больше разброс)
		var distance = randf_range(10, 30 + i * 5)  # С каждым разом дальше
		var angle = randf() * TAU
		var offset = Vector2(cos(angle), sin(angle)) * distance
		
		# Случайная мощность (первые вспышки ярче)
		var flash_power = power * randf_range(0.7, 1.0) * (1.0 - i * 0.1)
		
		# Создаем вспышку
		create_flash(position + offset, color, flash_power, duration)
		
		# Ждем перед следующей
		await get_tree().create_timer(pause).timeout
	
	# Финальная центральная вспышка (самая яркая)
	await get_tree().create_timer(pause * 0.5).timeout
	create_flash(position, color, power * 1.5, duration * 1.5)

func _get_available_light() -> PointLight2D:
	for light in light_pool:
		if not light.visible:
			return light
	return null

# Публичный метод для создания искр
func create_sparks(position: Vector2, color: Color = Color(1.0, 0.8, 0.2), count: int = -1) -> void:
	var particles = _get_spark_particles()
	if not particles:
		return
	
	# Устанавливаем позицию
	particles.global_position = position
	
	# Если нужно изменить количество искр
	if count > 0 and particles.amount != count:
		particles.amount = count
	
	# Цвет можно менять через modulate (если текстура белая)
	particles.modulate = color
	
	# Перезапускаем
	particles.restart()
	particles.emitting = true
	
	# Для обратной связи (опционально)
	emit_signal("flash_created", position, color)
