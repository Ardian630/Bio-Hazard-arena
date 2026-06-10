extends CharacterBody3D

# IDENTIDAD DEL JUGADOR
@export var player_id : int = 1  # 1 o 2

# MOVIMIENTO
@export var speed : float = 5.0
@export var rotation_speed : float = 10.0

# VIDA
@export var max_health : int = 100
@export var current_health : int = 100
@export var invincibility_time : float = 1.0

# ENERGÍA
@export var max_energy : int = 100
@export var current_energy : float = 100.0
@export var flashlight_energy_drain : float = 0.2
@export var shoot_energy_cost : int = 10

# DASH
@export var dash_energy_cost : int = 20
@export var dash_speed : float = 20.0
@export var dash_duration : float = 0.3
@export var dash_cooldown : float = 1.5

# DISPARO
@export var bullet_scene : PackedScene
@export var shoot_cooldown : float = 0.3
@export var bullet_max_range : float = 10.0
@export var muzzle_flash_scene : PackedScene

# Nodos --------------------------------------------------------------------
@export var model_node : Node3D
@onready var muzzle : Node3D = $Muzzle
@onready var flashlight_node : SpotLight3D = $Flashlight

# UI - se asigna externamente desde main.gd
var ui : Control = null

# ACCIONES DE INPUT (se construyen en _ready según player_id)
var action_move_left   : String
var action_move_right  : String
var action_move_forward: String
var action_move_back   : String
var action_shoot       : String
var action_dash        : String
var action_flashlight  : String

# APUNTADO (solo relevante para J2 con mando)
var action_aim_left    : String
var action_aim_right   : String
var action_aim_up      : String
var action_aim_down    : String

# MODO DE APUNTADO
enum AimMode { MOUSE, STICK, MOVE_DIRECTION }
var aim_mode : AimMode = AimMode.MOUSE
var last_move_direction : Vector3 = Vector3.FORWARD

# Variables internas
var can_shoot : bool = true
var is_invincible : bool = false
var flashlight_on : bool = false
var h_key_timer : float = 0.0

# Variables de dash
var is_dashing : bool = false
var can_dash : bool = true
var dash_timer : float = 0.0
var dash_cooldown_timer : float = 0.0
var dash_direction : Vector3 = Vector3.FORWARD

# ESTADO MECHA
var is_mecha_active : bool = false
var mecha_timer_node : Timer = null
var original_speed : float
var original_shoot_cooldown : float
var original_model_scale : Vector3

# ESTADO THUNDERBOLT
var is_thunderbolt_active : bool = false

# Diccionario para materiales originales
var original_surface_materials : Dictionary = {}

# SEÑALES
signal player_died(id: int)

func _ready():
	# ── Construir nombres de acciones según player_id ──
	var prefix = "p" + str(player_id) + "_"
	action_move_left    = prefix + "move_left"
	action_move_right   = prefix + "move_right"
	action_move_forward = prefix + "move_forward"
	action_move_back    = prefix + "move_back"
	action_shoot        = prefix + "shoot"
	action_dash         = prefix + "dash"
	action_flashlight   = prefix + "flashlight"
	action_aim_left     = prefix + "aim_left"
	action_aim_right    = prefix + "aim_right"
	action_aim_up       = prefix + "aim_up"
	action_aim_down     = prefix + "aim_down"
	
	# ── Detectar modo de apuntado desde GameManager ──
	var device_type = GameManager.p1_device if player_id == 1 else GameManager.p2_device
	if device_type == "gamepad":
		aim_mode = AimMode.STICK
	else:
		if player_id == 1:
			aim_mode = AimMode.MOUSE
		else:
			aim_mode = AimMode.MOVE_DIRECTION
	
	# ── Añadir al grupo para detección genérica ──
	add_to_group("players")
	
	# Bloquear eje Y para que no salga volando por colisiones
	axis_lock_linear_y = true
	
	# Guardar materiales originales
	_save_original_materials()
	
	# Mostrar configuración de energía
	print("🔋 [J", player_id, "] Flashlight Energy Drain = ", flashlight_energy_drain)
	print("   Esto significa: ", max_energy / flashlight_energy_drain, " segundos de duración")
	
	# Inicializar UI
	if ui:
		await get_tree().process_frame
		ui.update_health(current_health, max_health)
		ui.update_energy(current_energy, max_energy)
	
	# Estado inicial de la linterna (apagada)
	_update_flashlight_visibility()
	
	# Verificar nodos importantes
	if not muzzle:
		print("❌ [J", player_id, "] ERROR: Nodo Muzzle no encontrado")
	if not flashlight_node:
		print("❌ [J", player_id, "] ERROR: Nodo Flashlight no encontrado")
	if not bullet_scene:
		print("❌ [J", player_id, "] ERROR: Bullet Scene no asignada")

func _save_original_materials():
	if not model_node:
		return
	
	var meshes = []
	_find_all_meshes(model_node, meshes)
	
	for mesh_instance in meshes:
		if mesh_instance.mesh:
			var surface_materials = []
			var surface_count = mesh_instance.mesh.get_surface_count()
			
			for i in range(surface_count):
				# Obtener el material activo (puede ser override o del mesh base)
				var mat = mesh_instance.get_active_material(i)
				if mat:
					surface_materials.append(mat.duplicate(true))
				else:
					surface_materials.append(null)
			
			original_surface_materials[mesh_instance] = surface_materials

func _physics_process(delta):
	# MOVIMIENTO (solo si no está dashando)
	if not is_dashing:
		var input_dir = Input.get_vector(action_move_left, action_move_right, action_move_forward, action_move_back)
		velocity.x = input_dir.x * speed
		velocity.z = input_dir.y * speed
		
		# Guardar última dirección de movimiento para aim automático
		if input_dir.length_squared() > 0.01:
			last_move_direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	else:
		# Durante el dash, mantener velocidad constante
		velocity = dash_direction * dash_speed
	
	move_and_slide()
	
	# ROTACIÓN según modo de apuntado (solo si no está dashando)
	if not is_dashing:
		match aim_mode:
			AimMode.MOUSE:
				_rotate_towards_mouse(delta)
			AimMode.STICK:
				_rotate_towards_stick(delta)
			AimMode.MOVE_DIRECTION:
				_rotate_towards_movement(delta)
	
	# =============================================
	# DASH
	# =============================================
	if Input.is_action_just_pressed(action_dash) and can_dash and not is_dashing and current_energy >= dash_energy_cost:
		_start_dash()
	
	# Temporizadores del dash
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			_end_dash()
	
	if not can_dash:
		dash_cooldown_timer -= delta
		if dash_cooldown_timer <= 0:
			can_dash = true
	
	# =============================================
	# CONSUMO DE ENERGÍA DE LA LINTERNA
	# =============================================
	if flashlight_on and current_energy > 0 and not is_dashing:
		var drain = flashlight_energy_drain * delta
		current_energy = max(0, current_energy - drain)
		
		if ui:
			ui.update_energy(current_energy, max_energy)
		
		if current_energy <= 0:
			flashlight_on = false
			_update_flashlight_visibility()
			print("🔋 [J", player_id, "] Sin energía - linterna apagada")
	
	# =============================================
	# CONTROL DE LINTERNA
	# =============================================
	if Input.is_action_just_pressed(action_flashlight) and not is_dashing:
		if current_energy > 0:
			flashlight_on = not flashlight_on
			_update_flashlight_visibility()
			if flashlight_on:
				AudioManager.play_sfx("flashlight_on")
			else:
				AudioManager.play_sfx("flashlight_off")
			print("🔦 [J", player_id, "] Linterna: ", "ON" if flashlight_on else "OFF")
		else:
			print("🔋 [J", player_id, "] Sin energía - no puedes encender la linterna")
	
	# =============================================
	# DISPARO
	# =============================================
	if Input.is_action_just_pressed(action_shoot) and not is_dashing:
		if current_energy >= shoot_energy_cost:
			shoot()
		else:
			print("🔋 [J", player_id, "] Sin energía - no puedes disparar")
	
	# =============================================
	# TECLAS DE PRUEBA (solo J1 para no conflictos)
	# =============================================
	if player_id == 1:
		if Input.is_key_pressed(KEY_H) and h_key_timer <= 0:
			take_damage(10)
			h_key_timer = 0.5
		
		if Input.is_key_pressed(KEY_R) and h_key_timer <= 0:
			recharge_energy(20)
			h_key_timer = 0.5
		
		if Input.is_key_pressed(KEY_T) and h_key_timer <= 0:
			current_energy = max(0, current_energy - 10)
			if ui:
				ui.update_energy(current_energy, max_energy)
			print("🔋 Consumo manual T: ", current_energy)
			h_key_timer = 0.5
	
	if h_key_timer > 0:
		h_key_timer -= delta

# =============================================
# FUNCIONES DE ROTACIÓN
# =============================================
func _rotate_towards_mouse(delta):
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	
	# Si usamos ratón, la rotación del modelo depende de rotation_speed y mouse_sensitivity
	var current_sens = GameManager.mouse_sensitivity * 2.0
	
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var dir = camera.project_ray_normal(mouse_pos)
	
	var denom = dir.y
	if abs(denom) > 0.001:
		var t = -from.y / denom
		var point = from + dir * t
		
		var dir_to_mouse = point - global_position
		dir_to_mouse.y = 0
		
		if dir_to_mouse.length_squared() > 0.01:
			dir_to_mouse = dir_to_mouse.normalized()
			var target_y = atan2(-dir_to_mouse.x, -dir_to_mouse.z)
			rotation.y = lerp_angle(rotation.y, target_y, rotation_speed * current_sens * delta)

func _rotate_towards_stick(delta):
	var current_sens = GameManager.stick_sensitivity * 2.0
	var aim_input = Input.get_vector(
		action_aim_left, action_aim_right,
		action_aim_up, action_aim_down
	)
	
	# Zona muerta manual para evitar que el joystick se mueva solo por desgaste
	if aim_input.length() < 0.15:
		# Si no movemos el stick derecho, mantiene el AimMode.STICK pero no rota,
		# o puedes dejar tu lógica de cambiar a MOVE_DIRECTION si lo prefieres.
		return
	
	# En Godot 3D: 
	# -aim_input.x define la rotación horizontal (Izquierda / Derecha)
	# -aim_input.y define la rotación de profundidad en el eje Z (Arriba / Abajo)
	var target_y = atan2(-aim_input.x, -aim_input.y)
	
	# Suavizado de rotación para que no sea un giro brusco instantáneo
	rotation.y = lerp_angle(rotation.y, target_y, rotation_speed * current_sens * delta)

func _rotate_towards_movement(delta):
	# Si detectamos joystick derecho en cualquier frame → volver a STICK (solo si no somos mouse)
	if aim_mode != AimMode.MOUSE:
		var aim_input = Input.get_vector(
			action_aim_left, action_aim_right,
			action_aim_up, action_aim_down
		) # <--- Revisa que este paréntesis cierre correctamente
		
		if aim_input.length() > 0.2:
			aim_mode = AimMode.STICK
			return
	
	# Determinar la sensibilidad según el modo actual
	var current_sens = 0.0
	if aim_mode != AimMode.MOUSE:
		current_sens = GameManager.stick_sensitivity * 2.0
	else:
		current_sens = GameManager.mouse_sensitivity * 2.0
	
	if last_move_direction.length_squared() > 0.01:
		var target_y = atan2(-last_move_direction.x, -last_move_direction.z)
		rotation.y = lerp_angle(rotation.y, target_y, rotation_speed * current_sens * delta)

# =============================================
# FUNCIÓN DE DISPARO
# =============================================
func shoot():
	if not can_shoot or not bullet_scene or not muzzle:
		return
	
	# Consumir energía
	current_energy -= shoot_energy_cost
	
	# Actualizar UI
	if ui:
		ui.update_energy(current_energy, max_energy)
	
	# Calcular dirección de disparo según modo de apuntado
	var shoot_dir : Vector3
	
	match aim_mode:
		AimMode.MOUSE:
			# Obtener punto del ratón en el mundo
			var camera = get_viewport().get_camera_3d()
			if not camera:
				return
			var mouse_pos_2d = get_viewport().get_mouse_position()
			var from = camera.project_ray_origin(mouse_pos_2d)
			var ray_dir = camera.project_ray_normal(mouse_pos_2d)
			
			var denom = ray_dir.y
			if abs(denom) < 0.001:
				return
			
			var t = -from.y / denom
			var mouse_world_pos = from + ray_dir * t
			
			# Calcular dirección desde el muzzle al ratón
			shoot_dir = (mouse_world_pos - muzzle.global_position).normalized()
		
		AimMode.STICK, AimMode.MOVE_DIRECTION:
			# Disparar en la dirección a la que mira el personaje
			shoot_dir = -global_transform.basis.z
	
	shoot_dir.y = 0
	
	# Pedir bala prestada al Pool
	var bullet = ProjectilePool.get_bullet()
	
	if not bullet:
		return # Se cancela el disparo si el pool esta vacio
	
	# Configurar bala
	bullet.global_position = muzzle.global_position
	if bullet.has_method("initialize"):
		bullet.initialize(shoot_dir, self, bullet_max_range)
	
	# Partículas de disparo
	_spawn_muzzle_flash()
	AudioManager.play_sfx("shoot")
	
	# Cooldown
	can_shoot = false
	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true

func _spawn_muzzle_flash():
	if not muzzle_flash_scene or not muzzle:
		return
	
	var flash = muzzle_flash_scene.instantiate()
	muzzle.add_child(flash)
	flash.global_position = muzzle.global_position
	flash.emitting = true
	
	await get_tree().create_timer(0.5).timeout
	flash.queue_free()

# =============================================
# FUNCIONES DE LINTERNA
# =============================================
func _update_flashlight_visibility():
	if flashlight_node:
		flashlight_node.visible = flashlight_on

func get_flashlight_direction() -> Vector3:
	if not flashlight_on or not flashlight_node or current_energy <= 0:
		return Vector3.ZERO
	return -flashlight_node.global_transform.basis.z

# =============================================
# FUNCIONES DE DASH
# =============================================
func _start_dash():
	# Verificar energía
	if current_energy < dash_energy_cost:
		print("⚡ [J", player_id, "] Sin energía para dash")
		return
	
	# Consumir energía
	current_energy -= dash_energy_cost
	if ui:
		ui.update_energy(current_energy, max_energy)
	
	# Dirección del dash (hacia donde mira el personaje)
	dash_direction = -global_transform.basis.z
	dash_direction.y = 0
	dash_direction = dash_direction.normalized()
	
	# Activar dash
	is_dashing = true
	can_dash = false
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	
	# Efecto visual: cambiar color de materiales a amarillo
	_set_dash_color(true)
	
	AudioManager.play_sfx("dash")
	
	print("⚡ [J", player_id, "] Dash! Energía restante: ", current_energy)

func _end_dash():
	is_dashing = false
	
	# Restaurar colores originales
	_set_dash_color(false)
	
	# Pequeño impulso residual
	velocity = dash_direction * (dash_speed * 0.2)
	
	print("⚡ [J", player_id, "] Dash terminado")

# Función auxiliar para cambiar color durante el dash
func _set_dash_color(is_dashing_active: bool):
	_update_materials()

# =============================================
# FUNCIONES DE VIDA Y DAÑO
# =============================================
func take_damage(amount: int):
	if is_invincible:
		return
	
	current_health = max(0, current_health - amount)
	print("💥 [J", player_id, "] Daño: ", current_health, "/", max_health)
	
	if ui:
		ui.update_health(current_health, max_health)
	
	if current_health <= 0:
		die()
		return
	
	AudioManager.play_sfx("player_hurt")
	is_invincible = true
	_set_damage_effect(true)
	
	await get_tree().create_timer(invincibility_time).timeout
	
	if is_invincible and current_health > 0:
		is_invincible = false
		_set_damage_effect(false)

func _set_damage_effect(is_damaged: bool):
	_update_materials()

func die():
	print("💀 Jugador ", player_id, " muerto")
	AudioManager.play_sfx("player_death")
	
	# Rotar a horizontal
	var current_y_rotation = rotation_degrees.y
	rotation_degrees = Vector3(90, current_y_rotation, 0)
	global_position.y += 0.5
	
	# Desactivar físicas
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	
	# Emitir señal para que main.gd gestione el Game Over colectivo
	emit_signal("player_died", player_id)
	
	# Esperar y eliminar
	await get_tree().create_timer(2.0).timeout
	queue_free()

# =============================================
# FUNCIONES DE ENERGÍA
# =============================================
func drain_energy(amount: int):
	current_energy = max(0, current_energy - amount)
	if ui:
		ui.update_energy(current_energy, max_energy)
	
	if current_energy <= 0:
		flashlight_on = false
		_update_flashlight_visibility()
		print("🔋 [J", player_id, "] Energía agotada")

func recharge_energy(amount: int):
	current_energy = min(max_energy, current_energy + amount)
	if ui:
		ui.update_energy(current_energy, max_energy)
	print("🔋 [J", player_id, "] Energía recargada: ", current_energy, "/", max_energy)

# =============================================
func heal(amount: int):
	current_health = min(max_health, current_health + amount)
	if ui:
		ui.update_health(current_health, max_health)

# =============================================
# POWER-UP: MECHA
# =============================================
func activate_mecha(duration: float, scale_factor: float, speed_mult: float, fire_rate_mult: float):
	# Si ya está activo, reiniciar el timer
	if is_mecha_active and mecha_timer_node:
		mecha_timer_node.start(duration)
		return
	
	is_mecha_active = true
	
	# Guardar valores originales
	original_speed = speed
	original_shoot_cooldown = shoot_cooldown
	if model_node:
		original_model_scale = model_node.scale
	
	# Aplicar buffs
	speed *= speed_mult
	shoot_cooldown *= fire_rate_mult
	if model_node:
		model_node.scale *= scale_factor
	
	# Efecto visual: tinte dorado en los materiales
	_set_powerup_color(Color(1.0, 0.85, 0.2))
	
	print("🤖 [J", player_id, "] MECHA activado (", duration, "s)")
	
	# Crear Timer para revertir
	mecha_timer_node = Timer.new()
	mecha_timer_node.one_shot = true
	mecha_timer_node.wait_time = duration
	add_child(mecha_timer_node)
	mecha_timer_node.timeout.connect(_deactivate_mecha)
	mecha_timer_node.start()

func _deactivate_mecha():
	is_mecha_active = false
	
	# Restaurar valores originales
	speed = original_speed
	shoot_cooldown = original_shoot_cooldown
	if model_node:
		model_node.scale = original_model_scale
	
	# Restaurar color original
	_restore_original_materials()
	
	# Limpiar timer
	if mecha_timer_node:
		mecha_timer_node.queue_free()
		mecha_timer_node = null
	
	print("🤖 [J", player_id, "] MECHA desactivado")

# =============================================
# POWER-UP: THUNDERBOLT
# =============================================
func activate_thunderbolt(pulses: int, interval: float, aoe_radius: float, damage: int):
	if is_thunderbolt_active:
		return  # No se acumula
	
	is_thunderbolt_active = true
	print("⚡ [J", player_id, "] THUNDERBOLT activado")
	
	for i in range(pulses):
		_spawn_thunder_aoe(aoe_radius, damage)
		if i < pulses - 1:
			await get_tree().create_timer(interval).timeout
	
	is_thunderbolt_active = false
	print("⚡ [J", player_id, "] THUNDERBOLT finalizado")

func _spawn_thunder_aoe(radius: float, damage: int):
	# Crear un Area3D temporal centrada en la posición actual del jugador
	var aoe = Area3D.new()
	var shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	aoe.add_child(shape)
	
	# Añadir al nivel (no al jugador, para que no se mueva con él)
	get_parent().add_child(aoe)
	aoe.global_position = global_position
	
	# Configurar capas de colisión (detectar enemigos en layer 1 por defecto)
	aoe.collision_layer = 0
	aoe.collision_mask = 1  # Layer por defecto donde están los enemigos
	aoe.monitoring = true
	
	# Efecto visual: luz eléctrica
	var light = OmniLight3D.new()
	light.light_color = Color(0.3, 0.7, 1.0)
	light.light_energy = 8.0
	light.omni_range = radius * 1.5
	aoe.add_child(light)
	
	# Esperar 2 frames para que el Area3D detecte cuerpos correctamente
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	# Dañar a todos los enemigos dentro del área
	var bodies = aoe.get_overlapping_bodies()
	for body in bodies:
		if body.has_method("take_damage") and not body.is_in_group("players"):
			body.take_damage(damage)
			print("⚡ [J", player_id, "] Descarga impacta a: ", body.name)
	
	# Desvanecer la luz y destruir
	var tween = get_tree().create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.4)
	await tween.finished
	aoe.queue_free()

# =============================================
# UTILIDADES DE MATERIALES
# =============================================
func _set_powerup_color(color: Color):
	_update_materials()

func _restore_original_materials():
	_update_materials()

func _update_materials():
	if not model_node:
		return
		
	var meshes = []
	_find_all_meshes(model_node, meshes)
	
	for mesh_instance in meshes:
		if not mesh_instance.mesh:
			continue
			
		var surface_count = mesh_instance.mesh.get_surface_count()
		for i in range(surface_count):
			var original_mat = null
			if original_surface_materials.has(mesh_instance) and i < original_surface_materials[mesh_instance].size():
				original_mat = original_surface_materials[mesh_instance][i]
				
			if original_mat and original_mat is StandardMaterial3D:
				var target_color : Color = Color(1,1,1,1)
				var use_override = false
				
				if is_invincible:
					target_color = Color(1, 0.3, 0.3)
					use_override = true
				elif is_dashing:
					target_color = Color(1, 1, 0.5)
					use_override = true
				elif is_mecha_active:
					target_color = Color(1.0, 0.85, 0.2)
					use_override = true
					
				if use_override:
					var tinted = original_mat.duplicate(true)
					tinted.albedo_color = target_color
					mesh_instance.set_surface_override_material(i, tinted)
				else:
					mesh_instance.set_surface_override_material(i, original_mat)

func _find_all_meshes(node: Node, result: Array):
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_find_all_meshes(child, result)
