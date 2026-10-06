class_name DrivableCar
extends CharacterBody3D
## Машина, на которой можно ездить (аркадное управление с дрифтом) и сбивать зомби.
## Модель (glTF Quaternius) задаётся в model_scene или car_data (машина автосалона), коллизия,
## «бампер», камера, фары, стоп-сигналы, дым шин и неон создаются кодом.
## Управляет DriveController: enter()/exit(), set_input(), set_handbrake().
## Перед машины — направление -Z (у моделей Quaternius перед +Z, поэтому поворот 180).
## По сети: места seats (peer_id водителя и пассажиров) раздаёт хост, машину ведёт водитель
## и рассылает её состояние; у остальных она плавно догоняет присланное (копия).

signal driver_changed(driving: bool)
## По сети сменились водитель или пассажиры
signal seats_changed

const GROUP: StringName = &"drivable_cars"
## Водитель и три пассажира
const SEAT_COUNT: int = 4
## Повторный удар по тому же зомби не раньше, чем через столько секунд
const HIT_COOLDOWN: float = 0.6
## Удар по зомби немного тормозит машину
const HIT_SLOWDOWN: float = 0.9
## Столкновение со стеной: скорость умножается на это
const WALL_SLOWDOWN: float = 0.35
const FALL_LIMIT_Y: float = -12.0
## Гараж базы: двигатель +8% скорости, таран +25% урона и меньше потеря скорости за уровень
const ENGINE_PER_LEVEL: float = 0.08
const RAM_PER_LEVEL: float = 0.25
## Тюнинг автосалона за уровень: двигатель, газ (разгон), управление (руль и сцепление), таран
const TUNE_ENGINE: float = 0.07
const TUNE_TURBO: float = 0.12
const TUNE_STEER: float = 0.06
const TUNE_GRIP: float = 0.08
const TUNE_RAM: float = 0.25
## Фары: днём светят слабо, ночью — вовсю (DayNightCycle.night_amount)
const HEADLIGHT_DAY_ENERGY: float = 1.2
const HEADLIGHT_NIGHT_ENERGY: float = 6.0
const HEADLIGHT_RANGE: float = 42.0
const HEADLIGHT_ANGLE: float = 38.0
## Рассеянный свет перед капотом — освещает тротуары по бокам
const FILL_LIGHT_RANGE: float = 11.0
const FILL_LIGHT_NIGHT_ENERGY: float = 1.6
const HEADLIGHT_COLOR: Color = Color(1.0, 0.95, 0.82)
const BRAKE_COLOR: Color = Color(1.0, 0.08, 0.05)
## Дрифт: боковое скольжение больше этого (м/с) — занос, дым и очки дрифта
const DRIFT_LATERAL: float = 2.6
const DRIFT_MIN_SPEED: float = 5.0
## Ручник гасит скорость и разворачивает машину резче
const HANDBRAKE_DRAG: float = 5.0
const HANDBRAKE_STEER: float = 1.5
## Резкий руль на большой скорости срывает зад в занос и без ручника
const POWER_SLIDE_STEER: float = 0.75
const POWER_SLIDE_SPEED: float = 0.7
## Боковое скольжение тоже немного тормозит
const SLIDE_SCRUB: float = 0.25
## Состояние по сети 20 раз в секунду
const NET_INTERVAL: float = 0.05
const NET_STATE_SIZE: int = 8
const NET_SNAP_DISTANCE: float = 8.0

@export var model_scene: PackedScene
@export var model_rotation_y_degrees: float = 180.0
@export var model_scale: float = 1.0
## Машина автосалона: модель и характеристики берутся из неё (поверх полей ниже)
@export var car_data: CarData

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
## Сцепление шин: как быстро гасится боковое скольжение
@export var grip: float = 8.0
## Сцепление на ручнике (меньше — длиннее занос)
@export var drift_grip: float = 2.0

@export_group("Run Over")
## Ниже этой скорости зомби не получают урон
@export var run_over_min_speed: float = 3.0
## Урон = скорость (м/с) × множитель
@export var run_over_damage_factor: float = 14.0

@export_group("Camera")
@export var camera_distance: float = 7.5
@export var camera_height: float = 3.2
@export var camera_smooth: float = 6.0

## Тюнинг: "engine"/"turbo"/"handling"/"ram" -> уровень (задать до добавления в дерево)
var tuning: Dictionary = {}
## Покраска (белый — заводской цвет) и неон (прозрачный — без неона)
var paint: Color = Color.WHITE
var neon: Color = Color(0.0, 0.0, 0.0, 0.0)
## Скорость вдоль машины и боковое скольжение, м/с
var speed: float = 0.0
var lateral: float = 0.0
var camera: Camera3D
## По сети: peer_id на местах (0 — свободно), место 0 — водитель
var seats := PackedInt32Array([0, 0, 0, 0])

var _driven: bool = false
var _inside: bool = false  # свой игрок в машине (водитель или пассажир)
var _steer: float = 0.0
var _throttle: float = 0.0
var _handbrake: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _bumper: Area3D
var _box_size: Vector3 = Vector3(2.2, 1.6, 4.8)
var _box_center: Vector3 = Vector3(0.0, 0.8, 0.0)
## instance_id зомби -> время последнего удара
var _recent_hits: Dictionary = {}
var _time: float = 0.0
var _hit_slowdown: float = HIT_SLOWDOWN
var _safe_position: Vector3 = Vector3.ZERO
var _headlights: Array[SpotLight3D] = []
var _fill_light: OmniLight3D
var _brake_light: OmniLight3D
var _neon_light: OmniLight3D
var _headlight_material: StandardMaterial3D
var _brake_material: StandardMaterial3D
var _smoke: Array[CPUParticles3D] = []
var _lights_on: bool = false
var _braking: bool = false
var _smoking: bool = false
# Сеть
var _net_timer: float = 0.0
var _net_buffer := PackedFloat32Array()
var _net_position: Vector3 = Vector3.ZERO
var _net_yaw: float = 0.0
var _net_has_state: bool = false
var _net_flags: int = 0


## Машина автосалона с тюнингом, покраской и неоном
static func create(data: CarData, car_tuning: Dictionary = {}, paint_color: Color = Color.WHITE,
		neon_color: Color = Color(0.0, 0.0, 0.0, 0.0)) -> DrivableCar:
	var car := DrivableCar.new()
	car.car_data = data
	car.tuning = car_tuning.duplicate()
	car.paint = paint_color
	car.neon = neon_color
	return car


## Выбранная в автосалоне машина игрока
static func create_selected() -> DrivableCar:
	var data: CarData = GameState.get_selected_car()
	if data == null:
		return null
	var car_tuning: Dictionary = {}
	for stat: String in GameState.CAR_TUNING:
		car_tuning[stat] = GameState.get_car_tuning(data.id, stat)
	var neon_index: int = GameState.get_car_neon_index(data.id)
	var neon_color: Color = GameState.CAR_NEONS[neon_index] if neon_index >= 0 else Color(0.0, 0.0, 0.0, 0.0)
	return create(data, car_tuning, GameState.CAR_PAINTS[GameState.get_car_paint_index(data.id)], neon_color)


## Машина другого игрока по строке GameState.get_car_net_info() ("id|краска|неон|тюнинг…")
static func create_from_net_info(info: String) -> DrivableCar:
	var parts: PackedStringArray = info.split("|")
	var data: CarData = GameState.get_car(parts[0]) if not parts.is_empty() else null
	if data == null:
		return null
	var paint_index: int = clampi(parts[1].to_int(), 0, GameState.CAR_PAINTS.size() - 1) if parts.size() > 1 else 0
	var neon_index: int = clampi(parts[2].to_int(), -1, GameState.CAR_NEONS.size() - 1) if parts.size() > 2 else -1
	var car_tuning: Dictionary = {}
	for i in GameState.CAR_TUNING.size():
		if parts.size() > 3 + i:
			car_tuning[GameState.CAR_TUNING[i]] = clampi(parts[3 + i].to_int(), 0, GameState.CAR_TUNING_MAX)
	var neon_color: Color = GameState.CAR_NEONS[neon_index] if neon_index >= 0 else Color(0.0, 0.0, 0.0, 0.0)
	return create(data, car_tuning, GameState.CAR_PAINTS[paint_index], neon_color)


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = PhysicsLayers.WORLD
	collision_mask = PhysicsLayers.WORLD
	floor_snap_length = 0.5
	_apply_car_data()
	_build_model()
	_build_collision()
	_build_bumper()
	_build_camera()
	_build_headlights()
	_build_smoke()
	_build_neon()
	_apply_garage()
	_apply_tuning()
	_safe_position = global_position
	_net_position = global_position
	_net_yaw = rotation.y


func is_driven() -> bool:
	return _driven


## Кто-то за рулём (свой игрок или, по сети, другой)
func has_driver() -> bool:
	return _driven or seats[0] != 0


## По сети: есть свободное место (водителя или пассажира)
func has_free_seat() -> bool:
	return seats.has(0)


## Свой игрок едет пассажиром
func is_passenger_inside() -> bool:
	return _inside and not _driven


## Боковое скольжение — машина в заносе
func is_drifting() -> bool:
	return absf(lateral) > DRIFT_LATERAL and absf(speed) > DRIFT_MIN_SPEED


## Высота крыши (DriveController ставит туда спрятанного игрока, чтобы зомби его видели)
func get_roof_height() -> float:
	return _box_center.y + _box_size.y * 0.5


func get_speed_kmh() -> float:
	return Vector2(speed, lateral).length() * 3.6


func get_title() -> String:
	return car_data.title if car_data != null else "МАШИНА"


## Точка выхода — слева от машины (пассажиры справа и сзади)
func get_exit_position(seat: int = 0) -> Vector3:
	var side: float = -1.0 if seat % 2 == 0 else 1.0
	var back: float = 0.0 if seat < 2 else _box_size.z * 0.3
	return global_position + global_basis.x * side * (_box_size.x * 0.5 + 1.0) \
		+ global_basis.z * back + Vector3.UP * 0.2


## Сесть: водителем (управление) или пассажиром (только камера)
func enter(as_driver: bool = true) -> void:
	_driven = as_driver
	_inside = true
	_steer = 0.0
	_throttle = 0.0
	_handbrake = false
	if camera != null:
		_snap_camera()
		camera.make_current()
	driver_changed.emit(as_driver)


func exit() -> void:
	var was_driver: bool = _driven
	_driven = false
	_inside = false
	_steer = 0.0
	_throttle = 0.0
	_handbrake = false
	if was_driver and Net.in_match:
		_send_state()  # последняя точка — машина остановится у всех там же
	driver_changed.emit(false)


## steer: -1 влево .. 1 вправо; throttle: 1 газ .. -1 тормоз/назад
func set_input(steer: float, throttle: float) -> void:
	_steer = clampf(steer, -1.0, 1.0)
	_throttle = clampf(throttle, -1.0, 1.0)


func set_handbrake(pressed: bool) -> void:
	_handbrake = pressed


## Места по сети (рассылает хост). Свой игрок садится/выходит в DriveController по сигналу
func set_seats(new_seats: PackedInt32Array) -> void:
	if new_seats.size() != SEAT_COUNT:
		push_warning("DrivableCar '%s': неверные места %s" % [name, new_seats])
		return
	var had_driver: int = seats[0]
	seats = new_seats.duplicate()
	if had_driver != seats[0]:
		_net_has_state = false
		_net_position = global_position
		_net_yaw = rotation.y
	seats_changed.emit()


func get_seat_of(peer_id: int) -> int:
	return seats.find(peer_id)


func _physics_process(delta: float) -> void:
	_time += delta
	if _is_net_copy():
		_copy_physics(delta)
		return
	_check_fall()
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = minf(velocity.y, 0.0)

	var throttle: float = _throttle if _driven else 0.0
	var handbrake: bool = _driven and _handbrake
	if throttle > 0.0:
		var rate: float = brake_power if speed < 0.0 else acceleration
		speed = move_toward(speed, max_speed, rate * throttle * delta)
	elif throttle < 0.0:
		var rate_back: float = brake_power if speed > 0.0 else acceleration * 0.6
		speed = move_toward(speed, -max_reverse_speed, rate_back * -throttle * delta)
	else:
		speed = move_toward(speed, 0.0, drag * delta)
	if handbrake:
		speed = move_toward(speed, 0.0, HANDBRAKE_DRAG * delta)
	_braking = handbrake or (throttle < 0.0 and speed > 0.5) or (throttle > 0.0 and speed < -0.5)

	# Скорость в мире до поворота: после поворота её часть уходит вбок — это и есть занос
	var planar: Vector3 = -global_basis.z * speed + global_basis.x * lateral
	# Руль работает только в движении; назад — в обратную сторону
	var steer_power: float = clampf(absf(speed) / full_steer_speed, 0.0, 1.0)
	if _driven and steer_power > 0.0:
		var boost: float = HANDBRAKE_STEER if handbrake else 1.0
		rotate_y(-_steer * steer_rate * boost * steer_power * signf(speed) * delta)
	var forward: Vector3 = -global_basis.z
	var right: Vector3 = global_basis.x
	speed = planar.dot(forward)
	lateral = planar.dot(right)

	# Сцепление гасит скольжение: на ручнике и в резком повороте на скорости — слабее (дрифт)
	var current_grip: float = grip
	if handbrake:
		current_grip = drift_grip
	elif _driven and absf(_steer) > POWER_SLIDE_STEER and absf(speed) > max_speed * POWER_SLIDE_SPEED:
		current_grip = lerpf(grip, drift_grip, 0.6)
	lateral *= exp(-current_grip * delta)
	speed = move_toward(speed, 0.0, absf(lateral) * SLIDE_SCRUB * delta)

	var moving: Vector3 = forward * speed + right * lateral
	velocity.x = moving.x
	velocity.z = moving.z
	move_and_slide()
	_check_walls(forward, right)
	if _driven:
		_run_over()
		if Net.in_match:
			_net_timer -= delta
			if _net_timer <= 0.0:
				_net_timer = NET_INTERVAL
				_send_state()


func _process(delta: float) -> void:
	_update_lights()
	_update_smoke()
	if camera == null or not _inside:
		return
	var target: Vector3 = _camera_target()
	camera.global_position = camera.global_position.lerp(target, clampf(camera_smooth * delta, 0.0, 1.0))
	camera.look_at(global_position + Vector3.UP * 1.2, Vector3.UP)


## Упала за карту — вернуть на место последней стоянки на земле
func _check_fall() -> void:
	if global_position.y < FALL_LIMIT_Y:
		global_position = _safe_position + Vector3.UP * 1.0
		velocity = Vector3.ZERO
		speed = 0.0
		lateral = 0.0
		return
	if is_on_floor() and fmod(_time, 0.5) < get_physics_process_delta_time():
		_safe_position = global_position


## Удар о стену гасит скорость (иначе машина «скользит» вдоль домов на полном ходу);
## боком о стену — гасит занос
func _check_walls(forward: Vector3, right: Vector3) -> void:
	for i in get_slide_collision_count():
		var collision: KinematicCollision3D = get_slide_collision(i)
		var normal: Vector3 = collision.get_normal()
		if absf(normal.y) >= 0.5:
			continue
		if absf(forward.dot(normal)) > 0.5:
			speed *= WALL_SLOWDOWN
			return
		if absf(right.dot(normal)) > 0.5:
			lateral *= 0.2


func _run_over() -> void:
	var impact_speed: float = Vector2(speed, lateral).length()
	if impact_speed < run_over_min_speed or not _bumper.has_overlapping_bodies():
		return
	for body: Node3D in _bumper.get_overlapping_bodies():
		var zombie := body as Zombie
		if zombie == null or zombie.state == Zombie.State.DEAD:
			continue
		var id: int = zombie.get_instance_id()
		if _time - float(_recent_hits.get(id, -10.0)) < HIT_COOLDOWN:
			continue
		_recent_hits[id] = _time
		var push: Vector3 = velocity * Vector3(1.0, 0.0, 1.0)
		zombie.hit_by_vehicle(impact_speed * run_over_damage_factor, push)
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


# ---------- Свет и дым ----------

## Фары горят, пока в машине кто-то есть: днём слабо, ночью ярко освещают улицу
func _update_lights() -> void:
	var occupied: bool = _inside or (Net.in_match and seats[0] != 0)
	var night: float = DayNightCycle.night_amount
	if occupied != _lights_on:
		_lights_on = occupied
		for light: SpotLight3D in _headlights:
			light.visible = occupied
		if _fill_light != null:
			_fill_light.visible = occupied
		if _neon_light != null:
			_neon_light.visible = occupied
		if _headlight_material != null:
			_headlight_material.emission_energy_multiplier = 3.0 if occupied else 0.0
	if occupied:
		var energy: float = lerpf(HEADLIGHT_DAY_ENERGY, HEADLIGHT_NIGHT_ENERGY, night)
		if not _headlights.is_empty() and not is_equal_approx(_headlights[0].light_energy, energy):
			for light: SpotLight3D in _headlights:
				light.light_energy = energy
			if _fill_light != null:
				_fill_light.light_energy = FILL_LIGHT_NIGHT_ENERGY * night
	var braking: bool = occupied and (_braking if not _is_net_copy() else (_net_flags & 1) != 0)
	if braking != _braking_shown():
		if _brake_light != null:
			_brake_light.visible = braking
		if _brake_material != null:
			_brake_material.emission_energy_multiplier = 4.0 if braking else 0.6


func _braking_shown() -> bool:
	return _brake_light != null and _brake_light.visible


func _update_smoke() -> void:
	var smoking: bool = is_drifting() and is_on_floor()
	if smoking == _smoking:
		return
	_smoking = smoking
	for particles: CPUParticles3D in _smoke:
		particles.emitting = smoking


# ---------- Сеть ----------

## Копия чужой машины: её ведёт другой игрок
func _is_net_copy() -> bool:
	return Net.in_match and seats[0] != 0 and seats[0] != Net.my_id()


func _send_state() -> void:
	_net_buffer.resize(NET_STATE_SIZE)
	var p: Vector3 = global_position
	_net_buffer[0] = p.x
	_net_buffer[1] = p.y
	_net_buffer[2] = p.z
	_net_buffer[3] = rotation.y
	_net_buffer[4] = speed
	_net_buffer[5] = lateral
	_net_buffer[6] = float((1 if _braking else 0) | (2 if _handbrake else 0))
	_net_buffer[7] = _steer
	Net.rpc_car_state.rpc(get_path(), _net_buffer)


## Состояние от водителя (только он может присылать)
func net_apply_state(sender: int, state: PackedFloat32Array) -> void:
	if state.size() < NET_STATE_SIZE or sender != seats[0] or sender == Net.my_id():
		return
	_net_position = Vector3(state[0], state[1], state[2])
	_net_yaw = state[3]
	speed = state[4]
	lateral = state[5]
	_net_flags = int(state[6])
	if not _net_has_state or global_position.distance_to(_net_position) > NET_SNAP_DISTANCE:
		_net_has_state = true
		global_position = _net_position
		rotation.y = _net_yaw


## Копия: предсказываем по скорости и плавно догоняем присланное
func _copy_physics(delta: float) -> void:
	if not _net_has_state:
		return
	var basis_now := Basis(Vector3.UP, _net_yaw)
	_net_position += (-basis_now.z * speed + basis_now.x * lateral) * delta
	var weight: float = clampf(10.0 * delta, 0.0, 1.0)
	global_position = global_position.lerp(_net_position, weight)
	rotation.y = lerp_angle(rotation.y, _net_yaw, weight)
	velocity = Vector3.ZERO


# ---------- Сборка ----------

func _apply_car_data() -> void:
	if car_data == null:
		return
	if car_data.model_scene != null:
		model_scene = car_data.model_scene
	model_scale = car_data.model_scale
	max_speed = car_data.max_speed
	max_reverse_speed = car_data.max_reverse_speed
	acceleration = car_data.acceleration
	brake_power = car_data.brake_power
	steer_rate = car_data.steer_rate
	grip = car_data.grip
	drift_grip = car_data.drift_grip
	run_over_damage_factor = car_data.run_over_damage_factor


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
	_setup_materials(model)


## Покраска кузова модели Quaternius: меш с несколькими материалами — кузов (колёса — один материал, их не красим).
## Атлас текстуры умножается на цвет; белый — заводской цвет
static func paint_body(model: Node3D, paint_color: Color) -> void:
	if model == null or paint_color == Color.WHITE:
		return
	var painted: StandardMaterial3D
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() < 2:
			continue
		for i in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(i) as StandardMaterial3D
			if material == null or material.resource_name in ["Headlights", "BrakeLight"]:
				continue
			if painted == null:
				painted = material.duplicate() as StandardMaterial3D
				painted.albedo_color = material.albedo_color * paint_color
			mesh_instance.set_surface_override_material(i, painted)


## Покраска кузова и светящиеся фары/стоп-сигналы (материалы Headlights, BrakeLight моделей Quaternius)
func _setup_materials(model: Node3D) -> void:
	paint_body(model, paint)
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for i in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(i) as StandardMaterial3D
			if material == null:
				continue
			match material.resource_name:
				"Headlights":
					if _headlight_material == null:
						_headlight_material = material.duplicate() as StandardMaterial3D
						_headlight_material.emission_enabled = true
						_headlight_material.emission = HEADLIGHT_COLOR
						_headlight_material.emission_energy_multiplier = 0.0
					mesh_instance.set_surface_override_material(i, _headlight_material)
				"BrakeLight":
					if _brake_material == null:
						_brake_material = material.duplicate() as StandardMaterial3D
						_brake_material.emission_enabled = true
						_brake_material.emission = BRAKE_COLOR
						_brake_material.emission_energy_multiplier = 0.6
					mesh_instance.set_surface_override_material(i, _brake_material)


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


## Улучшения гаража базы из GameState (на все машины)
func _apply_garage() -> void:
	var engine: int = GameState.get_car_upgrade_level("engine")
	var ram: int = GameState.get_car_upgrade_level("ram")
	max_speed *= 1.0 + ENGINE_PER_LEVEL * engine
	acceleration *= 1.0 + ENGINE_PER_LEVEL * engine
	run_over_damage_factor *= 1.0 + RAM_PER_LEVEL * ram
	_hit_slowdown = minf(HIT_SLOWDOWN + 0.015 * ram, 0.98)


## Тюнинг автосалона этой машины
func _apply_tuning() -> void:
	max_speed *= 1.0 + TUNE_ENGINE * int(tuning.get("engine", 0))
	acceleration *= 1.0 + TUNE_TURBO * int(tuning.get("turbo", 0))
	var handling: int = int(tuning.get("handling", 0))
	steer_rate *= 1.0 + TUNE_STEER * handling
	grip *= 1.0 + TUNE_GRIP * handling
	run_over_damage_factor *= 1.0 + TUNE_RAM * int(tuning.get("ram", 0))


## Две фары и рассеянный свет перед капотом (горят, пока в машине кто-то есть), стоп-сигнал
func _build_headlights() -> void:
	var front_z: float = _box_center.z - _box_size.z * 0.5
	for side: float in [-1.0, 1.0]:
		var light := SpotLight3D.new()
		light.light_color = HEADLIGHT_COLOR
		light.light_energy = HEADLIGHT_DAY_ENERGY
		light.spot_range = HEADLIGHT_RANGE
		light.spot_angle = HEADLIGHT_ANGLE
		light.spot_attenuation = 0.8
		light.shadow_enabled = false
		light.visible = false
		light.position = Vector3(side * _box_size.x * 0.3, _box_center.y, front_z)
		light.rotation.x = deg_to_rad(-7.0)
		add_child(light)
		_headlights.append(light)
	_fill_light = OmniLight3D.new()
	_fill_light.light_color = HEADLIGHT_COLOR
	_fill_light.light_energy = 0.0
	_fill_light.omni_range = FILL_LIGHT_RANGE
	_fill_light.shadow_enabled = false
	_fill_light.visible = false
	_fill_light.position = Vector3(0.0, 2.2, front_z - 5.0)
	add_child(_fill_light)
	_brake_light = OmniLight3D.new()
	_brake_light.light_color = BRAKE_COLOR
	_brake_light.light_energy = 1.2
	_brake_light.omni_range = 4.0
	_brake_light.shadow_enabled = false
	_brake_light.visible = false
	_brake_light.position = Vector3(0.0, _box_center.y, _box_center.z + _box_size.z * 0.5 + 0.4)
	add_child(_brake_light)


## Дым из-под задних колёс в заносе
func _build_smoke() -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	var quad := QuadMesh.new()
	quad.size = Vector2(1.2, 1.2)
	quad.material = material
	var fade := Gradient.new()
	fade.set_color(0, Color(0.85, 0.85, 0.85, 0.5))
	fade.set_color(1, Color(0.7, 0.7, 0.7, 0.0))
	var rear_z: float = _box_center.z + _box_size.z * 0.4
	for side: float in [-1.0, 1.0]:
		var particles := CPUParticles3D.new()
		particles.mesh = quad
		particles.emitting = false
		particles.amount = 14
		particles.lifetime = 0.9
		particles.local_coords = false
		particles.direction = Vector3.UP
		particles.spread = 35.0
		particles.initial_velocity_min = 0.6
		particles.initial_velocity_max = 1.6
		particles.gravity = Vector3(0.0, 0.6, 0.0)
		particles.scale_amount_min = 0.6
		particles.scale_amount_max = 1.6
		particles.color_ramp = fade
		particles.position = Vector3(side * _box_size.x * 0.4, 0.25, rear_z)
		add_child(particles)
		_smoke.append(particles)


## Неон под днищем (тюнинг автосалона)
func _build_neon() -> void:
	if neon.a <= 0.0:
		return
	_neon_light = OmniLight3D.new()
	_neon_light.light_color = Color(neon, 1.0)
	_neon_light.light_energy = 2.5
	_neon_light.omni_range = maxf(_box_size.z * 0.75, 3.0)
	_neon_light.shadow_enabled = false
	_neon_light.position = Vector3(0.0, 0.25, _box_center.z)
	_neon_light.visible = false
	add_child(_neon_light)


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
