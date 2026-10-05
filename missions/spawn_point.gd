class_name ZombieSpawnPoint
extends Marker3D
## Точка появления зомби. Ставь по краям карты и за укрытиями, на навмеше.


func _ready() -> void:
	add_to_group(&"zombie_spawn")
