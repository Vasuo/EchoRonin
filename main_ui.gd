extends CanvasLayer

@onready var slot_labels = [
	$MainControl/MainMargin/SlotsContainer/Slot1/Label,
	$MainControl/MainMargin/SlotsContainer/Slot2/Label,
	$MainControl/MainMargin/SlotsContainer/Slot3/Label,
	$MainControl/MainMargin/SlotsContainer/Slot4/Label
]

@onready var health_bar = $MainControl/MainMargin/HealthBar
@onready var wave_label = $MainControl/MainMargin/WaveLabel

func _ready():
	var player = get_tree().get_first_node_in_group("players")
	if player:
		# Подключаем сигнал
		player.health_changed.connect(_on_player_health_changed)
		# Устанавливаем начальное значение
		_on_player_health_changed(player.health, player.max_health)
		
		if player.ability_manager:
			player.ability_manager.abilities_updated.connect(_on_abilities_updated)
			# Если у менеджера уже есть способности - обновляем
			_on_abilities_updated(player.ability_manager.ability_slots)
	
	var wave_manager = get_tree().get_first_node_in_group("wave_managers")
	if wave_manager:
		wave_manager.wave_started.connect(_on_wave_started)

func _on_player_health_changed(current: int, max: int):
	health_bar.value = (float(current) / max) * 100

func _on_abilities_updated(slots: Array):
	for i in range(slot_labels.size()):
		if i < slots.size() and slots[i]:
			slot_labels[i].text = slots[i].display_name
		else:
			slot_labels[i].text = "пусто"

func _on_wave_started(wave_number: int):
	wave_label.text = "Волна " + str(wave_number)
