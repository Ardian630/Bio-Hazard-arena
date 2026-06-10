extends Node3D

@onready var player1 : CharacterBody3D = $Player1
@onready var player2 : CharacterBody3D = $Player2
# @onready var camera  : Camera3D = $TopDownCamera
@onready var camera = $TopDownCamera
@onready var ui_p1   : Control = $UI_P1
@onready var ui_p2   : Control = $UI_P2

var alive_players : int = 1

func _ready():
	# ── Configurar Música de Fondo ──
	var music = AudioStreamPlayer.new()
	music.name = "BackgroundMusic"
	music.stream = preload("res://assets/audios/sounds/music/music_gameplay.mp3")
	music.bus = "Music"
	add_child(music)
	music.play()
	
	# ── Configurar Jugador 1 (siempre presente) ──
	player1.player_id = 1
	player1.ui = ui_p1
	player1.player_died.connect(_on_player_died)
	
	# ── Leer modo de juego desde el Autoload ──
	if GameManager.is_multiplayer:
		# ── Configurar Jugador 2 ──
		alive_players = 2
		player2.player_id = 2
		player2.ui = ui_p2
		if ui_p2.has_method("flip_to_right"):
			ui_p2.flip_to_right()
		player2.player_died.connect(_on_player_died)
		
		# Spawn cooperativo: J2 aparece junto a J1
		player2.global_position = player1.global_position + Vector3(2, 0, 0)
		
		# Cámara sigue a ambos
		if camera.get_script():
			var t: Array[Node3D] = [player1, player2]
			camera.targets = t
	else:
		# ── Modo solitario: destruir J2 y su UI ──
		player2.queue_free()
		ui_p2.queue_free()
		
		# Cámara solo sigue a J1
		if camera.get_script():
			var t: Array[Node3D] = [player1]
			camera.targets = t

	# Conectar victoria
	var wave_manager = $WaveManager
	if wave_manager:
		wave_manager.all_waves_completed.connect(_show_victory_screen)

	# Siempre preguntar si se quiere ver el tutorial al iniciar
	_ask_tutorial()

func _ask_tutorial():
	get_tree().paused = true
	var prompt = ConfirmationDialog.new()
	prompt.title = "Bienvenido a Bio-Hazard Arena"
	prompt.dialog_text = "¿Es tu primera vez jugando?"
	prompt.get_ok_button().text = "Sí, ver tutorial"
	prompt.get_cancel_button().text = "No, ya sé jugar"
	prompt.process_mode = PROCESS_MODE_ALWAYS
	
	prompt.confirmed.connect(func():
		var tutorial_scene = load("res://ui/menus/tutorial_screen.tscn")
		if tutorial_scene:
			var instance = tutorial_scene.instantiate()
			add_child(instance)
		prompt.queue_free()
	)
	
	prompt.canceled.connect(func():
		get_tree().paused = false
		prompt.queue_free()
	)
	
	add_child(prompt)
	prompt.popup_centered()

func _input(event):
	if event.is_action_pressed("pause") and not get_tree().paused:
		var pause_scene = load("res://ui/menus/pause_menu.tscn")
		if pause_scene:
			var pm = pause_scene.instantiate()
			add_child(pm)

func _on_player_died(id: int):
	alive_players -= 1
	print("💀 Jugador ", id, " eliminado. Vivos: ", alive_players)
	
	if alive_players <= 0:
		_show_game_over_screen()

func _show_game_over_screen():
	# Detener música de fondo
	var music = get_node_or_null("BackgroundMusic")
	if music:
		music.stop()
		
	var game_over_scene = get_node_or_null("GameOverScreen")
	if game_over_scene and game_over_scene.has_method("show_game_over"):
		game_over_scene.show_game_over()
	else:
		var go_scene = preload("res://ui/menus/game_over_screen.tscn")
		var go = go_scene.instantiate()
		add_child(go)
		go.show_game_over()

func _show_victory_screen():
	# Detener música de fondo
	var music = get_node_or_null("BackgroundMusic")
	if music:
		music.stop()
		
	var game_over_scene = get_node_or_null("GameOverScreen")
	if game_over_scene and game_over_scene.has_method("show_victory"):
		game_over_scene.show_victory()
	else:
		var go_scene = preload("res://ui/menus/game_over_screen.tscn")
		var go = go_scene.instantiate()
		add_child(go)
		go.show_victory()
