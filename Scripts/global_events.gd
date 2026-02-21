# global_events.gd
extends Node

# Сигналы игрока
signal player_died
signal player_took_damage(amount: int, current_health: int)
signal player_healed(amount: int)

# Сигналы способностей
signal ability_swapped(slot_index: int, old_ability_id: String, new_ability_id: String)
signal ability_activated(slot_index: int)

# Сигналы врагов
signal enemy_spawned(enemy: Node2D)
signal enemy_killed(enemy: Node2D, ability_dropped: Resource)

# Сигналы волн
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)

# Визуальные эффекты
signal flash_requested(position: Vector2, color: Color, intensity: float)
