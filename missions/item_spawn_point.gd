class_name ItemSpawnPoint
extends Marker3D
## Место, где может появиться ящик с припасами в миссии COLLECT. Группа "item_spawn".


func _ready() -> void:
	add_to_group(&"item_spawn")
