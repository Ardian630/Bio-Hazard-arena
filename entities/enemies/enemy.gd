extends CharacterBody3D

# Velocidad
@export var speed : float = 3.0
@export var max_speed_multiplier : float = 2.5

# Tamaño
@export var max_scale_multiplier : float = 2.0

# Daño
@export var damage_amount : int = 10
@export var detection_range : float = 15.0
@export var damage_cooldown : float = 1.0

# Vida
@export var health : int = 30
@export var base_health : int = 30
@export var health_increase_per_wave : int = 5

# Velocidad por horda
@export var base_speed : float = 3.0
@export var speed_increase_per_wave : float = 0.3

# Parámetros de linterna
@export var flashlight_cone_angle : float = 60.0
@export var flashlight_max_distance : float = 25.0
@export var time_to_max_scale : float = 1.0

# Referencias
var players : Array[Node3D] = []
var target_player : Node3D = null  # El más cercano
var can_damage : bool = true
var is_alive : bool = true

# Variables de escalado
var current_scale_factor : float = 1.0
var current_speed_multiplier : float = 1.0
var is_in_light : bool = false

# Nodo del modelo
@export var model_node : Node3D
var original_scale : Vector3  # Se inicializa en la funcion _ready()

@onready var nav_agent : NavigationAgent3D = $NavigationAgent3D

func _ready():
	# Buscar ambos jugadores
	var p1 = get_node_or_null("/root/Main/Player1")
	var p2 = get_node_or_null("/root/Main/Player2")
	if p1: players.append(p1)
	if p2: players.append(p2)
	
	# Seleccionar target inicial
	target_player = _get_closest_player()
	
	if model_node:
		original_scale = model_node.scale
	else:
		print("¡Error! No se ha asignado el model_node en el inspector del enemigo")
		
	# Bloquear eje Y para que no salgan volando por colisiones
	axis_lock_linear_y = true

# 🔹 Configurar dificultad según la horda
func set_wave_difficulty(wave: int):
	# Aumentar vida según la horda
	var extra_health = (wave - 1) * health_increase_per_wave
	health = base_health + extra_health
	
	# Aumentar velocidad según la horda
	speed = base_speed + (wave - 1) * speed_increase_per_wave
	
	print("👾 Enemigo nivel ", wave, " - Vida: ", health, " - Velocidad: ", speed)

func _physics_process(delta):
	if not is_alive or players.is_empty():
		return
	
	# Elegir al jugador más cercano como objetivo
	target_player = _get_closest_player()
	if not target_player:
		return
	
	_check_if_in_flashlight()
	_update_scale_and_speed(delta)
	
	if global_position.distance_to(target_player.global_position) <= detection_range:
		_chase_player(delta)
	
	move_and_slide()
	_check_collisions()

func _get_closest_player() -> Node3D:
	var closest : Node3D = null
	var min_dist : float = INF
	for p in players:
		if is_instance_valid(p) and p.current_health > 0:
			var d = global_position.distance_to(p.global_position)
			if d < min_dist:
				min_dist = d
				closest = p
	return closest

func _check_if_in_flashlight():
	# Comprobar contra TODOS los jugadores vivos (cualquier linterna afecta)
	is_in_light = false
	
	for player in players:
		if not is_instance_valid(player):
			continue
		if not player.has_method("get_flashlight_direction"):
			continue
		
		var flashlight_dir = player.get_flashlight_direction()
		
		if flashlight_dir == Vector3.ZERO:
			continue
		
		var to_enemy = (global_position - player.global_position).normalized()
		var dot = flashlight_dir.dot(to_enemy)
		var cone_cos = cos(deg_to_rad(flashlight_cone_angle * 0.5))
		var distance = global_position.distance_to(player.global_position)
		
		if dot > cone_cos and distance < flashlight_max_distance:
			var space = get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(player.global_position, global_position)
			var ex: Array[RID] = [self.get_rid(), player.get_rid()]
			query.exclude = ex
			var result = space.intersect_ray(query)
			if result.is_empty():
				is_in_light = true
				return  # Basta con que UNA linterna le ilumine

func _update_scale_and_speed(delta):
	var rate = delta / time_to_max_scale
	
	if is_in_light:
		current_scale_factor = min(max_scale_multiplier, current_scale_factor + rate * 2.0)
	else:
		current_scale_factor = max(1.0, current_scale_factor - rate)
	
	if max_scale_multiplier > 1.0:
		current_speed_multiplier = 1.0 + (current_scale_factor - 1.0) * (max_speed_multiplier - 1.0) / (max_scale_multiplier - 1.0)
	
	if model_node:
		model_node.scale = original_scale * current_scale_factor

func _chase_player(delta):
	if not target_player:
		return
	
	# Se le indica al agente que su destino final es el jugador más cercano
	nav_agent.target_position = target_player.global_position
	
	# El agente calcula la ruta esquivando paredes y da el siguiente paso a tomar
	var next_path_position = nav_agent.get_next_path_position()
	
	# Se calcula dirección hacia ese "paso" en vez de ir directo al jugador
	var dir = (next_path_position - global_position).normalized()
	dir.y = 0
	
	velocity.x = dir.x * speed * current_speed_multiplier
	velocity.z = dir.z * speed * current_speed_multiplier
	
	if dir.length_squared() > 0:
		var target_angle = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)

func _check_collisions():
	if not can_damage or not is_alive:
		return
	
	for i in range(get_slide_collision_count()):
		var collider = get_slide_collision(i).get_collider()
		# Dañar a CUALQUIER jugador con el que colisione
		if collider and collider.is_in_group("players"):
			_damage_player(collider)
			break

func _damage_player(player: Node3D = null):
	if not player:
		player = target_player
	if not player or not can_damage or not is_alive:
		return
	
	if player.has_method("take_damage"):
		var scaled_damage = int(damage_amount * current_scale_factor)
		player.take_damage(scaled_damage)
		print("👾 Enemigo ataca a J", player.player_id, "! Daño: ", scaled_damage)
		
		can_damage = false
		await get_tree().create_timer(damage_cooldown).timeout
		can_damage = true

func take_damage(amount: int):
	if not is_alive:
		return
	
	health -= amount
	print("👾 Enemigo recibe ", amount, " daño. Vida restante: ", health)
	AudioManager.play_sfx("enemy_hurt")
	
	if health <= 0:
		die()

func die():
	print("💀 Enemigo muerto")
	AudioManager.play_sfx("enemy_death")
	is_alive = false
	
	# Emitir señal para el wave manager
	emit_signal("died")
	
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	
	await get_tree().create_timer(1.5).timeout
	queue_free()

func _find_all_meshes(node: Node, result: Array):
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_find_all_meshes(child, result)

# 🔹 SEÑAL para notificar muerte al WaveManager
signal died
