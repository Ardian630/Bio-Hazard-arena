extends CharacterBody3D

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
@export var bullet_max_range : float = 20.0
@export var muzzle_flash_scene : PackedScene

# Nodos --------------------------------------------------------------------
# @onready var model_node : Node3D = $Blitz
# --------------------------------------------------------------------------
@export var model_node : Node3D
@onready var muzzle : Node3D = $Muzzle
@onready var camera : Camera3D = get_viewport().get_camera_3d()
@onready var flashlight_node : SpotLight3D = $Flashlight
@onready var ui : Control = get_node("/root/Main/UI")

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

# Diccionario para materiales originales
var original_surface_materials : Dictionary = {}

func _ready():
	# Guardar materiales originales
	_save_original_materials()
	
	# Mostrar configuración de energía
	print("🔋 Flashlight Energy Drain = ", flashlight_energy_drain)
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
		print("❌ ERROR: Nodo Muzzle no encontrado")
	if not flashlight_node:
		print("❌ ERROR: Nodo Flashlight no encontrado")
	if not bullet_scene:
		print("❌ ERROR: Bullet Scene no asignada")

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
				var mat = mesh_instance.mesh.surface_get_material(i)
				if mat:
					surface_materials.append(mat.duplicate(true))
				else:
					surface_materials.append(null)
			
			original_surface_materials[mesh_instance] = surface_materials

func _physics_process(delta):
	# MOVIMIENTO (solo si no está dashando)
	if not is_dashing:
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		velocity.x = input_dir.x * speed
		velocity.z = input_dir.y * speed
	else:
		# Durante el dash, mantener velocidad constante
		velocity = dash_direction * dash_speed
	
	move_and_slide()
	
	# ROTACIÓN HACIA EL RATÓN (solo si no está dashando)
	if not is_dashing:
		_rotate_towards_mouse(delta)
	
	# =============================================
	# DASH (tecla Shift)
	# =============================================
	if Input.is_action_just_pressed("Dash") and can_dash and not is_dashing and current_energy >= dash_energy_cost:
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
			print("🔋 Sin energía - linterna apagada")
	
	# =============================================
	# CONTROL DE LINTERNA (tecla F)
	# =============================================
	if Input.is_action_just_pressed("toggle_flashlight") and not is_dashing:
		if current_energy > 0:
			flashlight_on = not flashlight_on
			_update_flashlight_visibility()
			print("🔦 Linterna: ", "ON" if flashlight_on else "OFF")
		else:
			print("🔋 Sin energía - no puedes encender la linterna")
	
	# =============================================
	# DISPARO (clic izquierdo)
	# =============================================
	if Input.is_action_just_pressed("shoot") and not is_dashing:
		if current_energy >= shoot_energy_cost:
			shoot()
		else:
			print("🔋 Sin energía - no puedes disparar")
	
	# =============================================
	# TECLAS DE PRUEBA
	# =============================================
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

func _rotate_towards_mouse(delta):
	if not camera:
		camera = get_viewport().get_camera_3d()
		return
	
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
			rotation.y = lerp_angle(rotation.y, target_y, rotation_speed * delta)

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
	
	# Obtener punto del ratón en el mundo
	var mouse_pos_2d = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos_2d)
	var ray_dir = camera.project_ray_normal(mouse_pos_2d)
	
	var denom = ray_dir.y
	if abs(denom) < 0.001:
		return
	
	var t = -from.y / denom
	var mouse_world_pos = from + ray_dir * t
	
	# Calcular dirección desde el muzzle al ratón
	var shoot_dir = (mouse_world_pos - muzzle.global_position).normalized()
	shoot_dir.y = 0
	
	# Instanciar bala ¡X! Descontinuado
	# var bullet = bullet_scene.instantiate()
	# get_parent().add_child(bullet)
	
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
		print("⚡ Sin energía para dash")
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
	
	print("⚡ Dash! Energía restante: ", current_energy)

func _end_dash():
	is_dashing = false
	
	# Restaurar colores originales
	_set_dash_color(false)
	
	# Pequeño impulso residual
	velocity = dash_direction * (dash_speed * 0.2)
	
	print("⚡ Dash terminado")

# Función auxiliar para cambiar color durante el dash
func _set_dash_color(is_dashing_active: bool):
	if not model_node:
		return
	
	var meshes = []
	_find_all_meshes(model_node, meshes)
	
	for mesh_instance in meshes:
		if not mesh_instance.mesh:
			continue
		
		var surface_count = mesh_instance.mesh.get_surface_count()
		
		if is_dashing_active:
			# Cambiar a color amarillo durante el dash
			for i in range(surface_count):
				var original_mat = null
				if original_surface_materials.has(mesh_instance) and i < original_surface_materials[mesh_instance].size():
					original_mat = original_surface_materials[mesh_instance][i]
				
				if original_mat and original_mat is StandardMaterial3D:
					var dash_mat = original_mat.duplicate(true)
					dash_mat.albedo_color = Color(1, 1, 0.5)  # Amarillo
					mesh_instance.mesh.surface_set_material(i, dash_mat)
		else:
			# Restaurar materiales originales
			if original_surface_materials.has(mesh_instance):
				for i in range(surface_count):
					if i < original_surface_materials[mesh_instance].size():
						var original_mat = original_surface_materials[mesh_instance][i]
						if original_mat:
							mesh_instance.mesh.surface_set_material(i, original_mat)

# =============================================
# FUNCIONES DE VIDA Y DAÑO
# =============================================
func take_damage(amount: int):
	if is_invincible:
		return
	
	current_health = max(0, current_health - amount)
	print("💥 Daño: ", current_health, "/", max_health)
	
	if ui:
		ui.update_health(current_health, max_health)
	
	if current_health <= 0:
		die()
		return
	
	is_invincible = true
	_set_damage_effect(true)
	
	await get_tree().create_timer(invincibility_time).timeout
	
	if is_invincible and current_health > 0:
		is_invincible = false
		_set_damage_effect(false)

func _set_damage_effect(is_damaged: bool):
	if not model_node:
		return
	
	var meshes = []
	_find_all_meshes(model_node, meshes)
	
	for mesh_instance in meshes:
		if not mesh_instance.mesh:
			continue
		
		var surface_count = mesh_instance.mesh.get_surface_count()
		
		if is_damaged:
			for i in range(surface_count):
				var original_mat = null
				if original_surface_materials.has(mesh_instance) and i < original_surface_materials[mesh_instance].size():
					original_mat = original_surface_materials[mesh_instance][i]
				
				if original_mat and original_mat is StandardMaterial3D:
					var tinted = original_mat.duplicate(true)
					tinted.albedo_color = Color(1, 0.3, 0.3)
					mesh_instance.mesh.surface_set_material(i, tinted)
		else:
			if original_surface_materials.has(mesh_instance):
				for i in range(surface_count):
					if i < original_surface_materials[mesh_instance].size():
						var original_mat = original_surface_materials[mesh_instance][i]
						if original_mat:
							mesh_instance.mesh.surface_set_material(i, original_mat)

func die():
	print("💀 Jugador muerto")
	
	# Rotar a horizontal
	var current_y_rotation = rotation_degrees.y
	rotation_degrees = Vector3(90, current_y_rotation, 0)
	global_position.y += 0.5
	
	# Desactivar físicas
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	
	# 🔹 MOSTRAR PANTALLA DE GAME OVER
	_show_game_over_screen()
	
	# Esperar y eliminar (opcional, puedes mantener el cuerpo)
	await get_tree().create_timer(2.0).timeout
	queue_free()

func _show_game_over_screen():
	# Buscar la escena de game over
	var game_over = get_node("/root/Main/GameOverScreen")
	if not game_over:
		# Si no existe, crearla
		var game_over_scene = preload("res://ui/menus/game_over_screen.tscn")
		game_over = game_over_scene.instantiate()
		get_node("/root/Main").add_child(game_over)
	
	# Mostrar la pantalla
	game_over.show_game_over()

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
		print("🔋 Energía agotada")

func recharge_energy(amount: int):
	current_energy = min(max_energy, current_energy + amount)
	if ui:
		ui.update_energy(current_energy, max_energy)
	print("🔋 Energía recargada: ", current_energy, "/", max_energy)

# =============================================
func heal(amount: int):
	current_health = min(max_health, current_health + amount)
	if ui:
		ui.update_health(current_health, max_health)

func _find_all_meshes(node: Node, result: Array):
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_find_all_meshes(child, result)
