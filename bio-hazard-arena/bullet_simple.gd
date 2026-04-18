extends CharacterBody3D

@export var speed : float = 30.0
@export var damage : int = 15
@export var max_range : float = 20.0
@export var impact_particle : PackedScene  # Arrastra impact_particle.tscn aquí

var player_ref : Node = null
var direction : Vector3 = Vector3.FORWARD
var spawn_position : Vector3

func initialize(dir: Vector3, player: Node, range: float):
	direction = dir.normalized()
	player_ref = player
	max_range = range
	spawn_position = global_position
	look_at(global_position + direction, Vector3.UP)

func _ready():
	# Tiempo de vida de respaldo (por si acaso)
	await get_tree().create_timer(5.0).timeout
	queue_free()

func _physics_process(delta):
	velocity = direction * speed
	move_and_slide()
	
	# Verificar distancia recorrida
	var distance_traveled = global_position.distance_to(spawn_position)
	if distance_traveled > max_range:
		_spawn_impact_particle()
		queue_free()
		return
	
	# Detectar colisiones
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider == player_ref:
			continue
		
		if collider.has_method("take_damage"):
			collider.take_damage(damage)
		
		# 🔹 CREAR PARTÍCULA DE IMPACTO
		_spawn_impact_particle()
		
		queue_free()
		return

# 🔹 NUEVA FUNCIÓN: Crear partícula de impacto
func _spawn_impact_particle():
	if not impact_particle:
		print("❌ impact_particle no asignado en la bala")
		return
	
	var particle = impact_particle.instantiate()
	get_parent().add_child(particle)
	particle.global_position = global_position
	particle.emitting = true
	
	# Autodestruir la partícula después de 1 segundo
	await get_tree().create_timer(1.0).timeout
	particle.queue_free()
