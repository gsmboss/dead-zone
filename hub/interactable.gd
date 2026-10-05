class_name Interactable
extends Area3D
## Зона взаимодействия: когда игрок внутри, в HUD убежища появляется кнопка.

signal player_entered(interactable: Interactable)
signal player_exited(interactable: Interactable)
signal interacted

## Текст кнопки
@export var prompt: String = "ИСПОЛЬЗОВАТЬ"
## Что открыть: missions, shop (или своё — тогда сработает сигнал interacted)
@export var action_id: StringName = &""


func _ready() -> void:
	add_to_group(&"interactables")
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func interact() -> void:
	interacted.emit()


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		player_entered.emit(self)


func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		player_exited.emit(self)
