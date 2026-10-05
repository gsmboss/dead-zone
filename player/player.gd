class_name Player
extends CharacterBody3D
## FPS-контроллер: тач (джойстик + свайп) и клавиатура для теста на ПК.

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

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _pitch: float = 0.0
var _recoil_pitch: float = 0.0
var _bob_time: float = 0.0
var _last_bob_sin: float = 0.0
var _camera_base_y: float = 0.0
var _camera_base_x: float = 0.0
var _shake: float = 0.0
var _rng := RandomNumberGenerator.new()

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D


func _ready() -> void:
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
	_rng.randomize()


func _process(delta: float) -> void:
	if touch_controls != null:
		var look: Vector2 = touch_controls.consume_look_delta()
		# Пока управление выключено, свайпы просто сбрасываются
		if input_enabled and look != Vector2.ZERO:
			_apply_look(look)
	_update_recoil(delta)
	_update_shake(delta)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var input_dir: Vector2 = Vector2.ZERO
	if input_enabled:
		if Input.is_action_just_pressed(&"jump") and is_on_floor():
			velocity.y = jump_velocity
		input_dir = _get_move_input()

	# Аналоговое движение: длина вектора сохраняется (не normalize)
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).limit_length(1.0)
	var target: Vector2 = Vector2(direction.x, direction.z) * move_speed
	var accel: float = acceleration if is_on_floor() else acceleration * air_control

	var horizontal: Vector2 = Vector2(velocity.x, velocity.z).move_toward(target, accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y

	move_and_slide()
	_update_head_bob(delta, horizontal.length())


## Тряска камеры (удар босса, взрыв). strength 0..1, складывается
func shake(strength: float) -> void:
	_shake = clampf(_shake + strength, 0.0, 1.0)


## Отбрасывание (рывок и удар босса)
func apply_knockback(impulse: Vector3) -> void:
	velocity += impulse


## Вызывается оружием при выстреле
func add_recoil(pitch_deg: float, yaw_deg: float) -> void:
	_recoil_pitch = clampf(_recoil_pitch + pitch_deg, 0.0, max_recoil_pitch)
	rotate_y(deg_to_rad(yaw_deg))
	_update_head_rotation()


func _on_damaged(_amount: float, _hit_position: Vector3, _is_headshot: bool) -> void:
	Sfx.play_2d(Sfx.pick(Sfx.sounds.player_hurt), -2.0)


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
	if bob_enabled and is_on_floor() and speed > 0.1:
		_bob_time += delta * bob_frequency * TAU * (speed / move_speed)
		var bob_sin: float = sin(_bob_time)
		camera.position.y = _camera_base_y + bob_sin * bob_amplitude
		# Шаг — в нижней точке покачивания
		if _last_bob_sin > 0.0 and bob_sin <= 0.0:
			Sfx.play_2d(Sfx.pick(Sfx.sounds.footsteps), footstep_volume_db, 1.0, 0.1)
		_last_bob_sin = bob_sin
	else:
		_bob_time = 0.0
		_last_bob_sin = 0.0
		camera.position.y = lerpf(camera.position.y, _camera_base_y, clampf(10.0 * delta, 0.0, 1.0))
