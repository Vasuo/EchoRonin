# vfx_manager.gd
extends Node

# Сигналы
signal flash_created(position: Vector2, color: Color)
signal flash_finished(position: Vector2)

# Экспортируемые параметры
@export var pool_size: int = 30
@export var default_duration: float = 0.3
@export var default_intensity: float = 8.0
@export var default_texture_scale: float = 20.0
@export var fade_in_time: float = 0.05

# ===== Пул для световых вспышек =====
var light_pool: Array[PointLight2D] = []
var active_flashes: Array[PointLight2D] = []
var light_texture: GradientTexture2D

# ===== Типизированные пулы для частиц =====
enum SparkType { IMPACT, DEATH, EXPLOSION }
enum SparkPriority { LOW, NORMAL, HIGH }

# Сцены для разных типов искр
var spark_scenes: Dictionary = {
	SparkType.IMPACT: preload("res://Scenes/Effects/SparkGPUParticles_impact.tscn"),
	SparkType.DEATH: preload("res://Scenes/Effects/SparkGPUParticles_death.tscn"),
	SparkType.EXPLOSION: preload("res://Scenes/Effects/SparkGPUParticles_explosion.tscn"),
}

# Пулы для разных типов
var spark_pools: Dictionary = {}
var active_sparks: Dictionary = {}

# Очередь с приоритетами
var priority_queue: Dictionary = {}

func _ready():
	_create_light_texture()
	_initialize_pool()
	add_to_group("vfx_managers")
	
	_init_spark_pools()
	
	for priority in SparkPriority.values():
		priority_queue[priority] = []
	
	# Прогреваем эффекты через небольшой таймер, чтобы не тормозить старт
	call_deferred("_deferred_preheat")

func _deferred_preheat():
	preheat_all_effects()

# ===== ИНИЦИАЛИЗАЦИЯ =====

func _init_spark_pools():
	for type in SparkType.values():
		spark_pools[type] = []
		active_sparks[type] = 0

func _create_light_texture():
	light_texture = GradientTexture2D.new()
	
	var gradient = Gradient.new()
	gradient.colors = [
		Color(1, 1, 1, 1),
		Color(1, 1, 1, 0.8),
		Color(1, 1, 1, 0.5),
		Color(1, 1, 1, 0.2),
		Color(1, 1, 1, 0)
	]
	gradient.offsets = [0.0, 0.3, 0.6, 0.8, 1.0]
	
	light_texture.gradient = gradient
	light_texture.fill_from = Vector2(0.5, 0.5)
	light_texture.fill_to = Vector2(0, 0)
	light_texture.width = 128
	light_texture.height = 128

func _initialize_pool():
	for i in range(pool_size):
		var light = PointLight2D.new()
		light.name = "FlashLight_{0}".format([i])
		light.texture = light_texture
		light.energy = default_intensity
		light.visible = false
		light.shadow_enabled = true
		light.texture_scale = default_texture_scale
		light.light_mask = 1 | 2 | 4 | 8 | 16
		light.blend_mode = Light2D.BLEND_MODE_ADD
		light.range_z_min = -1024
		light.range_z_max = 1024
		light.z_index = 1000
		
		add_child(light)
		light_pool.append(light)

func preheat_all_effects():
	# Создаем временную точку для прогрева
	var temp_pos = Vector2(-1000, -1000)  # за пределами экрана
	
	# Запускаем каждый тип эффектов по одному разу
	for type in SparkType.values():
		var particles = _create_new_spark_particle(type)
		particles.global_position = temp_pos
		particles.emitting = true
		particles.restart()
		
		# Даем один кадр на компиляцию
		await get_tree().process_frame
		
		# Возвращаем в пул (но не удаляем)
		particles.emitting = false

# ===== СВЕТОВЫЕ ВСПЫШКИ =====

func create_flash(position: Vector2, color: Color = Color.ORANGE, 
				  flash_power: float = -1.0, duration: float = -1.0) -> bool:
	if flash_power < 0:
		flash_power = default_intensity
	if duration < 0:
		duration = default_duration
	
	var light = _get_available_light()
	if not light:
		return false
	
	light.global_position = position
	light.color = color
	light.energy = 0
	light.visible = true
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(light, "energy", flash_power, fade_in_time)
	tween.tween_property(light, "energy", 0.0, duration - fade_in_time).set_delay(fade_in_time)
	
	tween.finished.connect(func():
		if is_instance_valid(light):
			light.visible = false
			light.energy = flash_power
			active_flashes.erase(light)
			emit_signal("flash_finished", light.global_position)
	)
	
	active_flashes.append(light)
	emit_signal("flash_created", position, color)
	
	return true

func create_explosion(position: Vector2, color: Color = Color.ORANGE, 
					  power: float = -1.0, duration: float = -1.0):
	if power < 0:
		power = default_intensity
	if duration < 0:
		duration = default_duration
	
	create_flash(position, color, power * 1.5, duration)
	
	var offsets = [
		Vector2(30, 0), Vector2(-30, 0),
		Vector2(0, 30), Vector2(0, -30)
	]
	
	for offset in offsets:
		create_flash(position + offset, color, power * 0.7, duration * 0.8)
	
	var diagonal_offsets = [
		Vector2(20, 20), Vector2(-20, 20),
		Vector2(20, -20), Vector2(-20, -20)
	]
	
	for offset in diagonal_offsets:
		create_flash(position + offset, color, power * 0.5, duration * 0.6)

func create_rapid_explosion(position: Vector2, color: Color = Color.ORANGE,
						   power: float = -1.0, base_duration: float = 0.2,
						   flash_count: int = 5, pause: float = 0.2):
	if power < 0:
		power = default_intensity
	if base_duration < 0:
		base_duration = default_duration
	
	_rapid_explosion_async(position, color, power, base_duration, flash_count, pause)

func _rapid_explosion_async(position: Vector2, color: Color, power: float, 
						   duration: float, count: int, pause: float):
	for i in range(count):
		var distance = randf_range(10, 30 + i * 5)
		var angle = randf() * TAU
		var offset = Vector2(cos(angle), sin(angle)) * distance
		var flash_power = power * randf_range(0.7, 1.0) * (1.0 - i * 0.1)
		
		create_flash(position + offset, color, flash_power, duration)
		await get_tree().create_timer(pause).timeout
	
	await get_tree().create_timer(pause * 0.5).timeout
	create_flash(position, color, power * 1.5, duration * 1.5)

func _get_available_light() -> PointLight2D:
	for light in light_pool:
		if not light.visible:
			return light
	return null

# ===== СИСТЕМА ЧАСТИЦ С ПРИОРИТЕТАМИ =====

func _try_get_spark_particles(type: SparkType) -> GPUParticles2D:
	var pool = spark_pools[type]
	
	for p in pool:
		if is_instance_valid(p) and not p.emitting:
			return p
	
	return null

func _create_new_spark_particle(type: SparkType) -> GPUParticles2D:
	var new_particles = spark_scenes[type].instantiate()
	add_child(new_particles)
	
	new_particles.finished.connect(_on_spark_finished.bind(new_particles, type))
	
	spark_pools[type].append(new_particles)
	return new_particles

func _setup_and_launch_spark(particles: GPUParticles2D, type: SparkType,
							 position: Vector2, direction: Vector2, color: Color,
							 count: int, spread: float):
	
	particles.global_position = position
	
	if direction != Vector2.ZERO:
		particles.global_rotation = direction.angle()
	
	var material = particles.process_material as ParticleProcessMaterial
	if material:
		material.spread = spread
	
	if count > 0 and particles.amount != count:
		particles.amount = count
	
	particles.modulate = color
	
	active_sparks[type] += 1
	particles.restart()
	particles.emitting = true
	
	emit_signal("flash_created", position, color)

func _on_spark_finished(particles: GPUParticles2D, type: SparkType):
	active_sparks[type] -= 1
	_process_priority_queue.call_deferred()

func _process_priority_queue():
	for priority in [SparkPriority.HIGH, SparkPriority.NORMAL, SparkPriority.LOW]:
		var queue = priority_queue[priority]
		var i = 0
		while i < queue.size():
			var request = queue[i]
			var particles = _try_get_spark_particles(request.type)
			
			if particles:
				_setup_and_launch_spark(particles, request.type,
					request.position, request.direction, 
					request.color, request.count, request.spread)
				queue.remove_at(i)
			else:
				if spark_pools[request.type].size() < pool_size * 2:
					var new_particles = _create_new_spark_particle(request.type)
					_setup_and_launch_spark(new_particles, request.type,
						request.position, request.direction,
						request.color, request.count, request.spread)
					queue.remove_at(i)
				else:
					i += 1

func _process(delta):
	_process_priority_queue()

func create_sparks(position: Vector2, type: SparkType, direction: Vector2 = Vector2.ZERO, 
				   color: Color = Color(1.0, 0.8, 0.2), count: int = -1, spread: float = 45.0,
				   priority: SparkPriority = SparkPriority.NORMAL) -> void:
	
	var particles = _try_get_spark_particles(type)
	
	if particles:
		_setup_and_launch_spark(particles, type, position, direction, color, count, spread)
	else:
		if spark_pools[type].size() < pool_size * 2:
			var new_particles = _create_new_spark_particle(type)
			_setup_and_launch_spark(new_particles, type, position, direction, color, count, spread)
		else:
			var request = {
				"type": type,
				"position": position,
				"direction": direction,
				"color": color,
				"count": count,
				"spread": spread,
				"priority": priority
			}
			priority_queue[priority].append(request)

# ===== ПУБЛИЧНЫЕ МЕТОДЫ ДЛЯ РАЗНЫХ ТИПОВ ЭФФЕКТОВ =====

func create_impact_sparks(position: Vector2, direction: Vector2, color: Color = Color(1.0, 0.9, 0.5)):
	create_sparks(position, SparkType.IMPACT, direction, color, 30, 20.0, SparkPriority.LOW)

func create_death_sparks(position: Vector2, color: Color = Color(1.0, 0.5, 0.0)):
	create_sparks(position, SparkType.DEATH, Vector2.RIGHT, color, 80, 360.0, SparkPriority.HIGH)

func create_explosion_sparks(position: Vector2, color: Color = Color(1.0, 0.3, 0.0)):
	create_sparks(position, SparkType.EXPLOSION, Vector2.RIGHT, color, 300, 360.0, SparkPriority.HIGH)
