# ability_manager.gd
extends Node
class_name PlayerAbilityManager

# Сигналы
signal abilities_updated(ability_slots: Array)
signal ability_activated(slot_index: int)

# Экспортируемые параметры
@export var max_slots: int = 4
@export var swap_cooldown: float = 0.1

# Данные
var ability_slots: Array[AbilityResource] = []
var pending_swaps: Array[AbilityResource] = []
var last_swap_time: float = 0.0

func _ready():
	add_to_group("ability_managers")
	print("AbilityManager готов")

func _process(delta):
	# Отладка: нажимаем Enter для теста смены способности
	if Input.is_action_just_pressed("ui_accept"):
		_debug_add_random_ability()

func add_ability(resource: AbilityResource) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_swap_time < swap_cooldown:
		print("Кулдаун смены, добавляем в очередь")
		pending_swaps.append(resource)
		return
	
	_perform_swap(resource)

func _perform_swap(resource: AbilityResource) -> void:
	last_swap_time = Time.get_ticks_msec() / 1000.0
	
	print("Меняем способность на: ", resource.display_name if resource else "None")
	
	if ability_slots.size() >= max_slots:
		_remove_ability_at(0)
	
	ability_slots.append(resource)
	_create_ability_instance(resource)
	
	if pending_swaps.size() > 0:
		var next = pending_swaps.pop_front()
		call_deferred("add_ability", next)
	
	emit_signal("abilities_updated", ability_slots)

func _remove_ability_at(index: int) -> void:
	if index < 0 or index >= ability_slots.size():
		return
	
	var removed = ability_slots[index]
	print("Удаляем способность: ", removed.display_name if removed else "None")
	ability_slots.remove_at(index)
	# Здесь потом будем удалять сцену способности

func _create_ability_instance(resource: AbilityResource) -> void:
	if not resource:
		print("Нет ресурса способности")
		return
	
	print("Создаём экземпляр способности: ", resource.display_name)
	# Здесь потом будем инстанциировать сцену

func _debug_add_random_ability():
	var stub = AbilityResource.new()
	stub.id = "stub_" + str(randi() % 100)
	stub.display_name = "Тестовая " + stub.id
	add_ability(stub)
