# wave_manager.gd
extends Node
class_name WaveManager

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal enemy_spawned(enemy: Node2D)

@export var spawn_points: Array[Marker2D] = []
@export var enemy_types: Array[PackedScene] = []
@export var wave_duration: float = 60.0
@export var enemies_per_wave: int = 5

var current_wave: int = 0
var enemies_alive: int = 0
var is_wave_active: bool = false
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
	
	# Отложенный вызов, чтобы группа успела зарегистрироваться
	call_deferred("_refresh_spawn_points")
	
	# Отложенный запуск волны
	call_deferred("start_wave", 1)

func start_wave(wave_number: int = -1):
	if wave_number > 0:
		current_wave = wave_number
	else:
		current_wave += 1
	
	enemies_alive = 0
	is_wave_active = true
	
	spawn_timer.wait_time = 2.0
	spawn_timer.start()
	wave_timer.wait_time = wave_duration
	wave_timer.start()
	
	emit_signal("wave_started", current_wave)
	
func _spawn_enemy():
	if not is_wave_active: 
		return
	if enemies_alive >= enemies_per_wave: 
		return
	if enemy_types.is_empty():
		return
	if spawn_points.is_empty():
		return
	
	# Выбираем случайного врага из списка
	var enemy_scene = enemy_types[randi() % enemy_types.size()]
	var enemy = enemy_scene.instantiate()
	
	# Выбираем случайную точку спавна
	var spawn_point = spawn_points[randi() % spawn_points.size()]
	enemy.global_position = spawn_point.global_position
	
	# Добавляем на сцену (родитель WaveManager'а — это Arena)
	get_parent().add_child(enemy)
	
	# Подключаем сигнал смерти
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)
	
	enemies_alive += 1
	emit_signal("enemy_spawned", enemy)

func _on_enemy_died(ability_resource: AbilityResource):
	enemies_alive -= 1
	
	# Создаём уникальную версию способности
	if ability_resource and ability_resource.id == "sword":
		var new_resource = ability_resource.duplicate()
		var random_damage = randi() % 30 + 10  # от 10 до 40
		new_resource.base_damage = random_damage
		new_resource.display_name = "меч lvl" + str(random_damage)
		ability_resource = new_resource
	
	# Передаём способность игроку
	var player = get_tree().get_first_node_in_group("players")
	if player and player.ability_manager:
		player.ability_manager.add_ability(ability_resource)
	
	if enemies_alive == 0:
		_complete_wave()

func _complete_wave():
	is_wave_active = false
	spawn_timer.stop()
	wave_timer.stop()
	
	emit_signal("wave_completed", current_wave)
	
	await get_tree().create_timer(2.0).timeout
	start_wave()

func _refresh_spawn_points():
	if spawn_points.is_empty():
		var points = get_tree().get_nodes_in_group("spawn_points")
		for point in points:
			if point is Marker2D:
				spawn_points.append(point)
