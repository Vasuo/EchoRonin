# health_component.gd
extends Node
class_name HealthComponent

signal died
signal health_changed(current: int, max: int)

@export var max_health: int = 100
var current_health: int

func _ready():
	current_health = max_health

func take_damage(amount: int, _source: Node2D = null):
	if current_health <= 0:
		return
	
	current_health = max(0, current_health - amount)
	emit_signal("health_changed", current_health, max_health)
	
	if current_health == 0:
		emit_signal("died")
		# Не удаляем родителя здесь, пусть родитель сам решает, что делать при смерти
