extends CharacterBody2D
class_name Player

# Сигналы
signal health_changed(current: int, max: int)

@onready var vfx_manager = get_node("/root/Main/VisualEffectsManager")  # Имя совпадает

# Экспортируемые параметры
@export var speed: float = 400.0
@export var max_health: int = 100

# Ссылки на компоненты
@onready var ability_manager: PlayerAbilityManager = $AbilityManager
@onready var animated_sprite = $AnimatedSprite2D
@onready var animation_player = $AnimationPlayer  # Обязательно добавить ноду!

# Состояние
var health: int
var input_direction: Vector2 = Vector2.ZERO
var is_attacking: bool = false
var current_ability: Ability = null  # Текущая активная способность
var attack_direction: Vector2 = Vector2.DOWN

enum Direction { DOWN, UP, LEFT, RIGHT }
var current_direction = Direction.DOWN

func _ready():
	health = max_health
	add_to_group("players")
	animated_sprite.animation_finished.connect(_on_animation_finished)
	
	# Генерируем стартовые способности
	call_deferred("_generate_starting_abilities")
	
	if vfx_manager:
		vfx_manager.apply_neon_style(animated_sprite, Color(0, 1, 1), Color(1, 1, 0))
		animated_sprite.material.set_shader_parameter("outline_width", 1.0)

func _generate_starting_abilities():
	var base_sword = load("res://Resources/Abilities/SwordAbility.tres")
	var abilities_to_add = []
	
	for i in range(4):
		var new_sword = base_sword.duplicate()
		var random_damage = randi() % 30 + 10  # от 10 до 40
		new_sword.base_damage = random_damage
		new_sword.display_name = "меч lvl" + str(random_damage)
		abilities_to_add.append(new_sword)
	
	ability_manager.add_abilities_batch(abilities_to_add)

func _process(delta):
	input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _physics_process(delta):
	velocity = input_direction * speed
	move_and_slide()
	
	if input_direction.length() > 0:
		rotation = input_direction.angle()
	
	# Обновляем анимацию движения только если не атакуем
	if not is_attacking:
		update_sprite_direction()
		update_animation(input_direction)

# --- Вспомогательные методы для анимации ---
func update_sprite_direction():
	animated_sprite.rotation = -rotation

func update_animation(direction: Vector2):
	if direction.length() > 0:
		if abs(direction.x) > abs(direction.y):
			if direction.x > 0:
				current_direction = Direction.RIGHT
			else:
				current_direction = Direction.LEFT
		else:
			if direction.y > 0:
				current_direction = Direction.DOWN
			else:
				current_direction = Direction.UP
		play_animation("run")
	else:
		play_animation("idle")

func play_animation(base_name: String):
	var anim_name = base_name + "_" + direction_string(current_direction)
	if animated_sprite.sprite_frames.has_animation(anim_name):
		if animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name)

func direction_string(dir: Direction) -> String:
	match dir:
		Direction.DOWN: return "down"
		Direction.UP: return "up"
		Direction.LEFT: return "left"
		Direction.RIGHT: return "right"
		_: return "down"
# --- Конец вспомогательных методов ---

func _unhandled_input(event):
	# Запускаем атаку при нажатии кнопок способностей
	if event.is_action_pressed("ability_1"):
		start_attack(0)
	elif event.is_action_pressed("ability_2"):
		start_attack(1)
	elif event.is_action_pressed("ability_3"):
		start_attack(2)
	elif event.is_action_pressed("ability_4"):
		start_attack(3)

func start_attack(slot_index: int):
	if is_attacking:
		return
	if slot_index < 0 or slot_index >= ability_manager.ability_slots.size():
		return
	
	var ability_resource = ability_manager.ability_slots[slot_index]
	if not ability_resource or not ability_resource.ability_scene:
		return
	
	is_attacking = true
	attack_direction = get_facing_direction()
	
	var ability_instance = ability_resource.ability_scene.instantiate()
	add_child(ability_instance)
	current_ability = ability_instance as Ability
	
	if not current_ability:
		ability_instance.queue_free()
		is_attacking = false
		return
	
	# >>>>>>> ИСПРАВЛЕНИЕ: передаём урон из ресурса в способность <<<<<<<
	if current_ability.has_method("set_damage"):
		current_ability.set_damage(ability_resource.base_damage)
	else:
		current_ability.damage = ability_resource.base_damage
	# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
	
	var direction_str = direction_string(current_direction)
	var anim_name = current_ability.get_animation_name(direction_str)
	
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
	else:
		apply_damage()
		finish_attack()
		return
	
	current_ability.activate(self, attack_direction)
	
	if animation_player and animation_player.has_animation("attack_effects"):
		animation_player.play("attack_effects")

# Возвращает вектор направления, в который "смотрит" игрок
func get_facing_direction() -> Vector2:
	if is_attacking:
		return attack_direction
	
	match current_direction:
		Direction.DOWN: return Vector2.DOWN
		Direction.UP: return Vector2.UP
		Direction.LEFT: return Vector2.LEFT
		Direction.RIGHT: return Vector2.RIGHT
		_: return Vector2.DOWN

# Вызывается из AnimationPlayer в момент удара
func apply_damage():
	if current_ability and is_instance_valid(current_ability):
		current_ability.apply_damage(self, attack_direction)

# Вызывается по сигналу animated_sprite.animation_finished
func _on_animation_finished():
	if is_attacking:
		finish_attack()

func finish_attack():
	if current_ability and is_instance_valid(current_ability):
		current_ability.cleanup()
		current_ability.queue_free()
		current_ability = null
	
	is_attacking = false
	# Возвращаемся к обычной анимации
	update_animation(input_direction)

func enable_ability_hitbox():
	if current_ability and current_ability.has_method("enable_hitbox"):
		current_ability.enable_hitbox()

func disable_ability_hitbox():
	if current_ability and current_ability.has_method("disable_hitbox"):
		current_ability.disable_hitbox()

# --- Старые методы здоровья (оставляем без изменений) ---
func take_damage(amount: int, source: Node2D = null):
	health -= amount
	health = max(0, health)
	emit_signal("health_changed", health, max_health)
	
	# ЗВУК: игрок получил урон
	if AudioManager and AudioManager.sound_effects.has("player_hit"):
		AudioManager.play_sound("player_hit", global_position)
	
	animated_sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	animated_sprite.modulate = Color.WHITE
	
	if health <= 0:
		die()

func heal(amount: int):
	health = min(health + amount, max_health)
	emit_signal("health_changed", health, max_health)


func die():
	var death_position = global_position
	
	# 👇 МОЩНЫЙ ВЗРЫВ
	if VFXManager:
		VFXManager.create_rapid_explosion(
			global_position,
			Color(1.0, 1.0, 1.0),  # Оранжевый
			500.0,                    # Мощность
			0.15,                     # Длительность каждой вспышки
			15,                       # Количество вспышек
			0.1                     # Пауза между вспышками
		)
	
	if VFXManager:
		VFXManager.create_explosion_sparks(death_position, Color(1.0, 0.3, 0.0))  # ярко-красный взрыв
	
	emit_signal("health_changed", 0, max_health)
	GlobalEvents.player_died.emit()
	
	# Можно добавить небольшую задержку перед удалением,
	# чтобы взрыв успел начаться
	await get_tree().create_timer(0.1).timeout
	
	queue_free()
