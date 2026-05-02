extends Control

# Referencias a la barra de vida
@onready var health_bar = $HealthBarBackground/HealthBar
@onready var health_text = $HealthBarBackground/HealthBar/HealthText

# Referencias a la barra de energía
@onready var energy_bar = $EnergyBarBackground/EnergyBar
@onready var energy_text = $EnergyBarBackground/EnergyBar/EnergyText

# Nuevas referencias
@onready var wave_label = $WaveLabel
@onready var timer_label = $TimerLabel
@onready var enemies_left_label = $EnemiesLeftLabel

func _ready():
	# Verificar que todos los nodos existen
	if health_bar and health_text and energy_bar and energy_text:
		print("✅ UI cargada correctamente")
	else:
		print("❌ Algunos nodos de UI no se encontraron")

func update_health(current: int, max_health: int):
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current
	if health_text:
		health_text.text = str(current) + "/" + str(max_health)

func update_energy(current: int, max_energy: int):
	if energy_bar:
		energy_bar.max_value = max_energy
		energy_bar.value = current
	if energy_text:
		energy_text.text = str(current) + "/" + str(max_energy)

# Nuevas funciones
func update_wave(current_wave: int, total_waves: int):
	if wave_label:
		wave_label.text = "HORDA: " + str(current_wave) + "/" + str(total_waves)

func update_timer(seconds: int):
	if timer_label:
		var minutes = seconds / 60
		var remaining_seconds = seconds % 60
		timer_label.text = "TIEMPO: " + str(minutes).pad_zeros(2) + ":" + str(remaining_seconds).pad_zeros(2)

func update_enemies_left(count: int):
	if enemies_left_label:
		enemies_left_label.text = "ENEMIGOS: " + str(count)
