extends CanvasLayer

@onready var player = get_tree().get_first_node_in_group("players")
@onready var material = $RimLightEffect.material as ShaderMaterial
@onready var viewport = get_viewport()

@export var rim_color: Color = Color(0.0, 1.0, 1.0)
@export var rim_distance: float = 2000.0
@export var rim_width: float = 4.0
@export var intensity: float = 1.0
@export var angle_threshold: float = 0.2

func _ready():
	if not material:
		push_error("RimLightController: Material not found!")
		return
	update_all_parameters()

func _process(delta):
	if not player or not material:
		return
	
	var camera = viewport.get_camera_2d()
	if not camera:
		return
	
	# Получаем границы камеры в мировых координатах
	var camera_center = camera.global_position
	var viewport_size = viewport.size  # Это Vector2i
	
	# Конвертируем Vector2i в Vector2 для математики
	var viewport_size_f = Vector2(viewport_size.x, viewport_size.y)
	var camera_size = viewport_size_f / camera.zoom
	
	# Вычисляем левый верхний угол камеры
	var camera_top_left = camera_center - camera_size / 2
	
	# Передаём в шейдер как vec4 (x, y, width, height)
	material.set_shader_parameter("camera_rect", [camera_top_left.x, camera_top_left.y, camera_size.x, camera_size.y])
	
	# Также передаём UV-позицию игрока
	var player_uv = (player.global_position - camera_top_left) / camera_size
	material.set_shader_parameter("player_uv", player_uv)

func update_all_parameters():
	if not material:
		return
	
	material.set_shader_parameter("rim_color", rim_color)
	material.set_shader_parameter("rim_distance", rim_distance)
	material.set_shader_parameter("rim_width", rim_width)
	material.set_shader_parameter("intensity", intensity)
	material.set_shader_parameter("angle_threshold", angle_threshold)
