# visual_effects_manager.gd
extends Node

@onready var world_env: WorldEnvironment = $WorldEnvironment
# CanvasModulate удален - мы решили его не использовать

var shader_cache: Dictionary = {}

func _ready():
	pass

func get_neon_material(glow_color: Color, base_color: Color = Color.WHITE, pulse_offset: float = 0.0) -> ShaderMaterial:
	var cache_key = glow_color.to_html() + base_color.to_html() + str(pulse_offset)
	if shader_cache.has(cache_key):
		return shader_cache[cache_key]
	
	var material = ShaderMaterial.new()
	material.shader = load("res://Shaders/neon_outline_full.gdshader")
	material.set_shader_parameter("glow_color", glow_color)
	material.set_shader_parameter("base_color", base_color)
	material.set_shader_parameter("pulse_offset", pulse_offset)
	
	shader_cache[cache_key] = material
	return material

func apply_neon_style(node: CanvasItem, glow_color: Color, base_color: Color = Color.WHITE):
	"""Применяет неоновый стиль с отдельными цветами для свечения и основы"""
	if not node:
		return
	node.material = get_neon_material(glow_color, base_color, randf() * 10.0)
