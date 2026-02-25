extends Node2D
class_name SwordAbility

@export var data: AbilityResource
@export var damage: int = 25

@onready var cooldown_timer: Timer = $cooldown_timer
@onready var hitbox: Area2D = $hitbox
@onready var sprite: Sprite2D = $Sprite2D

var can_attack: bool = true
var player: Node2D

func initialize(resource: AbilityResource):
	data = resource
	player = get_parent() as Node2D
	damage = resource.base_damage
	
func activate() -> void:
	if not can_attack or not player:
		pass
		return
	_perform_attack()

func _perform_attack():
	can_attack = false
	cooldown_timer.start()
	
	# Визуальный фидбек
	sprite.visible = true
	sprite.global_position = player.global_position + Vector2(32, 0).rotated(player.global_rotation)
	sprite.global_rotation = player.global_rotation
	
	# Физический запрос
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	
	# Квадратный хитбокс 32x32
	var rect = RectangleShape2D.new()
	rect.size = Vector2(32, 32)
	query.shape = rect
	
	# Позиция: центр квадрата на расстоянии 32 пикселя ПЕРЕД игроком
	var offset = Vector2(32, 0).rotated(player.global_rotation)
	query.transform = Transform2D.IDENTITY.rotated(player.global_rotation)
	query.transform.origin = player.global_position + offset
	
	query.collision_mask = 1
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var body = result.collider
		if body and body != player and body.has_method("take_damage"):
			body.take_damage(damage, player)
	
	sprite.visible = false

func _ready():
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	sprite.visible = false
	hitbox.monitoring = false

func _on_cooldown_timeout():
	can_attack = true
