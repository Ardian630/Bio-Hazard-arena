extends Node3D

# Señales
signal wave_started(wave_number)
signal wave_completed(wave_number)
signal all_waves_completed

# Variables exportadas
@export var enemy_scene : PackedScene  # Arrastra enemy.tscn aquí
@export var initial_wave : int = 1
@export var max_waves : int = 3
@export var enemies_per_wave : int = 5  # Enemigos base por horda
@export var wave_increase : int = 2  # Enemigos adicionales por horda
@export var spawn_delay : float = 1.0  # Segundos entre cada enemigo
@export var wave_delay : float = 5.0  # Segundos entre hordas
@export var spawn_area_size : Vector2 = Vector2(30, 30)  # Área de aparición

# Variables internas
var current_wave : int = 1
var enemies_in_current_wave : int = 0
var enemies_spawned : int = 0
var enemies_alive : int = 0
var is_spawning : bool = false
var is_wave_active : bool = false
var game_timer : float = 0.0
var wave_timer : float = 0.0

# Referencias — soporta múltiples jugadores
var players : Array[Node3D] = []
@onready var ui = get_node_or_null("/root/Main/UI_P1")

func _ready():
	# Buscar ambos jugadores
	var p1 = get_node_or_null("/root/Main/Player1")
	var p2 = get_node_or_null("/root/Main/Player2")
	if p1: players.append(p1)
	if p2: players.append(p2)
	
	# Iniciar primera horda después de 3 segundos
	await get_tree().create_timer(3.0).timeout
	start_next_wave()

func _process(delta):
	# Actualizar temporizador de partida
	game_timer += delta
	if ui:
		ui.update_timer(int(game_timer))
	
	# Gestionar tiempo entre hordas
	if not is_wave_active and not is_spawning and current_wave <= max_waves:
		wave_timer += delta
		if wave_timer >= wave_delay:
			wave_timer = 0
			start_next_wave()
	
	# Verificar si la horda está completa
	if is_wave_active and enemies_alive <= 0 and enemies_spawned >= enemies_in_current_wave:
		_complete_wave()

func start_next_wave():
	if current_wave > max_waves:
		emit_signal("all_waves_completed")
		print("🎉 ¡TODAS LAS HORDAS COMPLETADAS! 🎉")
		return
	
	# === CAMBIO AQUÍ: Primero esperamos a que termine el tiempo de intro ===
	# Solo esperar el fadeout completo en la primera horda
	if current_wave == 1:
		await get_tree().create_timer(3.0).timeout
	else:
		await get_tree().create_timer(0.5).timeout
	
	# === CAMBIO AQUÍ: Ahora que terminó el tiempo de espera, activamos la horda ===
	is_wave_active = true
	is_spawning = true
	
	# Calcular enemigos para esta horda
	enemies_in_current_wave = enemies_per_wave + (current_wave - 1) * wave_increase
	enemies_spawned = 0
	enemies_alive = 0
	
	# Actualizar UI
	if ui:
		ui.update_wave(current_wave, max_waves)
	
	print("🌊 HORDA ", current_wave, " - Enemigos: ", enemies_in_current_wave)
	
	# Reproducir sonido épico
	AudioManager.play_sfx("wave_start")
	
	# Empezar a spawnear enemigos directamente
	_spawn_enemies()

func _spawn_enemies():
	for i in range(enemies_in_current_wave):
		_spawn_single_enemy()
		await get_tree().create_timer(spawn_delay).timeout
	
	is_spawning = false
	print("✅ Todos los enemigos de la horda ", current_wave, " han aparecido")

func _spawn_single_enemy():
	if not enemy_scene:
		print("❌ Enemy scene no asignada")
		return
	
	var enemy = enemy_scene.instantiate()
	
	# Posición aleatoria dentro del área de spawn
	var random_x = randf_range(-spawn_area_size.x / 2, spawn_area_size.x / 2)
	var random_z = randf_range(-spawn_area_size.y / 2, spawn_area_size.y / 2)
	
	# Asegurar que no aparezca demasiado cerca de CUALQUIER jugador
	var spawn_position = Vector3(random_x, 0.5, random_z)
	var max_attempts = 20
	var attempt = 0
	var too_close = true
	while too_close and attempt < max_attempts:
		too_close = false
		for p in players:
			if is_instance_valid(p) and spawn_position.distance_to(p.global_position) < 5.0:
				too_close = true
				break
		if too_close:
			random_x = randf_range(-spawn_area_size.x / 2, spawn_area_size.x / 2)
			random_z = randf_range(-spawn_area_size.y / 2, spawn_area_size.y / 2)
			spawn_position = Vector3(random_x, 0.5, random_z)
		attempt += 1
	
	# Aumentar dificultad del enemigo según la horda
	if enemy.has_method("set_wave_difficulty"):
		enemy.set_wave_difficulty(current_wave)
	
	add_child(enemy)
	
	enemy.global_position = spawn_position
	
	enemies_spawned += 1
	enemies_alive += 1
	
	# Actualizar UI de enemigos restantes
	if ui:
		ui.update_enemies_left(enemies_alive)
	
	# Conectar señal de muerte
	enemy.connect("died", _on_enemy_died)

func _on_enemy_died():
	enemies_alive -= 1
	if ui:
		ui.update_enemies_left(enemies_alive)
	print("💀 Enemigo muerto - Restantes: ", enemies_alive)

func _complete_wave():
	is_wave_active = false
	print("🏆 HORDA ", current_wave, " COMPLETADA!")
	AudioManager.play_sfx("wave_complete")
	emit_signal("wave_completed", current_wave)
	
	# Pequeña recompensa al completar horda — curar a TODOS los jugadores vivos
	for p in players:
		if is_instance_valid(p) and p.has_method("heal"):
			p.heal(10)
	
	current_wave += 1
	
	if current_wave <= max_waves:
		print("⏳ Siguiente horda en ", wave_delay, " segundos")
	else:
		print("🎉 ¡VICTORIA! Completaste todas las hordas")
		emit_signal("all_waves_completed")

# Función para reiniciar el sistema de hordas
func reset_wave_system():
	current_wave = initial_wave
	enemies_alive = 0
	enemies_spawned = 0
	is_spawning = false
	is_wave_active = false
	game_timer = 0.0
	wave_timer = 0.0
	
	# Limpiar enemigos existentes
	for child in get_children():
		if child.name == "Enemy" or child.has_method("take_damage"):
			child.queue_free()
	
	if ui:
		ui.update_wave(current_wave, max_waves)
		ui.update_timer(0)
		ui.update_enemies_left(0)
	
	# Reiniciar referencias de jugadores
	players.clear()
	var p1 = get_node_or_null("/root/Main/Player1")
	var p2 = get_node_or_null("/root/Main/Player2")
	if p1: players.append(p1)
	if p2: players.append(p2)
	
	# Iniciar de nuevo
	await get_tree().create_timer(2.0).timeout
	start_next_wave()
