extends BaseEnemy

@onready var attack_cooldown_timer: Timer = $AttackTimer

func _ready():
	super()
	current_state = State.IDLE
	attack_cooldown_timer.timeout.connect(_on_attack_cooldown_end)

func _process_state(delta):
	match current_state:
		State.IDLE:
			if player and global_position.distance_to(player.global_position) < 200:
				current_state = State.CHASE
		
		State.CHASE:
			_move_toward_player(delta)
			if player and global_position.distance_to(player.global_position) < attack_range:
				current_state = State.ATTACK
		
		State.ATTACK:
			velocity = Vector2.ZERO
			move_and_slide()
			if attack_cooldown_timer.is_stopped():
				_try_attack()

func _try_attack():
	if not player:
		current_state = State.IDLE
		return
	
	var distance = global_position.distance_to(player.global_position)
	if distance <= attack_range:
		if player.has_method("take_damage"):
			player.take_damage(damage)
		attack_cooldown_timer.start()
	else:
		# Если игрок отошел - возвращаемся в погоню
		current_state = State.CHASE

func _on_attack_cooldown_end():
	# После перезарядки проверяем, нужно ли снова атаковать
	if current_state == State.ATTACK and player:
		var distance = global_position.distance_to(player.global_position)
		if distance > attack_range:
			current_state = State.CHASE

func take_damage(amount: int, source: Node2D = null):
	super(amount, source)
