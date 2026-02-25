# player.gd
extends CharacterBody2D
class_name Player

# Сигналы
signal health_changed(current: int, max: int)

# Экспортируемые параметры
@export var speed: float = 400.0
@export var max_health: int = 100
@export var starting_abilities: Array[AbilityResource] = []

# Ссылки на компоненты
@onready var ability_manager: PlayerAbilityManager = $AbilityManager

#ссылка на ресурс начальных способностей
const BASE_SWORD = preload("res://Resources/Abilities/SwordAbility.tres")

# Состояние
var health: int
var input_direction: Vector2 = Vector2.ZERO

func _ready():
	health = max_health
	add_to_group("players")
	# Даём менеджеру время инициализироваться
	call_deferred("_generate_starting_abilities")

func _generate_starting_abilities():
	var base_sword = preload("res://Resources/Abilities/SwordAbility.tres")
	var abilities_to_add = []
	
	for i in range(4):
		var new_sword = base_sword.duplicate()
		var random_damage = randi() % 30 + 10
		new_sword.base_damage = random_damage
		new_sword.display_name = "меч lvl" + str(random_damage)
		abilities_to_add.append(new_sword)
	
	# Передаём массив в менеджер для пакетной обработки
	ability_manager.add_abilities_batch(abilities_to_add)

func _process(delta):
	input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _physics_process(delta):
	velocity = input_direction * speed
	move_and_slide()
	
	if input_direction.length() > 0:
		rotation = input_direction.angle()

func _unhandled_input(event):
	if event.is_action_pressed("ability_1"):
		ability_manager.activate_ability(0)
	elif event.is_action_pressed("ability_2"):
		ability_manager.activate_ability(1)
	elif event.is_action_pressed("ability_3"):
		ability_manager.activate_ability(2)
	elif event.is_action_pressed("ability_4"):
		ability_manager.activate_ability(3)

func take_damage(amount: int, source: Node2D = null):
	health -= amount
	health = max(0, health)
	emit_signal("health_changed", health, max_health)
	
	if health <= 0:
		die()

func die():
	emit_signal("health_changed", 0, max_health)
	GlobalEvents.player_died.emit()
	# Здесь потом рестарт

func heal(amount: int):
	health = min(health + amount, max_health)
	emit_signal("health_changed", health, max_health)
