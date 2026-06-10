extends Node3D

@export var object_scene : PackedScene  # Arrastra power_up.tscn aquí
@export var spawn_interval : float = 20.0
@export var max_objects : int = 5
@export var spawn_area_size : Vector2 = Vector2(40, 40)  # X, Z

var current_objects : int = 0
var timer : float = 0

func _ready():
	# Iniciar con algunos power-ups aleatorios
	for i in range(3):
		_spawn_random_object()

func _physics_process(delta):
	timer += delta
	if timer >= spawn_interval and current_objects < max_objects:
		timer = 0
		_spawn_random_object()

func _spawn_random_object():
	if not object_scene:
		print("❌ object scene no asignada")
		return
	
	# Crear power-up
	var object = object_scene.instantiate()
	
	# Distribución ponderada: Vida 35%, Energía 35%, Mecha 15%, ThunderBolt 15%
	var roll = randf()
	var random_type : int
	if roll < 0.35:
		random_type = 0  # HEALTH
	elif roll < 0.70:
		random_type = 1  # ENERGY
	elif roll < 0.85:
		random_type = 2  # MECHA
	else:
		random_type = 3  # THUNDERBOLT
	
	object.object_type = random_type
	
	# Posición aleatoria dentro del área
	var random_x = randf_range(-spawn_area_size.x / 2, spawn_area_size.x / 2)
	var random_z = randf_range(-spawn_area_size.y / 2, spawn_area_size.y / 2)
	
	# Añadir a la escena
	add_child(object)
	
	object.global_position = Vector3(random_x, 0.5, random_z)

	current_objects += 1
	
	# Conectar señal para cuando desaparezca (recolectado o timeout)
	object.tree_exited.connect(func(): current_objects -= 1)
	
	var type_names = ["VIDA", "ENERGÍA", "MECHA", "THUNDERBOLT"]
	print("✨ Objeto (", type_names[random_type], ") apareció en: (", random_x, ", ", random_z, ")")

# Función para limpiar todos los power-ups
func clear_all_Objects():
	for child in get_children():
		if child.has_method("_apply_effect"):  # Detectar power-ups
			child.queue_free()
	current_objects = 0
