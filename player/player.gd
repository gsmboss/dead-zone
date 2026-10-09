class_name Player
extends CharacterBody3D
## FPS-контроллер: тач (джойстик + свайп) и клавиатура для теста на ПК.
## Выносливость: бег (Shift или джойстик до упора вперёд) и подкат (C / кнопка ПОДКАТ).

signal stamina_changed(current: float, max_value: float)

@export var touch_controls: TouchControls
## Пусто → ищется по пути Head/Camera3D/WeaponManager
@export var weapon_manager: WeaponManager
## Пусто → дочерняя нода "Health"
@export var health: Health

@export_group("Movement")
@export var move_speed: float = 5.5
@export var acceleration: float = 30.0
@export_range(0.0, 1.0, 0.05) var air_control: float = 0.3
@export var jump_velocity: float = 4.8

@export_group("Sprint & Slide")
@export var sprint_multiplier: float = 1.6
@export var stamina_max: float = 100.0
## Расход выносливости на бег в секунду и восстановление
@export var stamina_drain: float = 20.0
@export var stamina_regen: float = 16.0
## Пауза перед восстановлением после траты
@export var stamina_regen_delay: float = 0.8
@export var slide_speed: float = 11.0
@export var slide_time: float = 0.55
@export var slide_cost: float = 25.0
## Камера опускается в подкате
@export var slide_camera_drop: float = 0.6
## На телефоне: джойстик вперёд сильнее этого — бег
@export_range(0.5, 1.0, 0.01) var touch_sprint_threshold: float = 0.93

@export_group("Fall Safety")
## Ниже этой высоты игрок считается упавшим за карту и возвращается на землю
@export var fall_limit_y: float = -12.0

@export_group("Look")
## Поворот в градусах за свайп на всю высоту экрана
@export_range(30.0, 720.0, 5.0) var look_sensitivity: float = 180.0
@export var invert_y: bool = false
@export_range(-89.0, 0.0) var min_pitch: float = -85.0
@export_range(0.0, 89.0) var max_pitch: float = 85.0

@export_group("Recoil")
## Скорость возврата камеры после отдачи
@export var recoil_recovery: float = 9.0
@export_range(0.0, 30.0) var max_recoil_pitch: float = 12.0

@export_group("Head Bob")
@export var bob_enabled: bool = true
@export var bob_frequency: float = 2.2
@export var bob_amplitude: float = 0.04

@export_group("Camera Shake")
@export var shake_max_offset: float = 0.12
@export var shake_decay: float = 3.0

@export_group("Audio")
@export_range(-40.0, 0.0, 0.5) var footstep_volume_db: float = -14.0

## Отключение управления (смерть, пауза, катсцены)
var input_enabled: bool = true
## Мультиплеер: копия другого игрока (без ввода, камеры и оружия; позиция из сети)
var is_remote: bool = false
var peer_id: int = 0
var _net_position: Vector3 = Vector3.ZERO
var _net_yaw: float = 0.0
var _net_pitch: float = 0.0
var _net_speed: float = 0.0
var _net_on_floor: bool = true
var _net_has_state: bool = false
var _head_base_y: float = 1.6

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _pitch: float = 0.0
var _recoil_pitch: float = 0.0
var _bob_time: float = 0.0
var _last_bob_sin: float = 0.0
var stamina: float = 100.0
var sprinting: bool = false
var _stamina_delay: float = 0.0
var _slide_left: float = 0.0
var _slide_direction: Vector3 = Vector3.ZERO
var _last_stamina_emit: float = -1.0
## Последняя точка, где игрок стоял на полу (для возврата при падении за карту)
var _safe_position: Vector3 = Vector3.ZERO
var _safe_timer: float = 0.0
const SAFE_POSITION_INTERVAL: float = 0.3
var _camera_base_y: float = 0.0
var _camera_base_x: float = 0.0
var _shake: float = 0.0
# Толчок камеры при уроне
const HIT_SHAKE_DAMAGE: float = 35.0
const HIT_SHAKE_AMOUNT: float = 0.55
const HIT_ROLL_DEGREES: float = 6.0
const HIT_PITCH_DEGREES: float = 3.0
const HIT_KICK_RECOVERY: float = 7.0
var _hit_roll: float = 0.0
var _hit_pitch: float = 0.0
var _rng := RandomNumberGenerator.new()
# Гироскоп: опрос с частотой Settings.gyro_rate, сглаженная скорость поворота (рад/с)
var _gyro_timer: float = 0.0
var _gyro_rate: Vector2 = Vector2.ZERO
## Ниже этой скорости (рад/с) дрожание рук не крутит камеру
const GYRO_DEADZONE: float = 0.015

# Вид от 3-го лица: камера на «пружине» за правым плечом (не проходит сквозь стены)
const SHOULDER_OFFSET: Vector3 = Vector3(0.55, 0.15, 0.0)
const CAMERA_PROBE_RADIUS: float = 0.2
## Тело игрока (видно от 3-го лица и другим игрокам)
var body: PlayerBody
var third_person: bool = false
var _spring: SpringArm3D
var _camera_pivot: Node3D
var _camera_fps_position: Vector3 = Vector3.ZERO
var _weapons_enabled: bool = true
## Факел (если куплен в оружейной)
var torch: Torch
## Ночь по мнению автофакела (с запасом: зажигается после NIGHT_ON, гаснет до NIGHT_OFF)
const TORCH_NIGHT_ON: float = 0.5
const TORCH_NIGHT_OFF: float = 0.3
var _torch_night: bool = false

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D


func _ready() -> void:
	if is_remote:
		_ready_remote()
		return
	add_to_group(&"player")
	collision_layer = PhysicsLayers.PLAYER
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.ENEMY

	if touch_controls == null:
		push_warning("Player: touch_controls не назначен — работает только клавиатура")
	if weapon_manager == null:
		weapon_manager = get_node_or_null(^"Head/Camera3D/WeaponManager") as WeaponManager
	if health == null:
		health = get_node_or_null(^"Health") as Health
	if health == null:
		push_warning("Player: нет ноды Health — игрок бессмертен")
	else:
		# Улучшения «Выжившего» из оружейной
		health.max_health = GameState.get_player_max_health()
		health.damage_reduction = GameState.get_player_armor()
		health.reset()
		health.died.connect(_on_died)
		health.damaged.connect(_on_damaged)
	_camera_base_y = camera.position.y
	_camera_base_x = camera.position.x
	_camera_fps_position = camera.position
	_head_base_y = head.position.y
	_setup_body()
	_setup_spring_arm()
	_setup_torch()
	_rng.randomize()
	_apply_settings()
	Settings.changed.connect(_apply_settings)
	stamina = stamina_max
	_safe_position = global_position


func _process(delta: float) -> void:
	if is_remote:
		return
	if touch_controls != null:
		var look: Vector2 = touch_controls.consume_look_delta()
		# Пока управление выключено, свайпы просто сбрасываются
		if input_enabled and look != Vector2.ZERO:
			_apply_look(look)
	_process_gyro(delta)
	if input_enabled and torch != null and Input.is_action_just_pressed(&"torch"):
		torch.toggle()
	_update_auto_torch()
	if input_enabled and Input.is_action_just_pressed(&"camera_view"):
		Settings.set_value(&"camera_mode", 1 - Settings.camera_mode)
	_update_recoil(delta)
	_update_shake(delta)
	_update_hit_kick(delta)
	if third_person:
		_update_third_person_camera()


func _physics_process(delta: float) -> void:
	if is_remote:
		_remote_physics(delta)
		return
	_check_fall(delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var input_dir: Vector2 = Vector2.ZERO
	if input_enabled:
		if Input.is_action_just_pressed(&"jump") and is_on_floor() and _slide_left <= 0.0:
			velocity.y = jump_velocity
		input_dir = _get_move_input()

	_update_stamina(input_dir, delta)
	if _slide_left > 0.0:
		_process_slide(delta)
		return

	# Аналоговое движение: длина вектора сохраняется (не normalize)
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).limit_length(1.0)
	var speed: float = move_speed * (sprint_multiplier if sprinting else 1.0)
	var target: Vector2 = Vector2(direction.x, direction.z) * speed
	var accel: float = acceleration if is_on_floor() else acceleration * air_control

	var horizontal: Vector2 = Vector2(velocity.x, velocity.z).move_toward(target, accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y

	move_and_slide()
	_update_head_bob(delta, horizontal.length())


## Тряска камеры (удар босса, взрыв). strength 0..1, складывается
func shake(strength: float) -> void:
	_shake = clampf(_shake + strength * Settings.camera_shake, 0.0, 1.0)


## Чувствительность и инверсия из настроек игрока
func _apply_settings() -> void:
	look_sensitivity = Settings.look_sensitivity
	invert_y = Settings.invert_y
	if _spring != null:
		_spring.spring_length = Settings.camera_distance
	set_third_person(Settings.camera_mode == Settings.CameraMode.THIRD_PERSON)


# ---------- Мультиплеер ----------

func _ready_remote() -> void:
	add_to_group(&"remote_player")
	collision_layer = PhysicsLayers.PLAYER
	collision_mask = PhysicsLayers.WORLD
	input_enabled = false
	weapon_manager = null
	if health == null:
		health = get_node_or_null(^"Health") as Health
	camera.current = false
	_setup_body()
	body.visible = true
	_net_position = global_position
	_net_yaw = rotation.y


## Состояние другого игрока из сети
func apply_net_state(position_value: Vector3, yaw: float, pitch: float, speed: float, on_floor: bool) -> void:
	_net_position = position_value
	_net_yaw = yaw
	_net_pitch = pitch
	_net_speed = speed
	_net_on_floor = on_floor
	if not _net_has_state:
		_net_has_state = true
		global_position = position_value
		rotation.y = yaw


func _remote_physics(delta: float) -> void:
	var weight: float = clampf(12.0 * delta, 0.0, 1.0)
	if global_position.distance_squared_to(_net_position) > 25.0:
		global_position = _net_position  # возрождение или сильный лаг — без «полёта»
	else:
		global_position = global_position.lerp(_net_position, weight)
	rotation.y = lerp_angle(rotation.y, _net_yaw, weight)
	head.rotation.x = lerp_angle(head.rotation.x, deg_to_rad(_net_pitch), weight)
	if body != null:
		body.update_motion(_net_speed, _net_on_floor, delta)


## Поворот камеры по вертикали (для отправки по сети), градусы
func get_pitch() -> float:
	return _pitch


## Возрождение в точке at (мультиплеер)
func respawn(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	_safe_position = at
	_slide_left = 0.0
	if health != null:
		health.reset()
	input_enabled = true
	head.position.y = _head_base_y
	head.rotation.z = 0.0
	_hit_roll = 0.0
	_hit_pitch = 0.0
	camera.rotation = Vector3.ZERO
	if touch_controls != null:
		touch_controls.show()
	if body != null:
		body.revive()
	if weapon_manager != null:
		weapon_manager.add_reserve_ammo(1.0)
	stamina = stamina_max


# ---------- Вид от 1-го / 3-го лица ----------

func set_third_person(enabled: bool) -> void:
	if body == null or _spring == null:
		return
	third_person = enabled
	body.visible = enabled
	if weapon_manager != null:
		weapon_manager.visible = _weapons_enabled and not enabled
	if not enabled:
		camera.position = _camera_fps_position
		_camera_base_x = _camera_fps_position.x
		_camera_base_y = _camera_fps_position.y


## Оружие включено (в убежище — нет): вью-модель, стрельба и оружие в руке тела
func set_weapons_enabled(enabled: bool) -> void:
	_weapons_enabled = enabled
	if weapon_manager == null:
		return
	weapon_manager.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	weapon_manager.visible = enabled and not third_person
	if body != null:
		# В убежище стрелять нельзя, но ствол в руке видно (вид от 3-го лица)
		body.set_weapon(weapon_manager.get_current_weapon())


func _setup_body() -> void:
	body = PlayerBody.new()
	body.name = "Body"
	add_child(body)
	body.visible = false
	if not is_remote:
		body.set_skin(GameState.get_selected_skin())
		GameState.skin_changed.connect(_on_skin_changed)
	if weapon_manager != null:
		weapon_manager.weapon_changed.connect(_on_weapon_changed)
		weapon_manager.fired.connect(body.on_fired)
		body.set_weapon(weapon_manager.get_current_weapon())
	if health != null:
		health.damaged.connect(func(_a: float, _p: Vector3, _h: bool) -> void: body.on_hit())
		health.died.connect(body.on_died)


## Ночью факел загорается сам, на рассвете гаснет (между этим — как включил игрок)
func _update_auto_torch() -> void:
	if torch == null or not Settings.torch_auto:
		return
	var night: float = DayNightCycle.night_amount
	if not _torch_night and night >= TORCH_NIGHT_ON:
		_torch_night = true
		if not torch.lit:
			torch.set_lit(true)
	elif _torch_night and night <= TORCH_NIGHT_OFF:
		_torch_night = false
		if torch.lit:
			torch.set_lit(false)


func _setup_torch() -> void:
	GameState.gear_changed.connect(_on_gear_changed)
	_on_gear_changed()


func _on_gear_changed() -> void:
	if torch == null and GameState.owns_gear("torch"):
		torch = Torch.new()
		torch.name = "Torch"
		head.add_child(torch)


func _setup_spring_arm() -> void:
	_spring = SpringArm3D.new()
	_spring.name = "CameraArm"
	_spring.position = SHOULDER_OFFSET
	_spring.spring_length = Settings.camera_distance
	_spring.collision_mask = PhysicsLayers.WORLD
	_spring.margin = 0.1
	var probe := SphereShape3D.new()
	probe.radius = CAMERA_PROBE_RADIUS
	_spring.shape = probe
	_spring.add_excluded_object(get_rid())
	head.add_child(_spring)
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPivot"
	_spring.add_child(_camera_pivot)


## Камера в точке «пружины» (в осях головы, как и сама камера)
func _update_third_person_camera() -> void:
	var local: Vector3 = _spring.transform * _camera_pivot.position
	_camera_base_x = local.x
	_camera_base_y = local.y
	camera.position.z = local.z
	camera.position.y = local.y
	if _shake <= 0.0:
		camera.position.x = local.x


func _on_skin_changed(skin: PlayerSkin) -> void:
	if body == null:
		return
	body.set_skin(skin)
	if weapon_manager != null:
		body.set_weapon(weapon_manager.get_current_weapon())


func _on_weapon_changed(weapon: WeaponData) -> void:
	if body != null:
		body.set_weapon(weapon)


## Отбрасывание (рывок и удар босса)
func apply_knockback(impulse: Vector3) -> void:
	velocity += impulse


## Вызывается оружием при выстреле
func add_recoil(pitch_deg: float, yaw_deg: float) -> void:
	_recoil_pitch = clampf(_recoil_pitch + pitch_deg, 0.0, max_recoil_pitch)
	rotate_y(deg_to_rad(yaw_deg))
	_update_head_rotation()


# ---------- Защита от падения за карту ----------

## Запоминает безопасную точку на полу; упавшего ниже fall_limit_y возвращает туда
func _check_fall(delta: float) -> void:
	if global_position.y < fall_limit_y:
		global_position = _safe_position + Vector3.UP * 0.5
		velocity = Vector3.ZERO
		_slide_left = 0.0
		push_warning("Player: упал за карту, возвращён на %s" % _safe_position)
		return
	_safe_timer -= delta
	if _safe_timer <= 0.0 and is_on_floor():
		_safe_timer = SAFE_POSITION_INTERVAL
		_safe_position = global_position


## Сменить безопасную точку вручную (выход из машины и т.п.)
func set_safe_position(point: Vector3) -> void:
	_safe_position = point


# ---------- Бег и подкат ----------

func _update_stamina(input_dir: Vector2, delta: float) -> void:
	var wants_sprint: bool = false
	if input_enabled and is_on_floor() and input_dir.y < -0.5:
		wants_sprint = Input.is_action_pressed(&"sprint")
		if touch_controls != null and touch_controls.get_move_vector().y <= -touch_sprint_threshold:
			wants_sprint = true
	var aiming: bool = weapon_manager != null and weapon_manager.is_aiming()
	sprinting = wants_sprint and not aiming and stamina > 0.0
	if sprinting:
		stamina = maxf(stamina - stamina_drain * delta, 0.0)
		_stamina_delay = stamina_regen_delay
	elif _stamina_delay > 0.0:
		_stamina_delay -= delta
	else:
		stamina = minf(stamina + stamina_regen * delta, stamina_max)

	if input_enabled and Input.is_action_just_pressed(&"slide"):
		_try_slide(input_dir)
	# Сигнал только при заметном изменении (без лишних обновлений HUD)
	if absf(stamina - _last_stamina_emit) >= 0.5 or (stamina >= stamina_max and _last_stamina_emit < stamina_max):
		_last_stamina_emit = stamina
		stamina_changed.emit(stamina, stamina_max)


func _try_slide(input_dir: Vector2) -> void:
	if not is_on_floor() or _slide_left > 0.0 or stamina < slide_cost:
		return
	var horizontal := Vector2(velocity.x, velocity.z)
	if horizontal.length() < move_speed * 0.6 and input_dir.y > -0.3:
		return  # подкат только на бегу вперёд
	stamina -= slide_cost
	_stamina_delay = stamina_regen_delay
	_slide_left = slide_time
	_slide_direction = -global_basis.z
	Sfx.play_2d(Sfx.pick(Sfx.sounds.footsteps), footstep_volume_db + 6.0, 0.7, 0.0)


## Рывок вперёд с опущенной камерой, скорость падает к концу
func _process_slide(delta: float) -> void:
	_slide_left -= delta
	var progress: float = 1.0 - clampf(_slide_left / slide_time, 0.0, 1.0)
	var speed: float = lerpf(slide_speed, move_speed, progress)
	velocity.x = _slide_direction.x * speed
	velocity.z = _slide_direction.z * speed
	move_and_slide()
	var drop: float = slide_camera_drop * sin(progress * PI)
	camera.position.y = _camera_base_y - drop
	if _slide_left <= 0.0:
		camera.position.y = _camera_base_y


func _on_damaged(amount: float, hit_position: Vector3, _is_headshot: bool) -> void:
	Sfx.play_2d(Sfx.pick(Sfx.sounds.player_hurt), -2.0)
	if health != null and health.is_dead:
		return
	# Камера вздрагивает: тряска по силе удара и толчок в сторону от атакующего
	var strength: float = clampf(amount / HIT_SHAKE_DAMAGE, 0.15, 1.0) * Settings.hit_shake
	if strength <= 0.0:
		return
	_shake = clampf(_shake + strength * HIT_SHAKE_AMOUNT, 0.0, 1.0)
	var side: float = 0.0
	if hit_position != Vector3.ZERO:
		var local: Vector3 = global_basis.inverse() * (hit_position - global_position)
		side = clampf(local.x / maxf(Vector2(local.x, local.z).length(), 0.01), -1.0, 1.0)
	# Удар справа валит голову влево и наоборот; удар — ещё и кивок вниз
	_hit_roll = clampf(_hit_roll - side * deg_to_rad(HIT_ROLL_DEGREES) * strength,
		-deg_to_rad(HIT_ROLL_DEGREES * 1.5), deg_to_rad(HIT_ROLL_DEGREES * 1.5))
	_hit_pitch = clampf(_hit_pitch - deg_to_rad(HIT_PITCH_DEGREES) * strength,
		-deg_to_rad(HIT_PITCH_DEGREES * 1.5), 0.0)


## Толчок камеры от удара плавно возвращается (поворот самой камеры, не головы)
func _update_hit_kick(delta: float) -> void:
	if _hit_roll == 0.0 and _hit_pitch == 0.0:
		return
	var weight: float = clampf(HIT_KICK_RECOVERY * delta, 0.0, 1.0)
	_hit_roll = lerpf(_hit_roll, 0.0, weight)
	_hit_pitch = lerpf(_hit_pitch, 0.0, weight)
	if absf(_hit_roll) < 0.0005 and absf(_hit_pitch) < 0.0005:
		_hit_roll = 0.0
		_hit_pitch = 0.0
	camera.rotation.z = _hit_roll
	camera.rotation.x = _hit_pitch


func _on_died() -> void:
	input_enabled = false
	if touch_controls != null:
		touch_controls.hide()  # TouchControls сам отпустит все кнопки
	# Камера «падает» на землю
	var tween := create_tween().set_parallel(true)
	tween.tween_property(head, "position:y", 0.4, 0.6).set_ease(Tween.EASE_IN)
	tween.tween_property(head, "rotation:z", deg_to_rad(35.0), 0.6)


func _get_move_input() -> Vector2:
	var keyboard: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if touch_controls == null:
		return keyboard
	var touch: Vector2 = touch_controls.get_move_vector()
	# Берём более сильный источник, чтобы клавиатура и тач не складывались
	return touch if touch.length() > keyboard.length() else keyboard


func _apply_look(delta_px: Vector2) -> void:
	var screen_height: float = get_viewport().get_visible_rect().size.y
	if screen_height <= 0.0:
		return
	var deg_per_px: float = look_sensitivity / screen_height
	if weapon_manager != null:
		deg_per_px *= weapon_manager.get_aim_slowdown()  # aim assist

	rotate_y(deg_to_rad(-delta_px.x * deg_per_px))

	var dy: float = delta_px.y * deg_per_px * (-1.0 if invert_y else 1.0)
	_pitch = clampf(_pitch - dy, min_pitch, max_pitch)
	_update_head_rotation()


## Обзор наклоном телефона. Опрос со своей частотой (gyro_rate, Гц), поворот за всё
## прошедшее время — скорость камеры не зависит от FPS игры
func _process_gyro(delta: float) -> void:
	if not Settings.gyro_enabled or not input_enabled:
		_gyro_timer = 0.0
		_gyro_rate = Vector2.ZERO
		return
	if Settings.gyro_mode == Settings.GyroMode.AIM_ONLY \
			and (weapon_manager == null or not weapon_manager.is_aiming()):
		_gyro_timer = 0.0
		_gyro_rate = Vector2.ZERO
		return
	_gyro_timer += delta
	var interval: float = 1.0 / float(maxi(Settings.gyro_rate, 1))
	if _gyro_timer < interval:
		return
	var elapsed: float = minf(_gyro_timer, 0.1)  # после лага — без рывка
	_gyro_timer = 0.0
	# Оси экрана: y — поворот влево/вправо, x — наклон вверх/вниз (рад/с)
	var raw: Vector3 = Input.get_gyroscope()
	var sample := Vector2(raw.y, raw.x)
	if absf(sample.x) < GYRO_DEADZONE:
		sample.x = 0.0
	if absf(sample.y) < GYRO_DEADZONE:
		sample.y = 0.0
	_gyro_rate = _gyro_rate.lerp(sample, 1.0 - Settings.gyro_smoothing)
	if _gyro_rate == Vector2.ZERO:
		return
	var yaw: float = _gyro_rate.x * elapsed * Settings.gyro_sensitivity_x * (-1.0 if Settings.gyro_invert_x else 1.0)
	var pitch: float = _gyro_rate.y * elapsed * Settings.gyro_sensitivity_y * (-1.0 if Settings.gyro_invert_y else 1.0)
	rotate_y(yaw)
	_pitch = clampf(_pitch + rad_to_deg(pitch), min_pitch, max_pitch)
	_update_head_rotation()


func _update_recoil(delta: float) -> void:
	if _recoil_pitch <= 0.0:
		return
	_recoil_pitch = lerpf(_recoil_pitch, 0.0, clampf(recoil_recovery * delta, 0.0, 1.0))
	if _recoil_pitch < 0.01:
		_recoil_pitch = 0.0
	_update_head_rotation()


func _update_head_rotation() -> void:
	head.rotation.x = deg_to_rad(clampf(_pitch + _recoil_pitch, min_pitch, max_pitch))


func _update_shake(delta: float) -> void:
	if _shake <= 0.0:
		return
	if health != null and health.is_dead:
		_shake = 0.0  # не мешаем анимации падения камеры
		camera.position.x = _camera_base_x
		return
	_shake = maxf(_shake - shake_decay * delta, 0.0)
	var power: float = _shake * _shake * shake_max_offset
	camera.position.x = _camera_base_x + _rng.randf_range(-power, power)
	head.rotation.z = _rng.randf_range(-power, power) * 0.5
	if _shake <= 0.0:
		camera.position.x = _camera_base_x
		head.rotation.z = 0.0


func _update_head_bob(delta: float, speed: float) -> void:
	if body != null and body.visible:
		body.update_motion(speed, is_on_floor(), delta)
	# От 3-го лица камера не качается (её ставит «пружина»), но шаги звучат так же
	var move_camera: bool = not third_person
	if bob_enabled and is_on_floor() and speed > 0.1:
		_bob_time += delta * bob_frequency * TAU * (speed / move_speed)
		var bob_sin: float = sin(_bob_time)
		if move_camera:
			camera.position.y = _camera_base_y + bob_sin * bob_amplitude
		# Шаг — в нижней точке покачивания
		if _last_bob_sin > 0.0 and bob_sin <= 0.0:
			Sfx.play_2d(Sfx.pick(Sfx.sounds.footsteps), footstep_volume_db, 1.0, 0.1)
		_last_bob_sin = bob_sin
	else:
		_bob_time = 0.0
		_last_bob_sin = 0.0
		if move_camera:
			camera.position.y = lerpf(camera.position.y, _camera_base_y, clampf(10.0 * delta, 0.0, 1.0))
