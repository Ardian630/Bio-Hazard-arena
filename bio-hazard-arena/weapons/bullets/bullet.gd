# --------------------------------------------------------------------------
# extends RigidBody3D
# --------------------------------------------------------------------------
extends Area3D

@export var speed : float = 30.0
@export var damage : int = 15
@export var lifetime : float = 3.0

# Variable originaria de bullet_simple.gd para efectos visuales
@export var impact_particle : PackedScene 

var player_ref : Node = null
var direction : Vector3

# -----------------------
# func initialize(dir: Vector3):
# 	direction = dir.normalized()
# -----------------------

# Se actualizan los parámetros para que coincidan con la llamada desde player.gd
func initialize(dir: Vector3, player: Node, max_range: float):
	direction = dir.normalized()
	player_ref = player
	look_at(global_position + direction, Vector3.UP)
	
	# Se maneja la autodestrucción temporal aquí
	await get_tree().create_timer(lifetime).timeout
	if visible: # Si sigue viva después de 3 segundos, se devuelve al pool
		ProjectilePool.return_bullet(self)
	
# Nueva Funcion: Al ser un Area3D, se mueve la bala manualmente (+ rapido)
func _physics_process(delta):
	global_position += direction * speed * delta

func _on_body_entered(body):
	if body == player_ref:
		return
	
	if body.has_method("take_damage"):
		body.take_damage(damage)
		print("💥 Impacto en: ", body.name)
	
	_spawn_impact_particle()
#	queue_free()
# 	En lugar de queue_free(), se devuelve al pool
	ProjectilePool.return_bullet(self)

# Nueva Funcion: Originaria de bullet_simple.gd
func _spawn_impact_particle():
	if not impact_particle:
		return
	
	var particle = impact_particle.instantiate()
	get_parent().add_child(particle)
	particle.global_position = global_position
	particle.emitting = true
	
	await get_tree().create_timer(1.0).timeout
	particle.queue_free()
