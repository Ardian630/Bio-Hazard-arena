extends Node

var pool: Array = []
var max_bullets: int = 5 # Cantidad máxima de balas reciclabes
var bullet_scene: PackedScene = preload("res://weapons/bullets/bullet.tscn")

func _ready() -> void:
	# Al arrancar, se construyen todas las balas y se ocultan
	for i in range(max_bullets):
		var bullet = bullet_scene.instantiate()
		bullet.hide()
		bullet.set_physics_process(false)
		bullet.set_deferred("monitoring", false) # Apaga el sensor del Area3D
		add_child(bullet)
		pool.append(bullet)

# El jugador (player) llama a esta función para pedir una bala
func get_bullet() -> Node:
	for bullet in pool:
		if not bullet.visible:
			bullet.show()
			bullet.set_physics_process(true)
			bullet.set_deferred("monitoring", true) # Enciende el sensor
			return bullet
			
	print("¡Alerta! El pool se quedó sin balas. Aumenta max_bullets.")
	return null

# La bala llama a esta función cuando choca para regresar al pool
func return_bullet(bullet: Node) -> void:
	bullet.hide()
	bullet.set_physics_process(false)
	bullet.set_deferred("monitoring", false)
	bullet.global_position = Vector3(0, -100, 0) # Se esconde bajo el mapa
