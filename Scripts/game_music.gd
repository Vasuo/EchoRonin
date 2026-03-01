extends Node

@export var battle_music_key: String = "battle"
@export var menu_music_key: String = "menu"
@export var boss_music_key: String = "boss"

func _ready():
	if GlobalEvents:
		GlobalEvents.wave_started.connect(_on_wave_started)
		GlobalEvents.wave_completed.connect(_on_wave_completed)
		GlobalEvents.player_died.connect(_on_player_died)
	
	await get_tree().create_timer(0.5).timeout
	_start_battle_music()

func _start_battle_music():
	if AudioManager.music_tracks.has(battle_music_key):
		AudioManager.play_music(battle_music_key, 2.0)
	elif AudioManager.music_tracks.size() > 0:
		var first_key = AudioManager.music_tracks.keys()[0]
		AudioManager.play_music(first_key, 2.0)

func _on_wave_started(wave_number: int):
	if wave_number == 5 and AudioManager.music_tracks.has(boss_music_key):
		AudioManager.play_music(boss_music_key, 1.5)

func _on_wave_completed(wave_number: int):
	if wave_number < 5:
		_start_battle_music()
	
	if AudioManager.sound_effects.has("ui_wave_complete"):
		AudioManager.play_sound("ui_wave_complete")

func _on_player_died():
	AudioManager.stop_music(1.0)
	if AudioManager.sound_effects.has("ui_game_over"):
		AudioManager.play_sound("ui_game_over")
