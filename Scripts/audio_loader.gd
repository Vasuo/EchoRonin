# audio_loader.gd
extends Node

func _ready():
	# Ждём, пока AudioManager будет готов
	await get_tree().process_frame
	
	if not AudioManager:
		push_error("AudioManager не найден в автозагрузке!")
		return
	
	
	# Загружаем музыку
	_load_audio_from_folder("res://Audio/Music/", "music_", false)
	
	# Загружаем все звуки из одной папки (без подпапок)
	_load_audio_from_folder("res://Audio/SFX/", "", true)


func _load_audio_from_folder(path: String, prefix: String = "", is_sound: bool = true):
	var dir = DirAccess.open(path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and _is_audio_file(file_name):
			var full_path = path + file_name
			var stream = load(full_path)
			if stream:
				# Используем имя файла без расширения как ключ
				var key = file_name.get_basename()
				
				if is_sound:
					AudioManager.register_sound(key, stream)
				else:
					AudioManager.register_music(key, stream)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _is_audio_file(file_name: String) -> bool:
	var extension = file_name.get_extension().to_lower()
	return extension in ["ogg", "mp3", "wav", "waw"]  # waw тоже поддерживаем
