class_name ZombieSpawner
extends Node3D
## Создаёт зомби в точках ZombieSpawnPoint.
## Приоритет: точки вне поля зрения игрока → просто далёкие → любые.

signal zombie_spawned(zombie: Zombie)

@export var zombie_scene: PackedScene
## Не спавнить ближе этого расстояния к игроку
@export var min_player_distance: float = 10.0
## Случайный разброс вокруг точки, чтобы зомби не появлялись друг в друге
@export var spawn_jitter: float = 1.0
## Сразу сообщать зомби, где игрок
@export var aggressive: bool = true

var _rng := RandomNumberGenerator.new()
var _warned_no_points: bool = false


func _ready() -> void:
	_rng.randomize()
	if zombie_scene == null:
		push_error("ZombieSpawner: не назначена zombie_scene")


## Возвращает созданного зомби или null, если спавн невозможен.
## Множители — сложность миссии (уровень повтора)
func spawn(data: ZombieData, health_multiplier: float = 1.0, damage_multiplier: float = 1.0) -> Zombie:
	if zombie_scene == null:
		return null

	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var point: Variant = _pick_point(player)
	if point == null:
		return null

	var zombie := zombie_scene.instantiate() as Zombie
	if zombie == null:
		push_error("ZombieSpawner: в корне zombie_scene должен быть скрипт zombie.gd")
		return null

	# Данные и позицию задаём до add_child: они нужны зомби в _ready
	zombie.data = data
	zombie.health_multiplier = health_multiplier
	zombie.damage_multiplier = damage_multiplier
	var jitter := Vector3(
		_rng.randf_range(-spawn_jitter, spawn_jitter), 0.0,
		_rng.randf_range(-spawn_jitter, spawn_jitter))
	zombie.position = to_local((point as Vector3) + jitter)
	zombie.rotation.y = _rng.randf() * TAU
	add_child(zombie)

	if aggressive and player != null:
		zombie.notify_target(player.global_position)
	zombie_spawned.emit(zombie)
	return zombie


func _pick_point(player: Node3D) -> Variant:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(&"zombie_spawn")
	var all_points: Array[Vector3] = []
	for node: Node in nodes:
		if node is Node3D:
			all_points.append((node as Node3D).global_position)

	if all_points.is_empty():
		if not _warned_no_points:
			push_warning("ZombieSpawner: нет ни одной ZombieSpawnPoint в уровне")
			_warned_no_points = true
		return null

	if player == null:
		return all_points[_rng.randi() % all_points.size()]

	var camera: Camera3D = get_viewport().get_camera_3d()
	var far_points: Array[Vector3] = []
	var hidden_points: Array[Vector3] = []
	for p: Vector3 in all_points:
		if p.distance_to(player.global_position) < min_player_distance:
			continue
		far_points.append(p)
		# Проверяем точку на уровне груди зомби
		if camera == null or not camera.is_position_in_frustum(p + Vector3.UP):
			hidden_points.append(p)

	var pool: Array[Vector3] = all_points
	if not hidden_points.is_empty():
		pool = hidden_points
	elif not far_points.is_empty():
		pool = far_points
	return pool[_rng.randi() % pool.size()]
