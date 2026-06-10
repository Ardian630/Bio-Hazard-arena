extends Node

const SETTINGS_PATH = "user://settings.cfg"

# Gestor global de estado del juego (registrar como Autoload)
var is_multiplayer : bool = false

# --- Configuración de Dispositivos ---
var p1_device : String = "keyboard" # "keyboard" o "gamepad"
var p2_device : String = "keyboard" # "keyboard" o "gamepad"

# --- Configuración de Audio ---
var master_volume : float = 0.8
var music_volume : float = 0.8
var sfx_volume : float = 0.8

# --- Configuración de Controles ---
var mouse_sensitivity : float = 0.5
var stick_sensitivity : float = 0.5

# --- Configuración de Gráficos ---
var window_mode : int = 0 # 0=Windowed, 1=Fullscreen, 2=Borderless
var vsync_enabled : bool = true
var resolution : Vector2i = Vector2i(1280, 720)
var brightness : float = 1.0

# --- Estado del Juego ---
var tutorial_seen : bool = false

func _ready():
	load_settings()

func reset_to_defaults():
	p1_device = "keyboard"
	p2_device = "keyboard"
	master_volume = 0.8
	music_volume = 0.8
	sfx_volume = 0.8
	mouse_sensitivity = 0.5
	stick_sensitivity = 0.5
	window_mode = 0
	vsync_enabled = true
	resolution = Vector2i(1280, 720)
	brightness = 1.0
	save_settings()
	apply_all_settings()

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	if err != OK:
		reset_to_defaults()
		return

	p1_device = config.get_value("Controls", "p1_device", "keyboard")
	p2_device = config.get_value("Controls", "p2_device", "keyboard")
	mouse_sensitivity = config.get_value("Controls", "mouse_sensitivity", 0.5)
	stick_sensitivity = config.get_value("Controls", "stick_sensitivity", 0.5)

	master_volume = config.get_value("Audio", "master_volume", 0.8)
	music_volume = config.get_value("Audio", "music_volume", 0.8)
	sfx_volume = config.get_value("Audio", "sfx_volume", 0.8)

	window_mode = config.get_value("Graphics", "window_mode", 0)
	vsync_enabled = config.get_value("Graphics", "vsync_enabled", true)
	resolution = config.get_value("Graphics", "resolution", Vector2i(1280, 720))
	brightness = config.get_value("Graphics", "brightness", 1.0)

	tutorial_seen = config.get_value("Game", "tutorial_seen", false)

	apply_all_settings()

func save_settings():
	var config = ConfigFile.new()
	config.set_value("Controls", "p1_device", p1_device)
	config.set_value("Controls", "p2_device", p2_device)
	config.set_value("Controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("Controls", "stick_sensitivity", stick_sensitivity)

	config.set_value("Audio", "master_volume", master_volume)
	config.set_value("Audio", "music_volume", music_volume)
	config.set_value("Audio", "sfx_volume", sfx_volume)

	config.set_value("Graphics", "window_mode", window_mode)
	config.set_value("Graphics", "vsync_enabled", vsync_enabled)
	config.set_value("Graphics", "resolution", resolution)
	config.set_value("Graphics", "brightness", brightness)

	config.set_value("Game", "tutorial_seen", tutorial_seen)

	config.save(SETTINGS_PATH)
	apply_all_settings()

func apply_all_settings():
	apply_audio_settings()
	apply_graphics_settings()

func apply_audio_settings():
	var master_bus = AudioServer.get_bus_index("Master")
	var music_bus = AudioServer.get_bus_index("Music")
	var sfx_bus = AudioServer.get_bus_index("SFX")

	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(master_volume))
	if music_bus >= 0:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(music_volume))
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(sfx_volume))

func apply_graphics_settings():
	call_deferred("_apply_graphics_deferred")

func _apply_graphics_deferred():
	var win = get_tree().root
	if not win:
		return
		
	match window_mode:
		0:
			win.mode = Window.MODE_WINDOWED
			# Solo redimensionar si estamos en ventana
			if win.size != resolution:
				win.size = resolution
		1:
			win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		2:
			win.mode = Window.MODE_FULLSCREEN
			
	if vsync_enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
