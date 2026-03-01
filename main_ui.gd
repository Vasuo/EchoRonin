extends CanvasLayer

@onready var slot_labels = [
	$MainControl/MainMargin/SlotsContainer/Slot1/Label,
	$MainControl/MainMargin/SlotsContainer/Slot2/Label,
	$MainControl/MainMargin/SlotsContainer/Slot3/Label,
	$MainControl/MainMargin/SlotsContainer/Slot4/Label
]

@onready var key_labels = [
	$MainControl/MainMargin/SlotsContainer/Slot1/MarginContainer/KeyLabel,
	$MainControl/MainMargin/SlotsContainer/Slot2/MarginContainer/KeyLabel,
	$MainControl/MainMargin/SlotsContainer/Slot3/MarginContainer/KeyLabel,
	$MainControl/MainMargin/SlotsContainer/Slot4/MarginContainer/KeyLabel
]

@onready var icon_rects = [
	$MainControl/MainMargin/SlotsContainer/Slot1/TextureRect,
	$MainControl/MainMargin/SlotsContainer/Slot2/TextureRect,
	$MainControl/MainMargin/SlotsContainer/Slot3/TextureRect,
	$MainControl/MainMargin/SlotsContainer/Slot4/TextureRect
]

@onready var health_bar = $MainControl/MainMargin/HealthBar
@onready var wave_label = $MainControl/MainMargin/WaveLabel

func _ready():
	var player = get_tree().get_first_node_in_group("players")
	if player:
		player.health_changed.connect(_on_player_health_changed)
		_on_player_health_changed(player.health, player.max_health)
		
		if player.ability_manager:
			player.ability_manager.abilities_updated.connect(_on_abilities_updated)
			_on_abilities_updated(player.ability_manager.ability_slots)
	
	var wave_manager = get_tree().get_first_node_in_group("wave_managers")
	if wave_manager:
		wave_manager.wave_started.connect(_on_wave_started)
	
	_setup_key_labels()

func _setup_key_labels():
	for i in range(key_labels.size()):
		if key_labels[i] != null:
			key_labels[i].text = str(i + 1)

func _on_player_health_changed(current: int, max: int):
	health_bar.value = (float(current) / max) * 100

func _on_abilities_updated(slots: Array):
	for i in range(slot_labels.size()):
		if i < slots.size() and slots[i] and slot_labels[i] != null:
			var ability = slots[i]
			slot_labels[i].text = ability.display_name
			
			# Обновляем иконку
			if icon_rects[i] != null:
				if ability.id == "sword":
					var level = ability.base_damage
					if level < 20:
						icon_rects[i].texture = load("res://Art/Icons/sword_low.png")
					elif level < 30:
						icon_rects[i].texture = load("res://Art/Icons/sword_medium.png")
					else:
						icon_rects[i].texture = load("res://Art/Icons/sword_high.png")
				else:
					icon_rects[i].texture = ability.icon
		else:
			if slot_labels[i] != null:
				slot_labels[i].text = "пусто"
			if icon_rects[i] != null:
				icon_rects[i].texture = null

func _on_wave_started(wave_number: int):
	wave_label.text = "Волна " + str(wave_number)
