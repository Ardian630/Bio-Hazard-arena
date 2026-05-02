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
	
	# Elegir tipo aleatorio (0 = vida, 1 = energía)
	var random_type = randi() % 2
	object.object_type = random_type
	
	# Posición aleatoria dentro del área
	var random_x = randf_range(-spawn_area_size.x / 2, spawn_area_size.x / 2)
	var random_z = randf_range(-spawn_area_size.y / 2, spawn_area_size.y / 2)
	
	object.global_position = Vector3(random_x, 0.5, random_z)
	
	# Añadir a la escena
	add_child(object)
	current_objects += 1
	
	# Conectar señal para cuando desaparezca (recolectado o timeout)
	object.tree_exited.connect(func(): current_objects -= 1)
	
	print("✨ Objeto (", "VIDA" if random_type == 0 else "ENERGÍA", ") apareció en: (", random_x, ", ", random_z, ")")

# Función para limpiar todos los power-ups
func clear_all_Objects():
	for child in get_children():
		if child.has_method("_apply_effect"):  # Detectar power-ups
			child.queue_free()
	current_objects = 0
