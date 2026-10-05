class_name Hitbox
extends Area3D
## Зона попадания. Луч выстрела находит её и передаёт урон в Health.

## Пусто → нода "Health" у родителя
@export var health: Health
@export_range(0.1, 10.0, 0.1) var damage_multiplier: float = 1.0
## Попадание в эту зону считается хедшотом
@export var is_head: bool = false

## Сейчас идёт урон от выстрела через хитбокс (мультиплеер: отличить выстрел от удара зомби)
static var applying: bool = false


func _ready() -> void:
	collision_layer = PhysicsLayers.HITBOX
	collision_mask = 0
	if health == null and get_parent() != null:
		health = get_parent().get_node_or_null(^"Health") as Health
	if health == null:
		push_warning("Hitbox '%s': не найден Health" % name)


## Возвращает true, если урон засчитан
func apply_hit(damage: float, hit_position: Vector3) -> bool:
	if health == null or health.is_dead or damage <= 0.0:
		return false
	applying = true
	health.take_damage(damage * damage_multiplier, hit_position, is_head)
	applying = false
	return true
