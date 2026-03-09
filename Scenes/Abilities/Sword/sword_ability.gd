extends Ability
class_name SwordAbility

@export var damage: int = 25

@onready var hitbox: Area2D = $hitbox
@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox_shape: CollisionShape2D = $hitbox/CollisionShape2D

func _ready():
	# Подключаем сигнал попадания
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.monitoring = false
	sprite.visible = false

func activate(player: Player, direction: Vector2) -> void:
	sprite.visible = true
	sprite.global_position = player.global_position + direction * 32
	sprite.global_rotation = direction.angle()
	
	# ЗВУК: взмах мечом
	if AudioManager:
		# 3 вариации: weapon_swing_1, weapon_swing_2, weapon_swing_3
		if AudioManager.sound_effects.has("weapon_swing_1"):
			var variation = randi() % 3 + 1
			AudioManager.play_sound("weapon_swing_" + str(variation), player.global_position)

# Вызывается из AnimationPlayer для включения хитбокса
func enable_hitbox():
	hitbox.monitoring = true

# Вызывается из AnimationPlayer для выключения хитбокса
func disable_hitbox():
	hitbox.monitoring = false

func _on_hitbox_body_entered(body):
	if body is BaseEnemy and body.has_method("take_damage"):
		body.take_damage(damage, get_parent())
		
		# ЗВУК: попадание по врагу
		if AudioManager:
			# 2 вариации: weapon_hit_1, weapon_hit_2
			if AudioManager.sound_effects.has("weapon_hit_1"):
				var variation = randi() % 2 + 1
				AudioManager.play_sound("weapon_hit_" + str(variation), body.global_position)
		
		# 👇 НОВЫЙ КОД: искры при попадании
		if VFXManager:
			# Бело-желтые искры, 15 штук
			VFXManager.create_sparks(body.global_position, Color(1.0, 0.9, 0.5), 15)
		
		hitbox.monitoring = false

func get_animation_name(direction_string: String) -> String:
	return "attack_" + direction_string
