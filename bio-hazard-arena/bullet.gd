extends RigidBody3D

@export var speed : float = 30.0
@export var damage : int = 15
@export var lifetime : float = 3.0

var player_ref : Node = null
var direction : Vector3  # Guardar dirección

func initialize(dir: Vector3):
	direction = dir.normalized()

func _ready():
	gravity_scale = 0.0
	linear_velocity = direction * speed
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _on_body_entered(body):
	if body == player_ref:
		return
	
	if body.has_method("take_damage"):
		body.take_damage(damage)
		print("💥 Impacto en: ", body.name)
		queue_free()
	else:
		queue_free()
