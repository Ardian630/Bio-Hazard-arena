extends Camera3D

# Referencias a los jugadores (asignadas desde main.gd)
var targets : Array[Node3D] = []

@export var base_offset : Vector3 = Vector3(0, 15, 5)
@export var min_height  : float = 12.0
@export var max_height  : float = 30.0
@export var zoom_margin : float = 5.0   # Margen extra en unidades 3D
@export var smooth_speed: float = 5.0

func _ready():
	# Asegurar rotación fija desde el inicio
	rotation_degrees = Vector3(-70, 0, 0)

func _process(delta):
	# Filtrar targets inválidos (jugadores muertos / queue_free)
	var valid_targets : Array[Node3D] = []
	for t in targets:
		if is_instance_valid(t):
			valid_targets.append(t)
	
	if valid_targets.is_empty():
		return
	
	# ── Calcular punto medio (Vector3) entre todos los jugadores válidos ──
	var center = Vector3.ZERO
	for t in valid_targets:
		center += t.global_position
	center /= valid_targets.size()
	
	# ── Calcular distancia máxima entre jugadores ──
	var max_dist = 0.0
	if valid_targets.size() > 1:
		for i in range(valid_targets.size()):
			for j in range(i + 1, valid_targets.size()):
				var d = valid_targets[i].global_position.distance_to(
					valid_targets[j].global_position
				)
				if d > max_dist:
					max_dist = d
	
	# ── Ajustar altura (eje Y) dinámicamente ──
	# Más separación entre jugadores → más altura para mantener ambos en pantalla
	var target_height = base_offset.y + max_dist * 0.5
	target_height = clamp(target_height, min_height, max_height)
	
	var target_offset = Vector3(base_offset.x, target_height, base_offset.z)
	var target_pos = center + target_offset
	
	# ── Interpolación suave ──
	global_position = global_position.lerp(target_pos, smooth_speed * delta)
	
	# ── Rotación fija ──
	rotation_degrees = Vector3(-70, 0, 0)
