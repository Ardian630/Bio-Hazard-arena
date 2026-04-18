extends Camera3D

@export var target : Node3D  # El jugador a seguir
@export var offset : Vector3 = Vector3(0, 15, 5)  # Altura y distancia

func _ready():
	if not target:
		# Si no se asignó target, buscar al jugador automáticamente
		target = get_parent()  # Asume que el padre es el jugador
	

func _process(delta):
	if target:
		# Seguir al target pero mantener rotación fija
		global_position = target.global_position + offset
		
		# Asegurar rotación constante (ya no depende del padre)
		rotation_degrees = Vector3(-70, 0, 0)  # Fijo
