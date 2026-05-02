extends Control

@onready var game_over_image = $GameOverImage

func _ready():
	# Ocultar todo al inicio
	hide()

func show_game_over():
	# Mostrar la pantalla
	show()
	
	# Opcional: animación de aparición
	modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5)

func _process(delta):
	# Detectar tecla R para reiniciar
	if visible and Input.is_key_pressed(KEY_R):
		get_tree().reload_current_scene()
