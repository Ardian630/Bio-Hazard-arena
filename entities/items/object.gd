extends CharacterBody3D

# Tipos de power-up
enum ObjectType { HEALTH, ENERGY, MECHA, THUNDERBOLT }

# Variables exportadas
@export var object_type : ObjectType = ObjectType.HEALTH
@export var health_amount : int = 25
@export var energy_amount : int = 25
@export var rotation_speed : float = 2.0
@export var float_amplitude : float = 0.2
@export var float_speed : float = 2.0

# MECHA
@export var mecha_duration      : float = 8.0
@export var mecha_scale_factor  : float = 1.8
@export var mecha_speed_boost   : float = 1.5   # Multiplicador
@export var mecha_fire_rate_mult: float = 0.5   # shoot_cooldown * 0.5 = más rápido

# THUNDERBOLT
@export var thunderbolt_pulses    : int = 3
@export var thunderbolt_interval  : float = 2.0   # Segundos entre descargas
@export var thunderbolt_aoe_radius: float = 5.0
@export var thunderbolt_damage    : int = 30

# Nodos
@onready var health_mesh      = $HealthMesh
@onready var energy_mesh      = $EnergyMesh
@onready var mecha_mesh       = $MechaMesh
@onready var thunderbolt_mesh = $ThunderBoltMesh

# Variables internas
var start_y : float
var time : float = 0

func _ready():
	start_y = global_position.y
	
	# Mostrar el mesh correcto según el tipo y ocultar los demás
	health_mesh.visible      = (object_type == ObjectType.HEALTH)
	energy_mesh.visible      = (object_type == ObjectType.ENERGY)
	mecha_mesh.visible       = (object_type == ObjectType.MECHA)
	thunderbolt_mesh.visible = (object_type == ObjectType.THUNDERBOLT)

func _physics_process(delta):
	time += delta
	
	# Rotación continua
	rotate_y(rotation_speed * delta)
	
	# Flotación suave (subir y bajar)
	var new_y = start_y + sin(time * float_speed) * float_amplitude
	global_position.y = new_y

# Cuando un jugador toca el power-up (señal del Area3D)
func _on_area_3d_body_entered(body):
	if body.is_in_group("players"):
		_apply_effect(body)
		queue_free()  # Desaparecer al ser recolectado

func _apply_effect(player):
	match object_type:
		ObjectType.HEALTH:
			if player.has_method("heal"):
				player.heal(health_amount)
				AudioManager.play_sfx("pickup_health")
				print("❤️ Objeto de vida: +", health_amount, " → J", player.player_id)
		
		ObjectType.ENERGY:
			if player.has_method("recharge_energy"):
				player.recharge_energy(energy_amount)
				AudioManager.play_sfx("pickup_energy")
				print("🔋 Objeto de energía: +", energy_amount, " → J", player.player_id)
		
		ObjectType.MECHA:
			if player.has_method("activate_mecha"):
				player.activate_mecha(
					mecha_duration,
					mecha_scale_factor,
					mecha_speed_boost,
					mecha_fire_rate_mult
				)
				AudioManager.play_sfx("pickup_mecha")
				print("🤖 Objeto MECHA recogido → J", player.player_id)
		
		ObjectType.THUNDERBOLT:
			if player.has_method("activate_thunderbolt"):
				player.activate_thunderbolt(
					thunderbolt_pulses,
					thunderbolt_interval,
					thunderbolt_aoe_radius,
					thunderbolt_damage
				)
				AudioManager.play_sfx("pickup_thunderbolt")
				print("⚡ Objeto THUNDERBOLT recogido → J", player.player_id)
