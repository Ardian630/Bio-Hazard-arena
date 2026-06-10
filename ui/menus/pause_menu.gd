extends CanvasLayer

@onready var btn_continue = $Panel/VBoxContainer/BtnContinue
@onready var btn_settings = $Panel/VBoxContainer/BtnSettings
@onready var btn_restart = $Panel/VBoxContainer/BtnRestart
@onready var btn_main_menu = $Panel/VBoxContainer/BtnMainMenu

func _ready():
	get_tree().paused = true
	btn_continue.pressed.connect(_on_continue)
	btn_restart.pressed.connect(_on_restart)
	btn_main_menu.pressed.connect(_on_main_menu)
	
	AudioManager.setup_ui_sounds(self)

func _input(event):
	if event.is_action_pressed("pause"):
		_on_continue()
		get_viewport().set_input_as_handled()

func _on_continue():
	get_tree().paused = false
	queue_free()

func _on_settings():
	var settings = load("res://ui/menus/settings_menu.tscn").instantiate()
	add_child(settings)

func _on_restart():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/menus/main_menu.tscn")
