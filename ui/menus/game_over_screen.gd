extends Control

@onready var game_over_image = $GameOverImage
@onready var lbl_horda = $Panel/VBox/LblHorda
@onready var lbl_time = $Panel/VBox/LblTime
@onready var btn_restart = $Panel/VBox/BtnRestart
@onready var btn_main_menu = $Panel/VBox/BtnMainMenu

func _ready():
	hide()
	process_mode = PROCESS_MODE_ALWAYS
	
	# Si la UI no se ha inicializado correctamente aún (en editor), evitamos error
	if btn_restart:
		btn_restart.pressed.connect(_on_restart)
	if btn_main_menu:
		btn_main_menu.pressed.connect(_on_main_menu)
		
	AudioManager.setup_ui_sounds(self)

func show_game_over():
	# Obtener estadísticas del WaveManager
	var wave_manager = get_tree().root.get_node_or_null("Main/WaveManager")
	if wave_manager:
		lbl_horda.text = "Horda alcanzada: " + str(wave_manager.current_wave)
		var mins = int(wave_manager.game_timer) / 60
		var secs = int(wave_manager.game_timer) % 60
		lbl_time.text = "Tiempo sobrevivido: %02d:%02d" % [mins, secs]
	else:
		lbl_horda.text = "Horda alcanzada: ?"
		lbl_time.text = "Tiempo sobrevivido: --:--"
	
	# Pausar el juego para que no haya más daños o sonidos
	get_tree().paused = true
	
	show()
	modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5)

func show_victory():
	var wave_manager = get_tree().root.get_node_or_null("Main/WaveManager")
	if wave_manager:
		lbl_horda.text = "¡Sobreviviste a las " + str(wave_manager.max_waves) + " hordas!"
		var mins = int(wave_manager.game_timer) / 60
		var secs = int(wave_manager.game_timer) % 60
		lbl_time.text = "Tiempo final: %02d:%02d" % [mins, secs]
	else:
		lbl_horda.text = "¡Sobreviviste a todas las hordas!"
		lbl_time.text = ""
		
	if game_over_image:
		game_over_image.hide()
		
	var bg = $ColorRect
	if bg:
		bg.color = Color(0, 0.2, 0, 0.85) # Tinte verde oscuro de victoria
		
	if btn_restart:
		btn_restart.text = "Jugar de Nuevo"
		
	get_tree().paused = true
	show()
	modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5)

func _on_restart():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/menus/main_menu.tscn")
