class_name Health
extends Node
## Здоровье сущности. Урон приходит через Hitbox.

signal health_changed(current: float, max_value: float)
signal damaged(amount: float, hit_position: Vector3, is_headshot: bool)
signal died

## Чем нанесён урон (для индикатора направления и эффектов)
enum Kind { MELEE, BULLET, EXPLOSION, FIRE, ACID }

@export var max_health: float = 100.0
## Доля поглощаемого урона (броня), 0..0.9
@export_range(0.0, 0.9, 0.01) var damage_reduction: float = 0.0

var current: float = 0.0
var is_dead: bool = false
## Источник последнего урона: заполнены только во время сигнала damaged от take_damage_from()
var last_kind: int = Kind.MELEE
var last_source_name: String = ""
var last_source: Node3D


func _ready() -> void:
	if max_health <= 0.0:
		push_warning("Health '%s': max_health <= 0, установлено 1" % get_parent().name)
		max_health = 1.0
	current = max_health


func take_damage(amount: float, hit_position: Vector3 = Vector3.ZERO, is_headshot: bool = false) -> void:
	if is_dead or amount <= 0.0:
		return
	amount *= 1.0 - clampf(damage_reduction, 0.0, 0.9)
	current = maxf(current - amount, 0.0)
	damaged.emit(amount, hit_position, is_headshot)
	health_changed.emit(current, max_health)
	if current <= 0.0:
		is_dead = true
		died.emit()


## Урон с источником: kind — Kind, source_name — имя игрока (по сети), source — кто нанёс
## (индикатор урона следит за ним, пока стрелка видна)
func take_damage_from(amount: float, hit_position: Vector3, is_headshot: bool, kind: int,
		source_name: String = "", source: Node3D = null) -> void:
	last_kind = kind
	last_source_name = source_name
	last_source = source
	take_damage(amount, hit_position, is_headshot)
	last_kind = Kind.MELEE
	last_source_name = ""
	last_source = null


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current = minf(current + amount, max_health)
	health_changed.emit(current, max_health)


func reset() -> void:
	is_dead = false
	current = max_health
	health_changed.emit(current, max_health)
