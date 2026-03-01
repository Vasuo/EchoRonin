# ability_manager.gd
extends Node
class_name PlayerAbilityManager

# Сигналы
signal abilities_updated(ability_slots: Array)

# Экспортируемые параметры
@export var max_slots: int = 4
@export var swap_cooldown: float = 0.1
@export var starting_abilities: Array[AbilityResource] = []  # оставляем, но не используем

# Данные
var ability_slots: Array[AbilityResource] = []
var pending_swaps: Array[AbilityResource] = []
var last_swap_time: float = 0.0

func _ready():
	add_to_group("ability_managers")
	# Убираем call_deferred("_setup_starting_abilities") - теперь этим занимается игрок

func add_abilities_batch(abilities: Array):
	var old_cooldown = swap_cooldown
	swap_cooldown = 0.0
	
	for res in abilities:
		add_ability(res)
	
	swap_cooldown = old_cooldown

func add_ability(resource: AbilityResource) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_swap_time < swap_cooldown:
		pending_swaps.append(resource)
		return
	
	_perform_swap(resource)

func _perform_swap(resource: AbilityResource) -> void:
	last_swap_time = Time.get_ticks_msec() / 1000.0
	
	# ЗВУК: смена способности
	if AudioManager and AudioManager.sound_effects.has("ui_ability_swap"):
		AudioManager.play_sound("ui_ability_swap")
	
	# Если достигнут максимум слотов - удаляем самую старую (справа, последний индекс)
	if ability_slots.size() >= max_slots:
		var removed = ability_slots[-1]  # последний элемент (справа)
		ability_slots.remove_at(ability_slots.size() - 1)  # удаляем последний
	
	# Вставляем новую способность в начало (слева)
	ability_slots.insert(0, resource)
	
	# Обрабатываем отложенные замены, если есть
	if pending_swaps.size() > 0:
		var next = pending_swaps.pop_front()
		call_deferred("add_ability", next)
	
	# Отправляем сигнал об обновлении
	emit_signal("abilities_updated", ability_slots)
