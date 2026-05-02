extends CharacterBody3D

# Tipos de power-up
enum ObjectType { HEALTH, ENERGY }

# Variables exportadas
@export var object_type : ObjectType = ObjectType.HEALTH
@export var health_amount : int = 25
@export var energy_amount : int = 25
@export var rotation_speed : float = 2.0
@export var float_amplitude : float = 0.2
@export var float_speed : float = 2.0

# Nodos
@onready var health_mesh = $HealthMesh
@onready var energy_mesh = $EnergyMesh

# Variables internas
var start_y : float
var time : float = 0

func _ready():
	start_y = global_position.y
	
	# Mostrar el mesh correcto según el tipo y ocultar el otro
	match object_type:
		ObjectType.HEALTH:
			health_mesh.visible = true
			energy_mesh.visible = false
		
		ObjectType.ENERGY:
			health_mesh.visible = false
			energy_mesh.visible = true

func _physics_process(delta):
	time += delta
	
	# Rotación continua
	rotate_y(rotation_speed * delta)
	
	# Flotación suave (subir y bajar)
	var new_y = start_y + sin(time * float_speed) * float_amplitude
	global_position.y = new_y

# Cuando el jugador toca el power-up (señal del Area3D)
func _on_area_3d_body_entered(body):
	if body.name == "Player":
		_apply_effect(body)
		queue_free()  # Desaparecer al ser recolectado

func _apply_effect(player):
	match object_type:
		ObjectType.HEALTH:
			if player.has_method("heal"):
				player.heal(health_amount)
				print("❤️ Objeto de vida: +", health_amount)
		
		ObjectType.ENERGY:
			if player.has_method("recharge_energy"):
				player.recharge_energy(energy_amount)
				print("🔋 Objeto de energía: +", energy_amount)
