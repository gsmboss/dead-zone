class_name Hitbox
extends Area3D
## Зона попадания. Луч выстрела находит её и передаёт урон в Health.

## Пусто → нода "Health" у родителя
@export var health: Health
@export_range(0.1, 10.0, 0.1) var damage_multiplier: float = 1.0
## Попадание в эту зону считается хедшотом
@export var is_head: bool = false
## Живая цель: кровь и звук попадания по телу. false — искры и звук металла (бочка)
@export var flesh: bool = true
## Помощь прицеливания и автоогонь считают это целью (бочку — нет, иначе автоогонь взорвёт её рядом)
@export var auto_target: bool = true

## Сейчас идёт урон от выстрела через хитбокс (мультиплеер: отличить выстрел от удара зомби)
static var applying: bool = false

## Своя обработка урона (каска, броня зомби): func(amount, hit_position, is_head) -> float.
## Вернула 0 — попадание засчитано, но урон поглощён
var damage_filter: Callable


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
	var amount: float = damage * damage_multiplier
	if damage_filter.is_valid():
		amount = float(damage_filter.call(amount, hit_position, is_head))
	if amount > 0.0:
		health.take_damage(amount, hit_position, is_head)
	applying = false
	return true
