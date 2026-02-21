# player.gd
extends CharacterBody2D
class_name Player

# Сигналы
signal health_changed(current: int, max: int)

# Экспортируемые параметры
@export var speed: float = 400.0
@export var max_health: int = 100

# Ссылки на компоненты
@onready var ability_manager: PlayerAbilityManager = $AbilityManager

# Состояние
var health: int
var input_direction: Vector2 = Vector2.ZERO

func _ready():
	health = max_health
	add_to_group("players")
	print("Игрок готов, здоровье: ", health)

func _process(delta):
	input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _physics_process(delta):
	velocity = input_direction * speed
	move_and_slide()
	
	if input_direction.length() > 0:
		rotation = input_direction.angle()

func take_damage(amount: int, source: Node2D = null):
	health -= amount
	health = max(0, health)
	emit_signal("health_changed", health, max_health)
	
	print("Игрок получил урон: ", amount, " здоровье: ", health)
	
	if health <= 0:
		die()

func die():
	print("Игрок умер")
	emit_signal("health_changed", 0, max_health)
	GlobalEvents.player_died.emit()
	# Здесь потом рестарт

func heal(amount: int):
	health = min(health + amount, max_health)
	emit_signal("health_changed", health, max_health)
