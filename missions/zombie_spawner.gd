class_name ZombieSpawner
extends Node3D
## Создаёт зомби в точках ZombieSpawnPoint.
## Приоритет: точки вне поля зрения игрока → просто далёкие → любые.
## Открытый мир (dynamic_spawn): точки берутся на навмеше в кольце вокруг игрока,
## а зомби дальше despawn_distance убираются (без награды), чтобы держать лимит.

signal zombie_spawned(zombie: Zombie)

@export var zombie_scene: PackedScene
## Не спавнить ближе этого расстояния к игроку
@export var min_player_distance: float = 10.0
## Случайный разброс вокруг точки, чтобы зомби не появлялись друг в друге
@export var spawn_jitter: float = 1.0
## Сразу сообщать зомби, где игрок
@export var aggressive: bool = true

@export_group("Open World")
## Спавн вокруг игрока по навмешу вместо точек ZombieSpawnPoint
@export var dynamic_spawn: bool = false
@export var dynamic_min_distance: float = 22.0
@export var dynamic_max_distance: float = 42.0
## Зомби дальше этого убираются (0 — не убирать)
@export var despawn_distance: float = 70.0

const DYNAMIC_ATTEMPTS: int = 8
const DESPAWN_CHECK_INTERVAL: float = 1.0
## Точка на навмеше не дальше этого от выбранной (иначе там стена/здание)
const NAV_SNAP_TOLERANCE: float = 3.0

var _despawn_timer: float = 0.0
var _players: Array[Node3D] = []

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
	# По сети в открытом мире — вокруг случайного игрока (иначе у друзей далеко от хоста пусто)
	if dynamic_spawn and Net.in_match:
		_collect_players()
		if not _players.is_empty():
			player = _players[_rng.randi() % _players.size()]
	var point: Variant = _pick_dynamic_point(player) if dynamic_spawn else _pick_point(player)
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


func _process(delta: float) -> void:
	if despawn_distance <= 0.0 or not dynamic_spawn:
		return
	_despawn_timer -= delta
	if _despawn_timer > 0.0:
		return
	_despawn_timer = DESPAWN_CHECK_INTERVAL
	_collect_players()
	if _players.is_empty():
		return
	for child: Node in get_children():
		var zombie := child as Zombie
		if zombie != null and _distance_to_nearest_player(zombie.global_position) > despawn_distance:
			zombie.despawn()


## Живые игроки: свой и (по сети) копии друзей. Массив переиспользуется
func _collect_players() -> void:
	_players.clear()
	for group: StringName in [&"player", &"remote_player"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var body := node as Player
			if body != null and (body.health == null or not body.health.is_dead):
				_players.append(body)


func _distance_to_nearest_player(point: Vector3) -> float:
	var nearest: float = INF
	for body: Node3D in _players:
		nearest = minf(nearest, point.distance_to(body.global_position))
	return nearest


## Случайная точка на навмеше в кольце вокруг игрока, по возможности вне поля зрения
func _pick_dynamic_point(player: Node3D) -> Variant:
	if player == null:
		return null
	var map: RID = get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return null  # навмеш ещё строится
	var camera: Camera3D = get_viewport().get_camera_3d()
	var fallback: Variant = null
	for attempt in DYNAMIC_ATTEMPTS:
		var angle: float = _rng.randf() * TAU
		var distance: float = _rng.randf_range(dynamic_min_distance, dynamic_max_distance)
		var candidate: Vector3 = player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
		var on_mesh: Vector3 = NavigationServer3D.map_get_closest_point(map, candidate)
		if Vector2(on_mesh.x - candidate.x, on_mesh.z - candidate.z).length() > NAV_SNAP_TOLERANCE:
			continue
		if on_mesh.distance_to(player.global_position) < dynamic_min_distance * 0.7:
			continue
		if camera != null and camera.is_position_in_frustum(on_mesh + Vector3.UP):
			fallback = on_mesh
			continue
		return on_mesh
	return fallback


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
