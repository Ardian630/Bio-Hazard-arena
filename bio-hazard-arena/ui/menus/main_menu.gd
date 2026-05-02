extends Control

@onready var start_button = $StartButton
@onready var quit_button = $QuitButton
var music : AudioStreamPlayer

func _ready():
	music = AudioStreamPlayer.new()
	add_child(music)
	music.stream = preload("res://assets/audios/sounds/Ravana_pour_une_infante_defunte.mp3")
	music.play()
	# Conectar señales de los botones
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	# Opcional: animación de entrada
	modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5)

func _on_start_pressed():
	print("🎮 Iniciando juego...")
	
	# Animación de salida
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3)
	await tween.finished
	
	# Cambiar a la escena del juego
	get_tree().change_scene_to_file("res://systems/main.tscn")

func _on_quit_pressed():
	print("👋 Saliendo del juego...")
	get_tree().quit()
