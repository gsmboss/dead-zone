class_name WeaponManager
extends Node3D
## Оружие игрока: стрельба лучом, разброс, дробь, перезарядка,
## смена стволов с моделями, автоогонь и aim assist.
## Стволы берутся из GameState (купленные и улучшенные).
## Должен быть дочерним узлом Camera3D.

signal weapon_changed(weapon: WeaponData)
signal ammo_changed(magazine: int, reserve: int, infinite_reserve: bool)
signal reload_started(duration: float)
signal reload_finished
signal reload_cancelled
signal fired(weapon: WeaponData)
signal hit_landed(is_headshot: bool, killed: bool)
signal aim_changed(aiming: bool)

const SWITCH_DELAY: float = 0.25
const MUZZLE_FLASH_TIME: float = 0.05
const GUN_RETURN_SPEED: float = 14.0
## Вью-модель уменьшается и придвигается к камере в это число раз: на экране она
## выглядит так же (перспектива), но не проходит сквозь стены — тело игрока
## (радиус 0.4) не подпускает стену так близко к камере.
const VIEW_MODEL_SHRINK: float = 0.35
## Оружие опускается при смене (затем поднимается за счёт плавного возврата)
const SWITCH_LOWER_OFFSET: Vector3 = Vector3(0.0, -0.25, 0.0)
## Оружие опущено во время перезарядки
const RELOAD_OFFSET: Vector3 = Vector3(0.0, -0.12, 0.05)
## Пауза между щелчками пустого магазина
const DRY_FIRE_INTERVAL: float = 0.35
## Размер спрайта вспышки (до уменьшения вью-модели), метры
const FLASH_SPRITE_SIZE: float = 0.32
const HIT_SOUND_VOLUME_DB: float = -10.0
# Анимация вью-модели (смещения — до уменьшения VIEW_MODEL_SHRINK)
## Дыхание: амплитуда и частота покачивания на месте
const IDLE_SWAY: Vector2 = Vector2(0.003, 0.004)
const IDLE_SWAY_SPEED: float = 1.6
## Покачивание при ходьбе (на полной скорости) и частота шагов
const WALK_BOB: Vector2 = Vector2(0.014, 0.01)
const WALK_BOB_SPEED: float = 9.0
## Наклон модели в середине перезарядки, градусы
const RELOAD_TILT_DEGREES: Vector3 = Vector3(-28.0, 12.0, 22.0)
# Прицеливание
## Скорость перехода в прицел и обратно (доля в секунду)
const ADS_SPEED: float = 7.0
## Оружие в прицеле: выше и ближе к камере (до уменьшения вью-модели)
const ADS_RAISE: Vector3 = Vector3(0.0, 0.05, 0.06)
## Покачивание в прицеле слабее
const ADS_SWAY_FACTOR: float = 0.25
## Затухание расхождения прицела, градусов в секунду
const BLOOM_DECAY: float = 6.0
## Доп. разброс при беге (доля от spread_degrees на полной скорости)
const MOVE_SPREAD_FACTOR: float = 0.8
## Огнемёт: струя горит ещё столько после последнего «выстрела»
const FLAME_HOLD_TIME: float = 0.15
## Длительность замаха и возврата модели ближнего боя (доли интервала удара)
const SWING_OUT_SHARE: float = 0.35
const SWING_BACK_SHARE: float = 0.5

## Запасной список, если в сохранении нет купленного оружия
@export var weapons: Array[WeaponData] = []
## Брать стволы из сохранения (купленные + улучшения)
@export var use_game_state_loadout: bool = true

@export_group("References (optional)")
## Пусто → корень сцены (Player)
@export var player: Player
## Пусто → родительская Camera3D
@export var camera: Camera3D
## Запасная модель (брусок), если у оружия нет view_model. Пусто → нода "Gun"
@export var gun_model: Node3D
## Пусто → нода "Gun/MuzzleFlash"
@export var muzzle_flash: Light3D

@export_group("Auto Fire / Aim Assist")
@export var auto_fire_enabled: bool = true
## Задержка перед автоогнём после наведения (от случайных выстрелов)
@export_range(0.0, 1.0, 0.01) var auto_fire_delay: float = 0.12
## Множитель скорости обзора, когда прицел на цели
@export_range(0.1, 1.0, 0.05) var aim_assist_slowdown: float = 0.55

var _index: int = -1
var _magazine: Array[int] = []
var _reserve: Array[int] = []
var _cooldown: float = 0.0
var _reload_left: float = 0.0
var _target_in_sight: bool = false
var _target_time: float = 0.0
var _flash_left: float = 0.0
var _impacts: ImpactPool
var _flash_sprite: MeshInstance3D
var _reload_player: AudioStreamPlayer
var _reload_stream: AudioStream
var _hit_sound_played: bool = false
var _swing_tween: Tween
var _flame_particles: CPUParticles3D
var _flame_sound: AudioStreamPlayer
var _flame_time: float = 0.0
var _reload_total: float = 0.0
var _model_base_rotation: Vector3 = Vector3.ZERO
var _anim_time: float = 0.0
var _bob_phase: float = 0.0
var _speed_ratio: float = 0.0
## Доля прицеливания, после которой снайпер смотрит в оптику
const SCOPE_THRESHOLD: float = 0.85
var _aiming: bool = false
var _aim_weight: float = 0.0
var _base_fov: float = 75.0
var _bloom: float = 0.0
# Здоровья, уже задетые текущим ударом (без аллокаций: очищается перед ударом)
var _melee_hit: Array[Health] = []
var _rng := RandomNumberGenerator.new()

# Модели
var _current_model: Node3D
## Обвесы на модели в руках (AttachmentData.Look): узел в осях менеджера у среза ствола
var _attachment_holder: Node3D
var _laser_pivot: Node3D
var _laser_dot: MeshInstance3D
var _laser_from: Vector3 = Vector3.ZERO
var _view_instance: Node3D
var _model_rest: Vector3 = Vector3.ZERO
var _fallback_rest: Vector3 = Vector3.ZERO
var _fallback_muzzle: Vector3 = Vector3.ZERO
var _fallback_rotation: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group(&"weapon_manager")
	_rng.randomize()
	_resolve_references()

	if camera == null:
		push_error("WeaponManager: не найдена Camera3D (нода должна быть дочерней для камеры)")
		set_physics_process(false)
		set_process(false)
		return
	_base_fov = camera.fov
	auto_fire_enabled = Settings.auto_fire
	Settings.changed.connect(_on_settings_changed)

	if use_game_state_loadout:
		var loadout: Array[WeaponData] = GameState.get_loadout()
		if not loadout.is_empty():
			weapons = loadout

	# Убираем пустые слоты массива
	for i in range(weapons.size() - 1, -1, -1):
		if weapons[i] == null:
			weapons.remove_at(i)

	for weapon: WeaponData in weapons:
		_magazine.append(weapon.magazine_size)
		_reserve.append(maxi(weapon.max_reserve_ammo, 0))

	if weapons.is_empty():
		push_warning("WeaponManager: нет ни одного ствола")
		return
	equip(0)


func _on_settings_changed() -> void:
	auto_fire_enabled = Settings.auto_fire


# ---------- Публичный API ----------

func get_current_weapon() -> WeaponData:
	if _index < 0 or _index >= weapons.size():
		return null
	return weapons[_index]


func is_reloading() -> bool:
	return _reload_left > 0.0


func is_target_in_sight() -> bool:
	return _target_in_sight


func get_aim_slowdown() -> float:
	var slowdown: float = aim_assist_slowdown if _target_in_sight else 1.0
	# В прицеле обзор медленнее пропорционально зуму
	if camera != null and _base_fov > 0.0:
		slowdown *= camera.fov / _base_fov
	return slowdown


func is_aiming() -> bool:
	return _aiming


## Смотрим в оптику (снайперская винтовка почти в прицеле): круг оптики, модель скрыта
func is_scoped() -> bool:
	var weapon: WeaponData = get_current_weapon()
	return weapon != null and weapon.has_scope and _aim_weight >= SCOPE_THRESHOLD


## 0 — от бедра, 1 — полностью в прицеле
func get_aim_weight() -> float:
	return _aim_weight


func set_aiming(enabled: bool) -> void:
	var weapon: WeaponData = get_current_weapon()
	if enabled and (weapon == null or weapon.is_melee):
		enabled = false
	if enabled == _aiming:
		return
	_aiming = enabled
	aim_changed.emit(_aiming)


## Текущий разброс в градусах: оружие, прицел, бег, расхождение от стрельбы
func get_current_spread() -> float:
	var weapon: WeaponData = get_current_weapon()
	if weapon == null:
		return 0.0
	var base: float = weapon.spread_degrees * lerpf(1.0, weapon.ads_spread_multiplier, _aim_weight)
	var moving: float = weapon.spread_degrees * MOVE_SPREAD_FACTOR * _speed_ratio * (1.0 - _aim_weight * 0.6)
	return base + moving + _bloom


func equip(index: int) -> void:
	if weapons.is_empty():
		return
	var new_index: int = wrapi(index, 0, weapons.size())
	if new_index == _index:
		return
	_cancel_reload()
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	set_aiming(false)
	_bloom = 0.0
	_index = new_index
	_cooldown = SWITCH_DELAY
	_apply_view_model(weapons[_index])
	emit_state()


func next_weapon() -> void:
	equip(_index + 1)


func reload() -> void:
	var weapon: WeaponData = get_current_weapon()
	if weapon == null or weapon.is_melee or is_reloading():
		return
	if _magazine[_index] >= weapon.magazine_size:
		return
	if not weapon.has_infinite_reserve() and _reserve[_index] <= 0:
		return
	_reload_left = weapon.reload_time
	_reload_total = weapon.reload_time
	set_aiming(false)  # перезарядка — из прицела
	_reload_stream = weapon.reload_sound
	_reload_player = Sfx.play_2d(weapon.reload_sound, -2.0, 1.0, 0.0)
	reload_started.emit(weapon.reload_time)


## Подбор патронов: каждому стволу с ограниченным запасом +fraction от максимума.
## Возвращает true, если хоть что-то добавлено
func add_reserve_ammo(fraction: float) -> bool:
	var added: bool = false
	for i in weapons.size():
		var weapon: WeaponData = weapons[i]
		if weapon.has_infinite_reserve() or _reserve[i] >= weapon.max_reserve_ammo:
			continue
		var amount: int = maxi(ceili(weapon.max_reserve_ammo * fraction), 1)
		_reserve[i] = mini(_reserve[i] + amount, weapon.max_reserve_ammo)
		added = true
	if added:
		_emit_ammo()
	return added


## Повторно отправляет сигналы о текущем состоянии (для UI, подключившегося позже)
func emit_state() -> void:
	var weapon: WeaponData = get_current_weapon()
	if weapon == null:
		return
	weapon_changed.emit(weapon)
	_emit_ammo()
	if is_reloading():
		reload_started.emit(_reload_left)


# ---------- Цикл ----------

func _physics_process(delta: float) -> void:
	var weapon: WeaponData = get_current_weapon()
	if weapon == null:
		return

	var controls_enabled: bool = player == null or player.input_enabled
	if controls_enabled:
		if Input.is_action_just_pressed(&"switch_weapon") and weapons.size() > 1:
			next_weapon()
			weapon = get_current_weapon()
		elif Input.is_action_just_pressed(&"reload"):
			reload()
		if Input.is_action_just_pressed(&"aim"):
			set_aiming(not _aiming)
	elif _aiming:
		set_aiming(false)  # смерть, окно, пауза

	_cooldown = maxf(_cooldown - delta, 0.0)
	_update_target(weapon, delta)

	if is_reloading():
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()
		return

	if not controls_enabled:
		return

	var auto_fire: bool = auto_fire_enabled and _target_in_sight and _target_time >= auto_fire_delay
	if (Input.is_action_pressed(&"fire") or auto_fire) and _cooldown <= 0.0:
		_fire(weapon)


func _process(delta: float) -> void:
	_update_aim(delta)
	_update_flame(delta)
	_update_laser()
	if _current_model != null and is_instance_valid(_current_model):
		_animate_model(delta)
		var show_model: bool = not is_scoped()
		if _current_model.visible != show_model:
			_current_model.visible = show_model
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			if muzzle_flash != null:
				muzzle_flash.visible = false
			if _flash_sprite != null:
				_flash_sprite.visible = false


## Плавный зум камеры, скорость игрока, затухание расхождения прицела
func _update_aim(delta: float) -> void:
	_aim_weight = move_toward(_aim_weight, 1.0 if _aiming else 0.0, ADS_SPEED * delta)
	if camera != null:
		var weapon: WeaponData = get_current_weapon()
		var zoom: float = weapon.ads_fov_multiplier if weapon != null else 1.0
		camera.fov = lerpf(_base_fov, _base_fov * zoom, smoothstep(0.0, 1.0, _aim_weight))
	_speed_ratio = 0.0
	if player != null and player.is_on_floor() and player.move_speed > 0.0:
		_speed_ratio = clampf(Vector2(player.velocity.x, player.velocity.z).length() / player.move_speed, 0.0, 1.0)
	_bloom = maxf(_bloom - BLOOM_DECAY * delta, 0.0)


## Дыхание, покачивание при ходьбе, наклон при перезарядке, прицел. Без аллокаций
func _animate_model(delta: float) -> void:
	var k: float = _offset_scale()
	_anim_time += delta
	var sway: float = lerpf(1.0, ADS_SWAY_FACTOR, _aim_weight)
	var speed_ratio: float = _speed_ratio * sway
	_bob_phase += delta * WALK_BOB_SPEED * _speed_ratio

	var offset := Vector3(
		sin(_anim_time * IDLE_SWAY_SPEED * 0.5) * IDLE_SWAY.x * sway + sin(_bob_phase) * WALK_BOB.x * speed_ratio,
		sin(_anim_time * IDLE_SWAY_SPEED) * IDLE_SWAY.y * sway - absf(cos(_bob_phase)) * WALK_BOB.y * speed_ratio,
		0.0)
	var reload_weight: float = 0.0
	if is_reloading() and _reload_total > 0.0:
		var progress: float = 1.0 - _reload_left / _reload_total
		reload_weight = sin(clampf(progress, 0.0, 1.0) * PI)
		offset += RELOAD_OFFSET * reload_weight

	var target: Vector3 = _model_rest + offset * k
	if _aim_weight > 0.0:
		# В прицеле оружие уходит к центру экрана и поднимается
		var ads_offset := Vector3(-_model_rest.x, 0.0, 0.0) + ADS_RAISE * k
		target += ads_offset * smoothstep(0.0, 1.0, _aim_weight)
	_current_model.position = _current_model.position.lerp(target, clampf(GUN_RETURN_SPEED * delta, 0.0, 1.0))
	# Поворот не трогаем во время замаха (им управляет твин)
	if _swing_tween == null or not _swing_tween.is_running():
		_current_model.rotation_degrees = _model_base_rotation + RELOAD_TILT_DEGREES * reload_weight


# ---------- Модели оружия ----------

func _apply_view_model(weapon: WeaponData) -> void:
	_clear_view_model()

	if weapon.view_model != null:
		var instance := weapon.view_model.instantiate() as Node3D
		if instance == null:
			push_warning("WeaponManager: view_model у '%s' не Node3D-сцена" % weapon.display_name)
		else:
			add_child(instance)
			instance.position = weapon.model_position * VIEW_MODEL_SHRINK
			instance.rotation_degrees = weapon.model_rotation_degrees
			instance.scale = Vector3.ONE * weapon.model_scale * VIEW_MODEL_SHRINK
			_disable_shadows(instance)
			_view_instance = instance
			_current_model = instance
			_model_rest = instance.position
			_model_base_rotation = weapon.model_rotation_degrees
			if gun_model != null:
				gun_model.visible = false
			if muzzle_flash != null:
				# Срез ствола: из локальных координат модели в координаты менеджера
				muzzle_flash.position = instance.transform * weapon.muzzle_position
			if _flash_sprite != null:
				_flash_sprite.position = instance.transform * weapon.muzzle_position
				_flash_sprite.scale = Vector3.ONE * VIEW_MODEL_SHRINK

	if _view_instance == null:
		# Запасной вариант: серый брусок
		_current_model = gun_model
		_model_rest = _fallback_rest
		_model_base_rotation = _fallback_rotation
		if gun_model != null:
			gun_model.visible = true
		if muzzle_flash != null:
			muzzle_flash.position = _fallback_muzzle
		if _flash_sprite != null:
			_flash_sprite.position = _fallback_muzzle
			_flash_sprite.scale = Vector3.ONE

	_build_attachments(weapon)

	# Оружие появляется снизу и поднимается
	if _current_model != null:
		_current_model.position = _model_rest + _offset_scale() * SWITCH_LOWER_OFFSET


## Множитель смещений модели: уменьшенная вью-модель двигается пропорционально
func _offset_scale() -> float:
	return VIEW_MODEL_SHRINK if _view_instance != null else 1.0


func _clear_view_model() -> void:
	if _view_instance != null and is_instance_valid(_view_instance):
		_view_instance.queue_free()
	_view_instance = null
	if _attachment_holder != null and is_instance_valid(_attachment_holder):
		_attachment_holder.queue_free()
	_attachment_holder = null
	_laser_pivot = null
	if _laser_dot != null:
		_laser_dot.visible = false


# ---------- Обвесы на модели ----------

## Размеры обвесов (до уменьшения вью-модели), метры
const SILENCER_SIZE: Vector2 = Vector2(0.024, 0.2)    # радиус, длина
const COMPENSATOR_SIZE: Vector2 = Vector2(0.028, 0.07)
## Коллиматор: доля длины ствола назад от среза и высота над срезом
const RED_DOT_BACK: float = 0.7
const RED_DOT_UP: float = 0.05
## Лазер и рукоять: доля длины назад и глубина под срезом
const UNDER_BACK: float = 0.3
const UNDER_DOWN: float = 0.04
const LASER_RANGE: float = 40.0
const LASER_COLOR: Color = Color(1.0, 0.1, 0.08)


## Примитивы обвесов. Узел-держатель — ребёнок модели (качается и наклоняется с ней),
## но в осях и масштабе менеджера: −Z — вперёд по стволу
func _build_attachments(weapon: WeaponData) -> void:
	if _current_model == null or weapon.attachment_looks.is_empty():
		return
	var k: float = _offset_scale()
	# Модель ещё в покое (опускание при смене ствола — позже): срез ствола в осях менеджера
	var muzzle: Vector3 = _view_instance.transform * weapon.muzzle_position if _view_instance != null \
		else _fallback_muzzle
	var rest := Transform3D(_current_model.basis, _model_rest)
	_attachment_holder = Node3D.new()
	_attachment_holder.name = "Attachments"
	_current_model.add_child(_attachment_holder)
	_attachment_holder.transform = rest.affine_inverse() * Transform3D(Basis.IDENTITY, muzzle)
	# Длина ствола: от среза до точки крепления модели (по оси вперёд)
	var length: float = clampf(absf(muzzle.z - _model_rest.z), 0.08 * k, 0.6)
	var metal := _attachment_material(Color(0.12, 0.12, 0.13), 0.0)
	for look: int in weapon.attachment_looks:
		match look:
			AttachmentData.Look.SILENCER:
				_add_tube(SILENCER_SIZE * k, metal)
			AttachmentData.Look.COMPENSATOR:
				_add_tube(COMPENSATOR_SIZE * k, _attachment_material(Color(0.35, 0.33, 0.3), 0.0))
			AttachmentData.Look.RED_DOT:
				var sight := Node3D.new()
				sight.position = Vector3(0.0, RED_DOT_UP * k, length * RED_DOT_BACK)
				_attachment_holder.add_child(sight)
				_add_box(sight, Vector3(0.03, 0.012, 0.06) * k, Vector3(0.0, 0.0, 0.0), metal)
				_add_box(sight, Vector3(0.032, 0.034, 0.006) * k, Vector3(0.0, 0.02 * k, -0.025 * k), metal)
				_add_box(sight, Vector3(0.032, 0.034, 0.006) * k, Vector3(0.0, 0.02 * k, 0.025 * k), metal)
				var dot := _add_sphere(sight, 0.004 * k, Vector3(0.0, 0.022 * k, -0.02 * k),
					_attachment_material(LASER_COLOR, 3.0))
				dot.name = "RedDot"
			AttachmentData.Look.LASER:
				_laser_from = Vector3(0.0, -UNDER_DOWN * k, length * UNDER_BACK)
				_add_box(_attachment_holder, Vector3(0.022, 0.02, 0.07) * k, _laser_from, metal)
				_build_laser(k)
			AttachmentData.Look.GRIP:
				var grip := _add_box(_attachment_holder, Vector3(0.02, 0.07, 0.025) * k,
					Vector3(0.0, (-UNDER_DOWN - 0.04) * k, length * (UNDER_BACK + 0.15)), metal)
				grip.rotation.x = 0.2
	_disable_shadows(_attachment_holder)


func _add_tube(size: Vector2, material: Material) -> void:
	var tube := CylinderMesh.new()
	tube.top_radius = size.x
	tube.bottom_radius = size.x
	tube.height = size.y
	tube.radial_segments = 10
	tube.rings = 1
	tube.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = tube
	instance.rotation.x = PI * 0.5
	instance.position = Vector3(0.0, 0.0, -size.y * 0.5)
	_attachment_holder.add_child(instance)


func _add_box(parent: Node3D, box_size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = box_size
	box.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = box
	instance.position = at
	parent.add_child(instance)
	return instance


func _add_sphere(parent: Node3D, radius: float, at: Vector3, material: Material) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	sphere.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = sphere
	instance.position = at
	parent.add_child(instance)
	return instance


func _attachment_material(color: Color, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.6
	material.roughness = 0.4
	if emission > 0.0:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


## Луч лазера (тонкая полоска от излучателя до точки попадания) и точка на цели
func _build_laser(k: float) -> void:
	_laser_pivot = Node3D.new()
	_laser_pivot.position = _laser_from + Vector3(0.0, 0.0, -0.035 * k)
	_attachment_holder.add_child(_laser_pivot)
	var beam_material := StandardMaterial3D.new()
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_material.albedo_color = Color(LASER_COLOR, 0.35)
	var beam := BoxMesh.new()
	beam.size = Vector3(0.0025, 0.0025, 1.0)
	beam.material = beam_material
	var beam_instance := MeshInstance3D.new()
	beam_instance.mesh = beam
	beam_instance.position = Vector3(0.0, 0.0, -0.5)  # единичная длина вперёд от излучателя
	_laser_pivot.add_child(beam_instance)
	if _laser_dot == null:
		var dot_material := StandardMaterial3D.new()
		dot_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dot_material.albedo_color = LASER_COLOR
		var dot := SphereMesh.new()
		dot.radius = 0.025
		dot.height = 0.05
		dot.radial_segments = 8
		dot.rings = 4
		dot.material = dot_material
		_laser_dot = MeshInstance3D.new()
		_laser_dot.name = "LaserDot"
		_laser_dot.mesh = dot
		_laser_dot.top_level = true
		_laser_dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_laser_dot)


## Луч смотрит туда, куда полетит пуля (луч камеры), точка — на попадании
func _update_laser() -> void:
	if _laser_pivot == null or camera == null:
		return
	var shown: bool = _current_model != null and _current_model.visible
	_laser_pivot.visible = shown
	if not shown:
		_laser_dot.visible = false
		return
	var origin: Vector3 = camera.global_position
	var far_point: Vector3 = origin - camera.global_basis.z * LASER_RANGE
	var result: Dictionary = _raycast(origin, far_point)
	var target: Vector3 = far_point
	if not result.is_empty():
		target = result["position"]
		_laser_dot.global_position = target
	_laser_dot.visible = not result.is_empty()
	var from: Vector3 = _laser_pivot.global_position
	var direction: Vector3 = target - from
	var distance: float = direction.length()
	if distance < 0.05:
		return
	var up: Vector3 = Vector3.UP if absf(direction.normalized().y) < 0.98 else Vector3.FORWARD
	_laser_pivot.global_basis = Basis.looking_at(direction / distance, up).scaled_local(Vector3(1.0, 1.0, distance))


func _disable_shadows(root: Node) -> void:
	for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ---------- Стрельба ----------

func _fire(weapon: WeaponData) -> void:
	if weapon.is_melee:
		_melee_attack(weapon)
		return
	if _magazine[_index] <= 0:
		reload()  # пустой магазин → авто-перезарядка
		if not is_reloading():
			# Патронов нет совсем — щелчок
			_cooldown = DRY_FIRE_INTERVAL
			Sfx.play_2d(Sfx.sounds.dry_fire, -6.0)
		return

	_magazine[_index] -= 1
	_cooldown = weapon.get_fire_interval()
	_hit_sound_played = false
	if weapon.is_flamethrower:
		_flame_burst(weapon)
		return
	Sfx.play_2d(weapon.fire_sound, weapon.fire_volume_db, weapon.fire_pitch)
	if weapon.bolt_sound != null:
		var bolt: AudioStream = weapon.bolt_sound
		get_tree().create_timer(weapon.bolt_delay, false).timeout.connect(func() -> void:
			Sfx.play_2d(bolt, -3.0, 1.15, 0.0))

	var any_hit: bool = false
	var headshot: bool = false
	var killed: bool = false
	for i in weapon.pellets:
		var result: Dictionary = _fire_ray(weapon)
		if result.get("hit", false):
			any_hit = true
			headshot = headshot or result.get("head", false)
			killed = killed or result.get("killed", false)

	# Каждый выстрел раскрывает прицел (до max_bloom_factor × разброс)
	_bloom = minf(_bloom + weapon.spread_degrees * weapon.bloom_per_shot,
		weapon.spread_degrees * weapon.max_bloom_factor)
	_apply_feedback(weapon)
	fired.emit(weapon)
	_emit_ammo()
	if any_hit:
		hit_landed.emit(headshot, killed)

	if _magazine[_index] == 0:
		reload()


# ---------- Огнемёт ----------

## Урон всем зомби в конусе перед камерой (с проверкой стен)
func _flame_burst(weapon: WeaponData) -> void:
	_flame_time = FLAME_HOLD_TIME
	var origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_basis.z
	var cone_cos: float = cos(deg_to_rad(weapon.flame_cone_degrees * 0.5))
	var any_hit: bool = false
	var killed: bool = false
	for node: Node in get_tree().get_nodes_in_group(&"zombies"):
		var zombie := node as Zombie
		if zombie == null or zombie.health == null or zombie.health.is_dead:
			continue
		var target: Vector3 = zombie.global_position + Vector3.UP
		var offset: Vector3 = target - origin
		var distance: float = offset.length()
		if distance > weapon.max_range or distance < 0.01:
			continue
		if forward.dot(offset / distance) < cone_cos:
			continue
		# Огонь не проходит сквозь стены
		var query := PhysicsRayQueryParameters3D.create(origin, target, PhysicsLayers.WORLD)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		zombie.health.take_damage(weapon.damage, target, false)
		any_hit = true
		killed = killed or zombie.health.is_dead
	fired.emit(weapon)
	_emit_ammo()
	if any_hit:
		hit_landed.emit(false, killed)
	if _magazine[_index] == 0:
		reload()


func _update_flame(delta: float) -> void:
	if _flame_time <= 0.0 and (_flame_particles == null or not _flame_particles.emitting):
		return
	_flame_time = maxf(_flame_time - delta, 0.0)
	var active: bool = _flame_time > 0.0
	if _flame_particles == null:
		_create_flame()
	_flame_particles.emitting = active
	if active and _flame_sound.stream != null and not _flame_sound.playing:
		_flame_sound.play()
	elif not active and _flame_sound.playing:
		_flame_sound.stop()


func _create_flame() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.5
	quad.material = material
	_flame_particles = CPUParticles3D.new()
	_flame_particles.name = "Flame"
	_flame_particles.mesh = quad
	_flame_particles.amount = 48
	_flame_particles.lifetime = 0.5
	_flame_particles.emitting = false
	_flame_particles.direction = Vector3.FORWARD
	_flame_particles.spread = 9.0
	_flame_particles.initial_velocity_min = 10.0
	_flame_particles.initial_velocity_max = 14.0
	_flame_particles.gravity = Vector3(0.0, 2.0, 0.0)
	_flame_particles.scale_amount_min = 0.4
	_flame_particles.scale_amount_max = 2.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.5, 0.9))
	ramp.set_color(1, Color(0.5, 0.08, 0.0, 0.0))
	ramp.add_point(0.4, Color(1.0, 0.45, 0.1, 0.8))
	_flame_particles.color_ramp = ramp
	var growth := Curve.new()
	growth.add_point(Vector2(0.0, 0.3))
	growth.add_point(Vector2(1.0, 1.0))
	_flame_particles.scale_amount_curve = growth
	add_child(_flame_particles)
	_flame_particles.position = muzzle_flash.position if muzzle_flash != null else Vector3(0.1, -0.1, -0.4)
	_flame_sound = AudioStreamPlayer.new()
	_flame_sound.stream = Sfx.sounds.fire_loop
	_flame_sound.volume_db = -2.0
	add_child(_flame_sound)


## Удар ближнего боя: веер из трёх лучей, каждая цель получает урон один раз
func _melee_attack(weapon: WeaponData) -> void:
	var interval: float = weapon.get_fire_interval()
	_cooldown = interval
	_hit_sound_played = false
	_melee_hit.clear()
	Sfx.play_2d(weapon.fire_sound, weapon.fire_volume_db, weapon.fire_pitch)
	_play_swing(weapon, interval)

	var forward: Vector3 = -camera.global_basis.z
	var half_arc: float = deg_to_rad(weapon.melee_arc_degrees * 0.5)
	var any_hit: bool = false
	var headshot: bool = false
	var killed: bool = false
	for angle: float in [0.0, -half_arc, half_arc]:
		var result: Dictionary = _shoot_along(weapon, forward.rotated(Vector3.UP, angle))
		if result.get("hit", false):
			any_hit = true
			headshot = headshot or result.get("head", false)
			killed = killed or result.get("killed", false)

	fired.emit(weapon)
	if any_hit:
		if player != null:
			player.shake(0.15)
		hit_landed.emit(headshot, killed)


func _play_swing(weapon: WeaponData, interval: float) -> void:
	if _current_model == null or not is_instance_valid(_current_model):
		return
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	var rest: Vector3 = weapon.model_rotation_degrees
	_current_model.rotation_degrees = rest
	_swing_tween = create_tween()
	_swing_tween.tween_property(_current_model, "rotation_degrees",
		rest + weapon.swing_rotation_degrees, interval * SWING_OUT_SHARE) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_swing_tween.tween_property(_current_model, "rotation_degrees", rest, interval * SWING_BACK_SHARE) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _fire_ray(weapon: WeaponData) -> Dictionary:
	return _shoot_along(weapon, _spread_direction(get_current_spread()))


## Луч из камеры в направлении direction на max_range: урон, искры, звук
func _shoot_along(weapon: WeaponData, direction: Vector3) -> Dictionary:
	var origin: Vector3 = camera.global_position
	var target: Vector3 = origin + direction * weapon.max_range
	var result: Dictionary = _raycast(origin, target)
	if result.is_empty():
		return {}

	var hit_position: Vector3 = result.position
	var hit_normal: Vector3 = result.normal
	var hitbox := result.collider as Hitbox

	if hitbox == null:
		if _impacts != null:
			_impacts.spawn(hit_position, hit_normal, false)
		_play_hit_sound(Sfx.sounds.world_hits, hit_position)
		return {}

	if weapon.is_melee:
		# Один удар — одна цель получает урон один раз (лучи веера могут задеть её дважды)
		if hitbox.health == null or hitbox.health in _melee_hit:
			return {}
		_melee_hit.append(hitbox.health)
	var was_dead: bool = hitbox.health == null or hitbox.health.is_dead
	if not hitbox.apply_hit(weapon.damage, hit_position):
		return {}
	if _impacts != null:
		_impacts.spawn(hit_position, hit_normal, hitbox.flesh)
	_play_hit_sound(Sfx.sounds.flesh_hits if hitbox.flesh else Sfx.sounds.metal_hits, hit_position)
	return {
		"hit": true,
		"head": hitbox.is_head,
		"killed": not was_dead and hitbox.health.is_dead,
	}


## Один звук попадания на выстрел (у дробовика 8 дробин)
func _play_hit_sound(list: Array[AudioStream], at: Vector3) -> void:
	if _hit_sound_played:
		return
	_hit_sound_played = true
	Sfx.play_3d(Sfx.pick(list), at, HIT_SOUND_VOLUME_DB)


## Один запрос на все лучи (прицел-помощник стреляет лучом каждый физический кадр — без аллокаций)
var _ray_query: PhysicsRayQueryParameters3D


func _raycast(from: Vector3, to: Vector3) -> Dictionary:
	if _ray_query == null:
		_ray_query = PhysicsRayQueryParameters3D.new()
		_ray_query.collision_mask = PhysicsLayers.SHOT_MASK
		_ray_query.collide_with_areas = true
		_ray_query.collide_with_bodies = true
		if player != null:
			_ray_query.exclude = [player.get_rid()]
	_ray_query.from = from
	_ray_query.to = to
	return get_world_3d().direct_space_state.intersect_ray(_ray_query)


func _spread_direction(spread_deg: float) -> Vector3:
	var cam_basis: Basis = camera.global_basis
	var forward: Vector3 = -cam_basis.z
	if spread_deg <= 0.0:
		return forward
	# Равномерная точка внутри конуса разброса
	var max_offset: float = tan(deg_to_rad(spread_deg))
	var radius: float = sqrt(_rng.randf()) * max_offset
	var angle: float = _rng.randf() * TAU
	return (forward + cam_basis.x * cos(angle) * radius + cam_basis.y * sin(angle) * radius).normalized()


func _update_target(weapon: WeaponData, delta: float) -> void:
	var origin: Vector3 = camera.global_position
	var result: Dictionary = _raycast(origin, origin - camera.global_basis.z * weapon.max_range)
	var hitbox := result.get("collider") as Hitbox
	_target_in_sight = hitbox != null and hitbox.auto_target and hitbox.health != null \
		and not hitbox.health.is_dead
	_target_time = _target_time + delta if _target_in_sight else 0.0


func _apply_feedback(weapon: WeaponData) -> void:
	if player != null:
		player.add_recoil(weapon.recoil_pitch, _rng.randf_range(-weapon.recoil_yaw, weapon.recoil_yaw))
	if _current_model != null and is_instance_valid(_current_model):
		_current_model.position = _model_rest + Vector3(0.0, 0.0, weapon.gun_kick * _offset_scale())
	if weapon.hide_flash:
		return  # глушитель: без вспышки
	if muzzle_flash != null:
		muzzle_flash.visible = true
		_flash_left = MUZZLE_FLASH_TIME
	if _flash_sprite != null:
		_flash_sprite.visible = true
		_flash_sprite.rotation.z = _rng.randf() * TAU
		_flash_left = MUZZLE_FLASH_TIME


# ---------- Перезарядка ----------

func _finish_reload() -> void:
	_reload_left = 0.0
	_stop_reload_sound()
	var weapon: WeaponData = get_current_weapon()
	if weapon == null:
		return
	Sfx.play_2d(weapon.reload_end_sound, -2.0, 1.0, 0.0)
	var needed: int = weapon.magazine_size - _magazine[_index]
	if weapon.has_infinite_reserve():
		_magazine[_index] = weapon.magazine_size
	else:
		var taken: int = mini(needed, _reserve[_index])
		_magazine[_index] += taken
		_reserve[_index] -= taken
	reload_finished.emit()
	_emit_ammo()


func _cancel_reload() -> void:
	if not is_reloading():
		return
	_reload_left = 0.0
	_stop_reload_sound()
	reload_cancelled.emit()


## Обрывает звук перезарядки, если плеер ещё играет именно его
func _stop_reload_sound() -> void:
	if _reload_player != null and _reload_player.playing and _reload_player.stream == _reload_stream:
		_reload_player.stop()
	_reload_player = null
	_reload_stream = null


func _emit_ammo() -> void:
	var weapon: WeaponData = get_current_weapon()
	if weapon == null:
		return
	ammo_changed.emit(_magazine[_index], _reserve[_index], weapon.has_infinite_reserve())


# ---------- Служебное ----------

func _resolve_references() -> void:
	if player == null:
		player = owner as Player
	if camera == null:
		camera = get_parent() as Camera3D
	if gun_model == null:
		gun_model = get_node_or_null(^"Gun") as Node3D
	if muzzle_flash == null:
		muzzle_flash = get_node_or_null(^"Gun/MuzzleFlash") as Light3D

	if gun_model != null:
		_fallback_rest = gun_model.position
		_fallback_rotation = gun_model.rotation_degrees
	if muzzle_flash != null:
		# Вспышка должна жить отдельно от бруска: брусок прячется при наличии модели
		if muzzle_flash.get_parent() != self:
			muzzle_flash.reparent(self)
		_fallback_muzzle = muzzle_flash.position
		muzzle_flash.visible = false

	_create_flash_sprite()

	_impacts = get_node_or_null(^"/root/Impacts") as ImpactPool
	if _impacts == null:
		push_warning("WeaponManager: автозагрузка Impacts не найдена, искр попаданий не будет")


## Спрайт вспышки: квадрат с радиальным градиентом, аддитивный, поверх геометрии.
## Дочерний к камере, поэтому всегда смотрит в камеру без billboard
func _create_flash_sprite() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	gradient.set_color(1, Color(1.0, 0.45, 0.05, 0.0))
	gradient.add_point(0.35, Color(1.0, 0.75, 0.25, 0.85))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.no_depth_test = true
	material.albedo_texture = texture
	material.render_priority = 10

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * FLASH_SPRITE_SIZE
	quad.material = material

	_flash_sprite = MeshInstance3D.new()
	_flash_sprite.name = "MuzzleFlashSprite"
	_flash_sprite.mesh = quad
	_flash_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash_sprite.visible = false
	add_child(_flash_sprite)
	if muzzle_flash != null:
		_flash_sprite.position = muzzle_flash.position
