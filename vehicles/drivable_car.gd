class_name DrivableCar
extends CharacterBody3D
## Машина, на которой можно ездить (аркадное управление) и сбивать зомби.
## Модель (glTF Quaternius) задаётся в model_scene, коллизия, «бампер» и камера
## создаются кодом. Управляет DriveController: enter()/exit() и set_input().
## Перед машины — направление -Z (у моделей Quaternius перед +Z, поэтому поворот 180).

signal driver_changed(driving: bool)

const GROUP: StringName = &"drivable_cars"
## Повторный удар по тому же зомби не раньше, чем через столько секунд
const HIT_COOLDOWN: float = 0.6
## Удар по зомби немного тормозит машину
const HIT_SLOWDOWN: float = 0.9
## Столкновение со стеной: скорость умножается на это
const WALL_SLOWDOWN: float = 0.35
## Гараж: двигатель +8% скорости, таран +25% урона и меньше потеря скорости за уровень
const ENGINE_PER_LEVEL: float = 0.08
const RAM_PER_LEVEL: float = 0.25
## Фары включаются, когда темнее этого (DayNightCycle.night_amount)
const HEADLIGHTS_NIGHT: float = 0.35

@export var model_scene: PackedScene
@export var model_rotation_y_degrees: float = 180.0
@export var model_scale: float = 1.0

@export_group("Driving")
## Максимальная скорость вперёд и назад, м/с (20 м/с = 72 км/ч)
@export var max_speed: float = 20.0
@export var max_reverse_speed: float = 7.0
@export var acceleration: float = 9.0
@export var brake_power: float = 22.0
## Замедление без газа
@export var drag: float = 3.5
## Поворот, рад/с на полной управляемости
@export var steer_rate: float = 1.9
## С этой скорости руль работает в полную силу
@export var full_steer_speed: float = 6.0

@export_group("Run Over")
## Ниже этой скорости зомби не получают урон
@export var run_over_min_speed: float = 3.0
## Урон = скорость (м/с) × множитель
@export var run_over_damage_factor: float = 14.0

@export_group("Camera")
@export var camera_distance: float = 7.5
@export var camera_height: float = 3.2
@export var camera_smooth: float = 6.0

var speed: float = 0.0
var camera: Camera3D

var _driven: bool = false
var _steer: float = 0.0
var _throttle: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _bumper: Area3D
var _box_size: Vector3 = Vector3(2.2, 1.6, 4.8)
var _box_center: Vector3 = Vector3(0.0, 0.8, 0.0)
## instance_id зомби -> время последнего удара
var _recent_hits: Dictionary = {}
var _time: float = 0.0
var _hit_slowdown: float = HIT_SLOWDOWN
var _headlights: Array[SpotLight3D] = []


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = PhysicsLayers.WORLD
	collision_mask = PhysicsLayers.WORLD
	floor_snap_length = 0.5
	_build_model()
	_build_collision()
	_build_bumper()
	_build_camera()
	_build_headlights()
	_apply_garage()


func is_driven() -> bool:
	return _driven


## Высота крыши (DriveController ставит туда спрятанного игрока, чтобы зомби его видели)
func get_roof_height() -> float:
	return _box_center.y + _box_size.y * 0.5


func get_speed_kmh() -> float:
	return absf(speed) * 3.6


## Точка выхода водителя — слева от машины
func get_exit_position() -> Vector3:
	return global_position - global_basis.x * (_box_size.x * 0.5 + 1.0) + Vector3.UP * 0.2


func enter() -> void:
	_driven = true
	_steer = 0.0
	_throttle = 0.0
	if camera != null:
		_snap_camera()
		camera.make_current()
	driver_changed.emit(true)


func exit() -> void:
	_driven = false
	_steer = 0.0
	_throttle = 0.0
	driver_changed.emit(false)


## steer: -1 влево .. 1 вправо; throttle: 1 газ .. -1 тормоз/назад
func set_input(steer: float, throttle: float) -> void:
	_steer = clampf(steer, -1.0, 1.0)
	_throttle = clampf(throttle, -1.0, 1.0)


func _physics_process(delta: float) -> void:
	_time += delta
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = minf(velocity.y, 0.0)

	var throttle: float = _throttle if _driven else 0.0
	if throttle > 0.0:
		var rate: float = brake_power if speed < 0.0 else acceleration
		speed = move_toward(speed, max_speed, rate * throttle * delta)
	elif throttle < 0.0:
		var rate_back: float = brake_power if speed > 0.0 else acceleration * 0.6
		speed = move_toward(speed, -max_reverse_speed, rate_back * -throttle * delta)
	else:
		speed = move_toward(speed, 0.0, drag * delta)

	# Руль работает только в движении; назад — в обратную сторону
	var steer_power: float = clampf(absf(speed) / full_steer_speed, 0.0, 1.0)
	if _driven and steer_power > 0.0:
		rotate_y(-_steer * steer_rate * steer_power * signf(speed) * delta)

	var forward: Vector3 = -global_basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	move_and_slide()
	_check_walls(forward)
	if _driven:
		_run_over()


func _process(delta: float) -> void:
	var lights_on: bool = _driven and DayNightCycle.night_amount > HEADLIGHTS_NIGHT
	if not _headlights.is_empty() and _headlights[0].visible != lights_on:
		for light: SpotLight3D in _headlights:
			light.visible = lights_on
	if camera == null or not _driven:
		return
	var target: Vector3 = _camera_target()
	camera.global_position = camera.global_position.lerp(target, clampf(camera_smooth * delta, 0.0, 1.0))
	camera.look_at(global_position + Vector3.UP * 1.2, Vector3.UP)


## Удар о стену гасит скорость (иначе машина «скользит» вдоль домов на полном ходу)
func _check_walls(forward: Vector3) -> void:
	for i in get_slide_collision_count():
		var collision: KinematicCollision3D = get_slide_collision(i)
		var normal: Vector3 = collision.get_normal()
		if absf(normal.y) < 0.5 and absf(forward.dot(normal)) > 0.5:
			speed *= WALL_SLOWDOWN
			return


func _run_over() -> void:
	if absf(speed) < run_over_min_speed or not _bumper.has_overlapping_bodies():
		return
	for body: Node3D in _bumper.get_overlapping_bodies():
		var zombie := body as Zombie
		if zombie == null or zombie.state == Zombie.State.DEAD:
			continue
		var id: int = zombie.get_instance_id()
		if _time - float(_recent_hits.get(id, -10.0)) < HIT_COOLDOWN:
			continue
		_recent_hits[id] = _time
		var push: Vector3 = (-global_basis.z) * speed
		zombie.hit_by_vehicle(absf(speed) * run_over_damage_factor, push)
		Sfx.play_3d(Sfx.pick(Sfx.sounds.flesh_hits), zombie.global_position, 0.0, 0.8)
		Sfx.play_3d(Sfx.pick(Sfx.sounds.metal_hits), global_position, -6.0)
		speed *= _hit_slowdown
	# Чистим старые записи, чтобы словарь не рос
	if _recent_hits.size() > 32:
		_recent_hits.clear()


func _camera_target() -> Vector3:
	var back: Vector3 = global_basis.z
	back.y = 0.0
	back = back.normalized() if back.length_squared() > 0.001 else Vector3.BACK
	return global_position + back * camera_distance + Vector3.UP * camera_height


func _snap_camera() -> void:
	camera.global_position = _camera_target()
	camera.look_at(global_position + Vector3.UP * 1.2, Vector3.UP)


# ---------- Сборка ----------

func _build_model() -> void:
	if model_scene == null:
		push_warning("DrivableCar '%s': не задана model_scene" % name)
		return
	var model := model_scene.instantiate() as Node3D
	if model == null:
		push_warning("DrivableCar '%s': model_scene не Node3D" % name)
		return
	model.name = "Model"
	model.rotation.y = deg_to_rad(model_rotation_y_degrees)
	model.scale = Vector3.ONE * model_scale
	add_child(model)
	var bounds: AABB = _local_bounds(model)
	if bounds.size != Vector3.ZERO:
		_box_size = bounds.size
		_box_center = bounds.get_center()


func _build_collision() -> void:
	var box := BoxShape3D.new()
	# Чуть уже модели и приподнята над землёй, чтобы не цеплять неровности
	box.size = Vector3(_box_size.x * 0.92, maxf(_box_size.y - 0.3, 0.5), _box_size.z * 0.95)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = _box_center + Vector3.UP * 0.15
	add_child(shape)


func _build_bumper() -> void:
	_bumper = Area3D.new()
	_bumper.name = "Bumper"
	_bumper.collision_layer = 0
	_bumper.collision_mask = PhysicsLayers.ENEMY
	_bumper.monitorable = false
	var box := BoxShape3D.new()
	box.size = _box_size + Vector3(0.6, 0.4, 0.8)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = _box_center
	_bumper.add_child(shape)
	add_child(_bumper)


## Улучшения гаража из GameState
func _apply_garage() -> void:
	var engine: int = GameState.get_car_upgrade_level("engine")
	var ram: int = GameState.get_car_upgrade_level("ram")
	max_speed *= 1.0 + ENGINE_PER_LEVEL * engine
	acceleration *= 1.0 + ENGINE_PER_LEVEL * engine
	run_over_damage_factor *= 1.0 + RAM_PER_LEVEL * ram
	_hit_slowdown = minf(HIT_SLOWDOWN + 0.015 * ram, 0.98)


## Две фары спереди (горят ночью, пока машина за рулём)
func _build_headlights() -> void:
	for side: float in [-1.0, 1.0]:
		var light := SpotLight3D.new()
		light.light_color = Color(1.0, 0.95, 0.8)
		light.light_energy = 3.0
		light.spot_range = 30.0
		light.spot_angle = 32.0
		light.shadow_enabled = false
		light.visible = false
		light.position = Vector3(side * _box_size.x * 0.3, _box_center.y, _box_center.z - _box_size.z * 0.5)
		light.rotation.x = deg_to_rad(-6.0)
		add_child(light)
		_headlights.append(light)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "ChaseCamera"
	camera.top_level = true
	camera.fov = 70.0
	camera.far = 300.0
	add_child(camera)


## Габариты мешей модели в координатах машины (по цепочке трансформов)
func _local_bounds(model: Node3D) -> AABB:
	var result := AABB()
	var has_bounds: bool = false
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var xform: Transform3D = Transform3D.IDENTITY
		var current: Node = mesh_instance
		while current != null and current != self:
			var current_3d := current as Node3D
			if current_3d != null:
				xform = current_3d.transform * xform
			current = current.get_parent()
		var bounds: AABB = xform * mesh_instance.get_aabb()
		result = result.merge(bounds) if has_bounds else bounds
		has_bounds = true
	return result
