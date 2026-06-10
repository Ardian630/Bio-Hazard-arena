extends Control

@onready var start_button = $StartButton
@onready var multiplayer_button = $MultiplayerButton
@onready var quit_button = $QuitButton
@onready var settings_button = $SettingsButton
var music : AudioStreamPlayer

func _ready():
	# Cargar ajustes al iniciar la pantalla
	GameManager.load_settings()
	
	music = AudioStreamPlayer.new()
	add_child(music)
	music.stream = preload("res://assets/audios/sounds/Ravana_pour_une_infante_defunte.mp3")
	music.bus = "Music"
	music.play()
	
	AudioManager.setup_ui_sounds(self)
	# Conectar señales de los botones
	start_button.pressed.connect(_on_start_pressed)
	multiplayer_button.pressed.connect(_on_multiplayer_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	# Opcional: animación de entrada
	modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5)

func _on_start_pressed():
	print("🎮 Iniciando juego en modo SOLITARIO...")
	GameManager.is_multiplayer = false
	_go_to_game()

func _on_multiplayer_pressed():
	print("🎮 Iniciando juego en modo MULTIJUGADOR...")
	GameManager.is_multiplayer = true
	_go_to_game()

func _on_quit_pressed():
	print("👋 Saliendo del juego...")
	get_tree().quit()

func _go_to_game():
	# Animación de salida
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3)
	await tween.finished
	
	# Cambiar a la escena del juego
	get_tree().change_scene_to_file("res://systems/main.tscn")

func _on_settings_pressed():
	print("⚙️ Abriendo Ajustes...")
	var settings_scene = load("res://ui/menus/settings_menu.tscn")
	if settings_scene:
		var instance = settings_scene.instantiate()
		add_child(instance)
