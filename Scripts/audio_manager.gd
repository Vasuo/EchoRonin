# audio_manager.gd
extends Node

# Сигналы для обратной связи
signal music_changed(music_name: String)
signal sound_played(sound_name: String)

# Экспортируемые настройки
@export var music_bus: String = "Music"
@export var sfx_bus: String = "SFX"
@export var master_bus: String = "Master"

# Словари для хранения аудио
var music_tracks: Dictionary = {}
var sound_effects: Dictionary = {}

# Текущее состояние
var current_music_player: AudioStreamPlayer = null
var is_music_muted: bool = false
var is_sfx_muted: bool = false

func _ready():
	# Автоматически добавляем в группу для удобного доступа
	add_to_group("audio_manager")
	
	# Создаём пустые узлы для музыки и звуков, если их нет
	_setup_audio_buses()
	
	# Громкость музыки (0.0 - тишина, 1.0 - макс)
	AudioManager.set_music_volume(0.5)  # 70% громкости
	# Громкость звуков
	AudioManager.set_sfx_volume(1.0)    # 80% громкости
	# Общая громкость
	AudioManager.set_master_volume(1.0)  # 100%
	

func _setup_audio_buses():
	# Проверяем, существуют ли нужные шины
	var bus_names = []
	for i in range(AudioServer.bus_count):
		bus_names.append(AudioServer.get_bus_name(i))
	
	# Если шины Music нет - создаём
	if not "Music" in bus_names:
		var new_bus_idx = AudioServer.bus_count
		AudioServer.add_bus(new_bus_idx)
		AudioServer.set_bus_name(new_bus_idx, "Music")
		# Делаем её дочерней от Master
		AudioServer.set_bus_send(new_bus_idx, "Master")
	
	# Если шины SFX нет - создаём
	if not "SFX" in bus_names:
		var new_bus_idx = AudioServer.bus_count
		AudioServer.add_bus(new_bus_idx)
		AudioServer.set_bus_name(new_bus_idx, "SFX")
		AudioServer.set_bus_send(new_bus_idx, "Master")

# ===== ЗАГРУЗКА РЕСУРСОВ =====

func register_music(key: String, stream: AudioStream):
	"""Регистрирует музыку для дальнейшего использования"""
	if stream:
		music_tracks[key] = stream
	else:
		push_error("Попытка зарегистрировать null музыку с ключом: ", key)

func register_sound(key: String, stream: AudioStream):
	"""Регистрирует звуковой эффект для дальнейшего использования"""
	if stream:
		sound_effects[key] = stream
	else:
		push_error("Попытка зарегистрировать null звук с ключом: ", key)

# ===== МУЗЫКА =====

func play_music(key: String, fade_time: float = 1.0):
	"""Проигрывает музыку по ключу с плавным переходом"""
	if not music_tracks.has(key):
		push_error("Музыка с ключом '" + key + "' не найдена!")
		return
	
	var new_stream = music_tracks[key]
	
	# Если уже играет та же музыка - ничего не делаем
	if current_music_player and current_music_player.stream == new_stream and current_music_player.playing:
		return
	
	# Создаём новый плеер для новой музыки
	var new_player = AudioStreamPlayer.new()
	new_player.stream = new_stream
	new_player.bus = music_bus
	new_player.volume_db = -80  # Начинаем с тишины для fade in
	add_child(new_player)
	new_player.play()
	
	# Если есть старая музыка - делаем fade out
	if current_music_player:
		_fade_out_and_free(current_music_player, fade_time)
	
	# Делаем fade in для новой
	current_music_player = new_player
	_create_tween_for_fade(new_player, 0, fade_time)
	
	emit_signal("music_changed", key)

func stop_music(fade_time: float = 1.0):
	"""Останавливает музыку с fade out"""
	if current_music_player:
		_fade_out_and_free(current_music_player, fade_time)
		current_music_player = null
		emit_signal("music_changed", "none")

func _fade_out_and_free(player: AudioStreamPlayer, fade_time: float):
	"""Плавно убавляет громкость и удаляет плеер"""
	if not player:
		return
	
	var tween = create_tween()
	tween.tween_property(player, "volume_db", -80, fade_time)
	tween.tween_callback(func(): 
		if player and is_instance_valid(player):
			player.stop()
			player.queue_free()
	)

func _create_tween_for_fade(player: AudioStreamPlayer, target_volume: float, fade_time: float):
	"""Создаёт твин для плавного изменения громкости"""
	var tween = create_tween()
	tween.tween_property(player, "volume_db", target_volume, fade_time)

# ===== ЗВУКОВЫЕ ЭФФЕКТЫ =====

func play_sound(key: String, position: Vector2 = Vector2.ZERO, pitch_variation: float = 0.1):
	"""Проигрывает звук. Если position != Vector2.ZERO - создаёт позиционированный звук"""
	if not sound_effects.has(key):
		push_error("Звук с ключом '" + key + "' не найден!")
		return
	
	var stream = sound_effects[key]
	
	# Создаём плеер
	var player
	if position != Vector2.ZERO:
		# Для позиционированного звука (2D)
		player = AudioStreamPlayer2D.new()
		player.global_position = position
	else:
		# Для обычного звука
		player = AudioStreamPlayer.new()
	
	player.stream = stream
	player.bus = sfx_bus
	
	# Добавляем вариацию высоты тона (чтобы звуки не были одинаковыми)
	if pitch_variation > 0:
		player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	
	add_child(player)
	player.play()
	
	# Автоматически удаляем после проигрывания
	await player.finished
	if player and is_instance_valid(player):
		player.queue_free()
	
	emit_signal("sound_played", key)

func play_sound_at_node(key: String, node: Node2D):
	"""Проигрывает звук, привязанный к узлу (например, для следования за объектом)"""
	if not sound_effects.has(key):
		push_error("Звук с ключом '" + key + "' не найден!")
		return
	
	var stream = sound_effects[key]
	
	var player = AudioStreamPlayer2D.new()
	player.stream = stream
	player.bus = sfx_bus
	player.pitch_scale = 1.0 + randf_range(-0.1, 0.1)
	
	# Добавляем как дочерний к узлу, чтобы звук двигался вместе с ним
	node.add_child(player)
	player.play()
	
	# Удаляем после проигрывания
	await player.finished
	if player and is_instance_valid(player):
		player.queue_free()

# ===== УПРАВЛЕНИЕ ГРОМКОСТЬЮ =====

func set_music_volume(value: float):
	"""Устанавливает громкость музыки (0.0 - 1.0)"""
	var bus_idx = AudioServer.get_bus_index(music_bus)
	if bus_idx >= 0:
		var db = linear_to_db(value)
		AudioServer.set_bus_volume_db(bus_idx, db)

func set_sfx_volume(value: float):
	"""Устанавливает громкость звуков (0.0 - 1.0)"""
	var bus_idx = AudioServer.get_bus_index(sfx_bus)
	if bus_idx >= 0:
		var db = linear_to_db(value)
		AudioServer.set_bus_volume_db(bus_idx, db)

func set_master_volume(value: float):
	"""Устанавливает общую громкость (0.0 - 1.0)"""
	var bus_idx = AudioServer.get_bus_index(master_bus)
	if bus_idx >= 0:
		var db = linear_to_db(value)
		AudioServer.set_bus_volume_db(bus_idx, db)

func toggle_music_mute():
	"""Вкл/Выкл музыку"""
	is_music_muted = !is_music_muted
	var bus_idx = AudioServer.get_bus_index(music_bus)
	if bus_idx >= 0:
		AudioServer.set_bus_mute(bus_idx, is_music_muted)

func toggle_sfx_mute():
	"""Вкл/Выкл звуки"""
	is_sfx_muted = !is_sfx_muted
	var bus_idx = AudioServer.get_bus_index(sfx_bus)
	if bus_idx >= 0:
		AudioServer.set_bus_mute(bus_idx, is_sfx_muted)
