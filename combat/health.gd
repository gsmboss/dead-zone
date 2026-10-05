class_name Health
extends Node
## Здоровье сущности. Урон приходит через Hitbox.

signal health_changed(current: float, max_value: float)
signal damaged(amount: float, hit_position: Vector3, is_headshot: bool)
signal died

@export var max_health: float = 100.0

var current: float = 0.0
var is_dead: bool = false


func _ready() -> void:
	if max_health <= 0.0:
		push_warning("Health '%s': max_health <= 0, установлено 1" % get_parent().name)
		max_health = 1.0
	current = max_health


func take_damage(amount: float, hit_position: Vector3 = Vector3.ZERO, is_headshot: bool = false) -> void:
	if is_dead or amount <= 0.0:
		return
	current = maxf(current - amount, 0.0)
	damaged.emit(amount, hit_position, is_headshot)
	health_changed.emit(current, max_health)
	if current <= 0.0:
		is_dead = true
		died.emit()


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current = minf(current + amount, max_health)
	health_changed.emit(current, max_health)


func reset() -> void:
	is_dead = false
	current = max_health
	health_changed.emit(current, max_health)
