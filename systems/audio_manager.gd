extends Node

var sfx_dict = {
	"dash": preload("res://assets/audios/sounds/sfx/sfx_dash.mp3"),
	"enemy_death": preload("res://assets/audios/sounds/sfx/sfx_enemy_death.mp3"),
	"enemy_hurt": preload("res://assets/audios/sounds/sfx/sfx_enemy_hurt.mp3"),
	"flashlight_off": preload("res://assets/audios/sounds/sfx/sfx_flashlight_off.mp3"),
	"flashlight_on": preload("res://assets/audios/sounds/sfx/sfx_flashlight_on.mp3"),
	"pickup_energy": preload("res://assets/audios/sounds/sfx/sfx_pickup_energy.mp3"),
	"pickup_health": preload("res://assets/audios/sounds/sfx/sfx_pickup_health.mp3"),
	"pickup_mecha": preload("res://assets/audios/sounds/sfx/sfx_pickup_mecha.mp3"),
	"pickup_thunderbolt": preload("res://assets/audios/sounds/sfx/sfx_pickup_thunderbolt.mp3"),
	"player_death": preload("res://assets/audios/sounds/sfx/sfx_player_death.mp3"),
	"player_hurt": preload("res://assets/audios/sounds/sfx/sfx_player_hurt.mp3"),
	"shoot": preload("res://assets/audios/sounds/sfx/sfx_shoot.mp3"),
	"ui_click": preload("res://assets/audios/sounds/sfx/sfx_ui_click.mp3"),
	"ui_hover": preload("res://assets/audios/sounds/sfx/sfx_ui_hover.mp3"),
	"wave_complete": preload("res://assets/audios/sounds/sfx/sfx_wave_complete.mp3"),
	"wave_start": preload("res://assets/audios/sounds/sfx/sfx_wave_start.mp3")
}

var sfx_pool = []
var max_pool_size = 20

func _ready():
	process_mode = PROCESS_MODE_ALWAYS # SFX might play during pause (like UI)
	
	for i in range(max_pool_size):
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_pool.append(p)

func play_sfx(sfx_name: String):
	if not sfx_dict.has(sfx_name):
		print("❌ SFX no encontrado: ", sfx_name)
		return
	
	for p in sfx_pool:
		if not p.playing:
			_configure_and_play(p, sfx_name)
			return
			
	# Si todos están ocupados, reutilizar el primero
	_configure_and_play(sfx_pool[0], sfx_name)

func _configure_and_play(p: AudioStreamPlayer, sfx_name: String):
	p.stream = sfx_dict[sfx_name]
	
	# Ajustes personalizados
	if sfx_name == "wave_start":
		p.volume_db = -15.0 # Volumen bajo para no ensordecer
	elif sfx_name == "enemy_hurt":
		p.volume_db = -10.0 # Bajar un poco el daño de enemigo
	else:
		p.volume_db = 0.0
		
	p.play()
	
	# Limitar el sonido de inicio de partida/horda con desvanecimiento rápido
	if sfx_name == "wave_start":
		var tween = get_tree().create_tween()
		tween.tween_property(p, "volume_db", -80.0, 1.5)
		tween.finished.connect(func():
			if is_instance_valid(p) and p.stream == sfx_dict["wave_start"]:
				p.stop()
		)

# ── SISTEMA DE SONIDOS PARA UI ──
func setup_ui_sounds(node: Node):
	for child in node.get_children():
		if child is Button:
			# Conectar solo si no está conectado ya para evitar sonidos duplicados
			if not child.mouse_entered.is_connected(_on_button_hover):
				child.mouse_entered.connect(_on_button_hover)
			if not child.pressed.is_connected(_on_button_click):
				child.pressed.connect(_on_button_click)
		
		# Buscar recursivamente en los hijos
		if child.get_child_count() > 0:
			setup_ui_sounds(child)

func _on_button_hover():
	play_sfx("ui_hover")

func _on_button_click():
	play_sfx("ui_click")
