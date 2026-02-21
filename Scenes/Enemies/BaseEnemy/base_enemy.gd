# base_enemy.gd
extends CharacterBody2D
class_name BaseEnemy

# Сигналы
signal died(ability_resource: Resource)
signal health_changed(current: int, max: int)

# Экспортируемые параметры
@export_group("Основное")
@export var ability_drop: AbilityResource
@export var max_health: int = 30

@export_group("Движение")
@export var speed: float = 100.0

@export_group("Бой")
@export var damage: int = 10
@export var attack_range: float = 50.0

# Состояния
enum State { IDLE, CHASE, ATTACK }
var current_state: State = State.IDLE:
	set(value):
		if current_state != value:
			_exit_state(current_state)
			current_state = value
			_enter_state(value)

# Ссылки
var player: Node2D = null
var health: int

func _ready():
	health = max_health
	
	# Поиск игрока
	player = get_tree().get_first_node_in_group("players")
	
	# Подключаем таймер
	$AttackTimer.timeout.connect(_on_attack_timer_timeout)
	
	# Добавляем себя в группу enemies
	add_to_group("enemies")
	
	print("Враг готов, здоровье: ", health)

func _process(delta):
	_process_state(delta)

func _enter_state(state: State) -> void:
	print("Вошли в состояние: ", state)

func _exit_state(state: State) -> void:
	pass

func _process_state(delta: float) -> void:
	match current_state:
		State.IDLE:
			pass
		State.CHASE:
			_move_toward_player(delta)
		State.ATTACK:
			pass

func take_damage(amount: int, source: Node2D = null):
	health -= amount
	emit_signal("health_changed", health, max_health)
	
	print("Враг получил урон: ", amount, " осталось здоровья: ", health)
	
	if health <= 0:
		die()

func die():
	print("Враг умер")
	emit_signal("died", ability_drop)
	queue_free()

func _move_toward_player(delta: float):
	if not player:
		player = get_tree().get_first_node_in_group("players")
		return
	
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()

func _on_attack_timer_timeout():
	pass
