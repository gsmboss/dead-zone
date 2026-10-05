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
# Здоровья, уже задетые текущим ударом (без аллокаций: очищается перед ударом)
var _melee_hit: Array[Health] = []
var _rng := RandomNumberGenerator.new()

# Модели
var _current_model: Node3D
var _view_instance: Node3D
var _model_rest: Vector3 = Vector3.ZERO
var _fallback_rest: Vector3 = Vector3.ZERO
var _fallback_muzzle: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group(&"weapon_manager")
	_rng.randomize()
	_resolve_references()

	if camera == null:
		push_error("WeaponManager: не найдена Camera3D (нода должна быть дочерней для камеры)")
		set_physics_process(false)
		set_process(false)
		return

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
	return aim_assist_slowdown if _target_in_sight else 1.0


func equip(index: int) -> void:
	if weapons.is_empty():
		return
	var new_index: int = wrapi(index, 0, weapons.size())
	if new_index == _index:
		return
	_cancel_reload()
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
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
	if _current_model != null and is_instance_valid(_current_model):
		var target: Vector3 = _model_rest + (RELOAD_OFFSET * _offset_scale() if is_reloading() else Vector3.ZERO)
		_current_model.position = _current_model.position.lerp(
			target, clampf(GUN_RETURN_SPEED * delta, 0.0, 1.0))
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			if muzzle_flash != null:
				muzzle_flash.visible = false
			if _flash_sprite != null:
				_flash_sprite.visible = false


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
		if gun_model != null:
			gun_model.visible = true
		if muzzle_flash != null:
			muzzle_flash.position = _fallback_muzzle
		if _flash_sprite != null:
			_flash_sprite.position = _fallback_muzzle
			_flash_sprite.scale = Vector3.ONE

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
	Sfx.play_2d(weapon.fire_sound, weapon.fire_volume_db, weapon.fire_pitch)

	var any_hit: bool = false
	var headshot: bool = false
	var killed: bool = false
	for i in weapon.pellets:
		var result: Dictionary = _fire_ray(weapon)
		if result.get("hit", false):
			any_hit = true
			headshot = headshot or result.get("head", false)
			killed = killed or result.get("killed", false)

	_apply_feedback(weapon)
	fired.emit(weapon)
	_emit_ammo()
	if any_hit:
		hit_landed.emit(headshot, killed)

	if _magazine[_index] == 0:
		reload()


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
	return _shoot_along(weapon, _spread_direction(weapon.spread_degrees))


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
		_impacts.spawn(hit_position, hit_normal, true)
	_play_hit_sound(Sfx.sounds.flesh_hits, hit_position)
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


func _raycast(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.SHOT_MASK)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if player != null:
		query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)


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
	_target_in_sight = hitbox != null and hitbox.health != null and not hitbox.health.is_dead
	_target_time = _target_time + delta if _target_in_sight else 0.0


func _apply_feedback(weapon: WeaponData) -> void:
	if player != null:
		player.add_recoil(weapon.recoil_pitch, _rng.randf_range(-weapon.recoil_yaw, weapon.recoil_yaw))
	if _current_model != null and is_instance_valid(_current_model):
		_current_model.position = _model_rest + Vector3(0.0, 0.0, weapon.gun_kick * _offset_scale())
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
