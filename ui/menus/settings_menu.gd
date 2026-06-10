extends CanvasLayer

@onready var tab_audio = $Panel/Tabs/TabAudio
@onready var tab_controls = $Panel/Tabs/TabControls
@onready var tab_graphics = $Panel/Tabs/TabGraphics

@onready var content_audio = $Panel/Content/Audio
@onready var content_controls = $Panel/Content/Controls
@onready var content_graphics = $Panel/Content/Graphics

@onready var master_slider = $Panel/Content/Audio/Master/HSlider
@onready var music_slider = $Panel/Content/Audio/Music/HSlider
@onready var sfx_slider = $Panel/Content/Audio/SFX/HSlider

@onready var mouse_sens_slider = $Panel/Content/Controls/MouseSens/HSlider
@onready var stick_sens_slider = $Panel/Content/Controls/StickSens/HSlider
@onready var p1_device_opt = $Panel/Content/Controls/P1Device/OptionButton
@onready var p2_device_opt = $Panel/Content/Controls/P2Device/OptionButton
@onready var p2_container = $Panel/Content/Controls/P2Device

@onready var window_opt = $Panel/Content/Graphics/WindowMode/OptionButton
@onready var vsync_check = $Panel/Content/Graphics/VSync/CheckButton

func _ready():
	_load_ui_from_manager()
	_connect_signals()
	_switch_tab(0)

func _load_ui_from_manager():
	master_slider.value = GameManager.master_volume
	music_slider.value = GameManager.music_volume
	sfx_slider.value = GameManager.sfx_volume
	
	mouse_sens_slider.value = GameManager.mouse_sensitivity
	stick_sens_slider.value = GameManager.stick_sensitivity
	
	p1_device_opt.select(0 if GameManager.p1_device == "keyboard" else 1)
	p2_device_opt.select(0 if GameManager.p2_device == "keyboard" else 1)
	
	# Ocultamos la opción del dispositivo J2 si no estamos en multijugador
	p2_container.visible = GameManager.is_multiplayer
	
	window_opt.select(GameManager.window_mode)
	vsync_check.button_pressed = GameManager.vsync_enabled

func _connect_signals():
	tab_audio.pressed.connect(func(): _switch_tab(0))
	tab_controls.pressed.connect(func(): _switch_tab(1))
	tab_graphics.pressed.connect(func(): _switch_tab(2))
	
	master_slider.value_changed.connect(func(v): GameManager.master_volume = v; GameManager.apply_audio_settings())
	music_slider.value_changed.connect(func(v): GameManager.music_volume = v; GameManager.apply_audio_settings())
	sfx_slider.value_changed.connect(func(v): GameManager.sfx_volume = v; GameManager.apply_audio_settings())
	
	mouse_sens_slider.value_changed.connect(func(v): GameManager.mouse_sensitivity = v)
	stick_sens_slider.value_changed.connect(func(v): GameManager.stick_sensitivity = v)
	
	p1_device_opt.item_selected.connect(func(idx): GameManager.p1_device = "keyboard" if idx == 0 else "gamepad")
	p2_device_opt.item_selected.connect(func(idx): GameManager.p2_device = "keyboard" if idx == 0 else "gamepad")
	
	window_opt.item_selected.connect(func(idx): GameManager.window_mode = idx; GameManager.apply_graphics_settings())
	vsync_check.toggled.connect(func(v): GameManager.vsync_enabled = v; GameManager.apply_graphics_settings())
	
	$Panel/BtnBack.pressed.connect(_on_back_pressed)
	$Panel/BtnDefaults.pressed.connect(_on_defaults_pressed)

func _switch_tab(idx: int):
	content_audio.visible = (idx == 0)
	content_controls.visible = (idx == 1)
	content_graphics.visible = (idx == 2)

func _on_back_pressed():
	GameManager.save_settings()
	queue_free()

func _on_defaults_pressed():
	GameManager.reset_to_defaults()
	_load_ui_from_manager()
