# test_enemy.gd
extends BaseEnemy
class_name TestEnemy

# Уникальные параметры
@export var speed: float = 100.0
@export var damage: int = 10
@export var attack_range: float = 50.0
@export var aggro_range: float = 200.0
@export var attack_cooldown: float = 1.0

# Состояния
enum State { IDLE, CHASE, ATTACK }
var current_state: State = State.IDLE
var is_attacking: bool = false
var attack_started: bool = false  # Флаг, что анимация атаки уже идёт
var attack_timeout: float = 0.0  # Таймер для принудительного сброса атаки

# Ссылки на компоненты
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var attack_timer: Timer = $AttackTimer
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D

func _ready():
	super()
	
	# Настройка таймера
	attack_timer.wait_time = attack_cooldown
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	
	# Подключаем сигналы анимации
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)
	
	# Подключаем сигналы хитбокса
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	
	# Хитбокс выключен по умолчанию
	hitbox.monitoring = false
	
	current_state = State.IDLE

func _physics_process(delta):
	# Обновляем ссылку на игрока
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("players")
		if not player:
			return
	
	# Таймаут для принудительного сброса атаки
	if is_attacking:
		attack_timeout += delta
		if attack_timeout > 1.0:  # Максимальная длина анимации
			_force_reset_attack()
	
	# Машина состояний
	match current_state:
		State.IDLE:
			_idle_state(delta)
		State.CHASE:
			_chase_state(delta)
		State.ATTACK:
			_attack_state(delta)
	
	# Поворачиваем врага к игроку (кроме времени, когда анимация атаки уже идёт)
	if player and current_state != State.ATTACK and not attack_started:
		rotation = (player.global_position - global_position).angle()
	
	# Компенсируем поворот для спрайта (всегда вертикален)
	if animated_sprite:
		animated_sprite.rotation = -rotation
	
	move_and_slide()

# ===== СОСТОЯНИЯ =====

func _idle_state(delta):
	velocity = Vector2.ZERO
	animated_sprite.play("idle")
	
	if player and global_position.distance_to(player.global_position) < aggro_range:
		current_state = State.CHASE

func _chase_state(delta):
	if not player:
		current_state = State.IDLE
		return
	
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * speed
	animated_sprite.play("run")
	
	var distance = global_position.distance_to(player.global_position)
	if distance < attack_range:
		current_state = State.ATTACK
		attack_started = false  # Сбрасываем флаг для новой атаки

func _attack_state(delta):
	velocity = Vector2.ZERO
	
	if not player:
		current_state = State.IDLE
		return
	
	# Если атака ещё не началась - проверяем дистанцию и начинаем
	if not attack_started:
		var distance = global_position.distance_to(player.global_position)
		
		# Если игрок ушёл далеко до начала атаки - отменяем
		if distance > attack_range * 1.2:
			current_state = State.CHASE
			return
		
		# Игрок рядом - начинаем атаку, если таймер готов
		if attack_timer.is_stopped():
			_start_attack()
		else:
			# Ждём окончания кулдауна
			animated_sprite.play("idle")
	else:
		# Атака уже идёт - не реагируем на движение игрока
		# Просто ждём окончания анимации
		pass

# ===== АТАКА =====

func _start_attack():
	is_attacking = true
	attack_started = true
	attack_timeout = 0.0
	
	# ЗВУК: враг атакует
	if AudioManager and AudioManager.sound_effects.has("enemy_attack"):
		AudioManager.play_sound_at_node("enemy_attack", self)
	
	if player:
		rotation = (player.global_position - global_position).angle()
		if animated_sprite:
			animated_sprite.rotation = -rotation
	
	animated_sprite.play("attack")
	
	if animation_player and animation_player.has_animation("attack_effects"):
		animation_player.play("attack_effects")

func _force_reset_attack():
	"""Принудительный сброс атаки при зависании"""
	is_attacking = false
	attack_started = false
	attack_timeout = 0.0
	hitbox.monitoring = false
	attack_timer.start()

# Вызывается из AnimationPlayer для включения хитбокса
func enable_hitbox():
	hitbox.monitoring = true

# Вызывается из AnimationPlayer для выключения хитбокса
func disable_hitbox():
	hitbox.monitoring = false

# Сигнал попадания по игроку
func _on_hitbox_body_entered(body):
	if body == player and body.has_method("take_damage"):
		body.take_damage(damage, self)
		# Выключаем хитбокс после первого попадания, чтобы не било несколько раз
		hitbox.monitoring = false

# ===== ОБРАБОТЧИКИ =====

func _on_animation_finished():
	if animated_sprite and animated_sprite.animation == "attack":
		is_attacking = false
		attack_started = false
		attack_timeout = 0.0
		hitbox.monitoring = false
		attack_timer.start()

func _on_attack_timer_timeout():
	# Таймер сработал - если мы в состоянии ATTACK и атака ещё не начата, начинаем новую атаку
	if current_state == State.ATTACK and not attack_started:
		_start_attack()

# ===== ПОЛУЧЕНИЕ УРОНА =====

func take_damage(amount: int, source: Node2D = null):
	super(amount, source)
	
	# Визуальный фидбек
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
	
	# Если враг получил урон во время атаки - не сбрасываем атаку,
	# просто показываем, что ему больно
