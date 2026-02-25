# ability_manager.gd
extends Node
class_name PlayerAbilityManager

var active_instances: Array[Node] = []

# Сигналы
signal abilities_updated(ability_slots: Array)
signal ability_activated(slot_index: int)

# Экспортируемые параметры
@export var max_slots: int = 4
@export var swap_cooldown: float = 0.1
@export var starting_abilities: Array[AbilityResource] = []

# Данные
var ability_slots: Array[AbilityResource] = []
var pending_swaps: Array[AbilityResource] = []
var last_swap_time: float = 0.0

func _ready():
	add_to_group("ability_managers")
	
	# Добавляем стартовые способности ПОСЛЕ того как всё загрузилось
	call_deferred("_setup_starting_abilities")

func _setup_starting_abilities():
	for resource in starting_abilities:
		add_ability(resource)

func _process(delta):
	# Отладка: нажимаем Enter для теста смены способности
	pass#if Input.is_action_just_pressed("ui_accept"):

func add_abilities_batch(abilities: Array):
	# Временно отключаем кулдаун
	var old_cooldown = swap_cooldown
	swap_cooldown = 0.0
	
	for res in abilities:
		add_ability(res)
	
	# Возвращаем кулдаун
	swap_cooldown = old_cooldown

func add_ability(resource: AbilityResource) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_swap_time < swap_cooldown:
		pending_swaps.append(resource)
		return
	
	_perform_swap(resource)

func activate_ability(slot_index: int):
	if slot_index < 0 or slot_index >= ability_slots.size():
		return
	
	# Здесь потом будем вызывать activate() у сцены способности
	if slot_index < active_instances.size():
		var instance = active_instances[slot_index]
		if instance and instance.has_method("activate"):
			instance.activate()
		else:
			pass
	else:
		pass

func _perform_swap(resource: AbilityResource) -> void:
	last_swap_time = Time.get_ticks_msec() / 1000.0
	
	
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
	ability_slots.remove_at(index)
	
	# Удаляем из active_instances
	if index < active_instances.size():
		var instance = active_instances[index]
		if instance and is_instance_valid(instance):
			instance.queue_free()
		active_instances.remove_at(index)

func _create_ability_instance(resource: AbilityResource) -> void:
	if not resource:
		return
	
	if not resource.ability_scene:
		return
	
	var instance = resource.ability_scene.instantiate()
	
	# ВАЖНО: добавляем как child к ИГРОКУ, а не к менеджеру
	get_parent().add_child(instance)
	
	if instance.has_method("initialize"):
		instance.initialize(resource)
	
	active_instances.append(instance)

func _debug_add_random_ability():
	var stub = AbilityResource.new()
	stub.id = "stub_" + str(randi() % 100)
	stub.display_name = "Тестовая " + stub.id
	add_ability(stub)
