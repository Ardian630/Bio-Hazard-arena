extends CanvasLayer

@onready var texture_rect = $Panel/TextureRect
@onready var btn_next = $Panel/BtnSiguiente
@onready var btn_close = $Panel/BtnCerrar

var images = [
	preload("res://assets/2d/Buttons/Movimiento.png"),
	preload("res://assets/2d/Buttons/Linterna.png"),
	preload("res://assets/2d/Buttons/Dash.png"),
	preload("res://assets/2d/Buttons/Disparar.png")
]
var current_slide = 0

func _ready():
	process_mode = PROCESS_MODE_ALWAYS
	get_tree().paused = true
	
	if btn_next:
		btn_next.pressed.connect(_on_next)
	if btn_close:
		btn_close.pressed.connect(_on_close)
		
	AudioManager.setup_ui_sounds(self)
	_update_slide()

func _update_slide():
	texture_rect.texture = images[current_slide]
	
	if current_slide == images.size() - 1:
		btn_next.hide()
		btn_close.show()
	else:
		btn_next.show()
		btn_close.hide()

func _on_next():
	current_slide += 1
	_update_slide()

func _on_close():
	GameManager.tutorial_seen = true
	GameManager.save_settings()
	get_tree().paused = false
	queue_free()
