class_name Zombie
extends CharacterBody3D
## Зомби:
## - бродит вокруг точки появления, пока не заметил игрока;
## - видит игрока только при прямой видимости, вплотную чует;
## - слышит выстрелы и идёт к месту выстрела;
## - заметив игрока, зовёт соседей;
## - окружает игрока с разных сторон и упреждает его движение;
## - потеряв из виду, идёт к последней точке и через время сдаётся;
## - вздрагивает от попаданий, выбирается, если застрял.
## Перед зомби — направление -Z. Работает с моделью (AnimationPlayer внутри Visual)
## и с капсулой-заглушкой.

signal died(zombie: Zombie)

enum State { WANDER, CHASE, SEARCH, ATTACK, STAGGER, DEAD, CHARGE, SLAM }

const PATH_UPDATE_INTERVAL: float = 0.25
const SENSE_INTERVAL: float = 0.2
const EYE_HEIGHT: float = 1.5
const PLAYER_HEAD_HEIGHT: float = 1.5
## Столько секунд после потери видимости зомби ещё «видит» игрока
const VISIBLE_GRACE: float = 0.5
## Заметив игрока, видит его дальше обычного
const KNOWN_SIGHT_MULTIPLIER: float = 1.5
const ATTACK_RECOVERY: float = 0.35
const ATTACK_HIT_TOLERANCE: float = 1.25
const FLANK_RADIUS: float = 2.0
## Ближе этого — идёт прямо на игрока, без обхода с фланга
const FLANK_MIN_DISTANCE: float = 4.0
const SEARCH_REACHED_DISTANCE: float = 1.2
const SEARCH_TURN_SPEED: float = 1.2
const WANDER_REACHED_DISTANCE: float = 0.8
const STAGGER_COOLDOWN: float = 1.0
const HEADSHOT_STAGGER_MULTIPLIER: float = 1.8
const STUCK_TIME: float = 0.8
const UNSTUCK_DURATION: float = 0.5
const FLASH_TIME: float = 0.08
const CORPSE_TIME: float = 4.0
const SINK_TIME: float = 1.5
## Пауза между рыками (случайная в этих пределах), сек
const VOICE_INTERVAL_MIN: float = 3.0
const VOICE_INTERVAL_MAX: float = 8.0
const HURT_SOUND_COOLDOWN: float = 0.4
const VOICE_HEIGHT: float = 1.5
## Рывок прерывается, если зомби упёрся (скорость ниже этой доли)
const CHARGE_BLOCKED_FACTOR: float = 0.25
const CHARGE_HIT_DISTANCE: float = 1.6
const SLAM_SHAKE: float = 0.8
const CHARGE_SHAKE: float = 0.6
## Масштаб модели Visual/Model в zombie.tscn (под него настроены хитбоксы)
const DEFAULT_MODEL_SCALE: float = 1.6

@export var data: ZombieData

## Сложность миссии: задаётся спавнером до add_child
var health_multiplier: float = 1.0
var damage_multiplier: float = 1.0
## Убит выстрелом в голову (для заданий)
var killed_by_headshot: bool = false

@export_group("References (optional)")
## Пусто → дочерняя нода "Health"
@export var health: Health
## Пусто → дочерняя нода "Visual"
@export var visual: Node3D
## Пусто → первый AnimationPlayer внутри Visual
@export var animation_player: AnimationPlayer

@export_group("Animation Names")
@export var anim_idle: StringName = &"Idle"
## Если такой анимации нет, используется бег
@export var anim_walk: StringName = &"Walk"
@export var anim_run: StringName = &"Run"
@export var anim_attack: StringName = &"Punch"
@export var anim_hit: StringName = &"HitReact"
@export var anim_death: StringName = &"Death"

@export_group("Animation Speed")
## Скорость (м/с), при которой анимация ходьбы выглядит естественно
@export var walk_anim_speed: float = 1.4
## Скорость (м/с), при которой анимация бега выглядит естественно
@export var run_anim_speed: float = 4.0
## Медленнее этого — анимация ходьбы, быстрее — бега
@export var walk_run_threshold: float = 2.4

@export_group("Movement")
## Обход других зомби (RVO). Полезно для толп, но дороже по CPU
@export var use_avoidance: bool = false

var state: State = State.WANDER

var _agent: NavigationAgent3D
var _player: Player
var _player_health: Health
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _rng := RandomNumberGenerator.new()

# Восприятие
var _target_known: bool = false
var _last_known_position: Vector3 = Vector3.ZERO
var _time_since_seen: float = INF
var _sense_timer: float = 0.0

# Движение
var _path_timer: float = 0.0
var _speed_multiplier: float = 1.0
var _flank_angle: float = 0.0
var _home_position: Vector3 = Vector3.ZERO
var _wander_target: Vector3 = Vector3.ZERO
var _has_wander_target: bool = false
var _wander_wait: float = 0.0
var _stuck_time: float = 0.0
var _unstuck_left: float = 0.0
var _unstuck_direction: Vector3 = Vector3.ZERO

# Бой
var _cooldown: float = 0.0
var _attack_elapsed: float = 0.0
var _attack_hit_done: bool = false
var _stagger_left: float = 0.0
var _stagger_cooldown: float = 0.0

# Визуал
var _flash: float = 0.0
var _geometries: Array[GeometryInstance3D] = []
var _hitboxes: Array[Hitbox] = []
var _flash_material: StandardMaterial3D
var _visual_base_position: Vector3 = Vector3.ZERO

# Способности босса
var _charge_cooldown: float = 0.0
var _slam_cooldown: float = 0.0
var _special_elapsed: float = 0.0
var _special_hit_done: bool = false
var _charge_direction: Vector3 = Vector3.ZERO
var _last_hit_headshot: bool = false

# Звук
var _voice_timer: float = 0.0
var _hurt_sound_cooldown: float = 0.0


func _ready() -> void:
	add_to_group(&"zombies")
	collision_layer = PhysicsLayers.ENEMY
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.ENEMY | PhysicsLayers.PLAYER

	if data == null:
		push_warning("Zombie '%s': data не назначена, используются значения по умолчанию" % name)
		data = ZombieData.new()

	if not _resolve_references():
		set_physics_process(false)
		set_process(false)
		return

	health.max_health = data.max_health * maxf(health_multiplier, 0.1)
	health.reset()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)

	# Индивидуальность каждого зомби
	_rng.randomize()
	_speed_multiplier = 1.0 + _rng.randf_range(-data.speed_variation, data.speed_variation)
	_flank_angle = _rng.randf() * TAU
	_home_position = global_position
	_wander_wait = _rng.randf_range(0.0, 2.0)
	_sense_timer = _rng.randf() * SENSE_INTERVAL  # разносим проверки по разным кадрам
	_voice_timer = _rng.randf_range(0.5, VOICE_INTERVAL_MAX)
	_charge_cooldown = data.charge_cooldown * 0.5
	_slam_cooldown = 0.0

	_setup_agent()
	_setup_visuals()
	_play(anim_idle)
	_find_player.call_deferred()


# ---------- Публичный API ----------

## Сообщить зомби, где игрок (выстрел, зов соседа).
## propagate = true — позвать соседей (только для «своих» обнаружений, без цепной реакции)
func notify_target(target_position: Vector3, propagate: bool = false) -> void:
	if state == State.DEAD:
		return
	_last_known_position = target_position
	var was_known: bool = _target_known
	_target_known = true
	# Знает место, но не видит → пойдёт искать; интерес продлевается
	_time_since_seen = minf(_time_since_seen, VISIBLE_GRACE + 0.1)
	if propagate and not was_known:
		_alert_others()


# ---------- Цикл ----------

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	_stagger_cooldown = maxf(_stagger_cooldown - delta, 0.0)
	_hurt_sound_cooldown = maxf(_hurt_sound_cooldown - delta, 0.0)
	_charge_cooldown = maxf(_charge_cooldown - delta, 0.0)
	_slam_cooldown = maxf(_slam_cooldown - delta, 0.0)
	_update_voice(delta)

	if _has_live_target():
		_update_senses(delta)
	else:
		_target_known = false

	match state:
		State.STAGGER:
			_process_stagger(delta)
			return
		State.ATTACK:
			if _has_live_target():
				_process_attack(delta)
				return
			_set_state(State.WANDER)
		State.CHARGE:
			if _has_live_target():
				_process_charge(delta)
				return
			_set_state(State.WANDER)
		State.SLAM:
			if _has_live_target():
				_process_slam(delta)
				return
			_set_state(State.WANDER)

	if _target_known:
		_process_hunt(delta)
	else:
		_process_wander(delta)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_set_flash(false)
	if animation_player == null and visual != null and state != State.DEAD:
		_animate_placeholder(delta)


# ---------- Восприятие ----------

func _update_senses(delta: float) -> void:
	_time_since_seen += delta
	_sense_timer -= delta
	if _sense_timer > 0.0:
		return
	_sense_timer = SENSE_INTERVAL

	var distance: float = _flat_distance_to(_player.global_position)
	var sight: float = data.detection_radius * (KNOWN_SIGHT_MULTIPLIER if _target_known else 1.0)
	var sees: bool = distance <= data.close_sense_radius \
		or (distance <= sight and _has_line_of_sight())

	if sees:
		_last_known_position = _player.global_position
		_time_since_seen = 0.0
		if not _target_known:
			_target_known = true
			_alert_others()
	elif _target_known and _time_since_seen >= data.lose_interest_time:
		_target_known = false  # сдался, уходит бродить
		_has_wander_target = false


func _has_line_of_sight() -> bool:
	var from: Vector3 = global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
	var to: Vector3 = _player.global_position + Vector3(0.0, PLAYER_HEAD_HEIGHT, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.WORLD)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _alert_others() -> void:
	if data.alert_radius <= 0.0:
		return
	for node: Node in get_tree().get_nodes_in_group(&"zombies"):
		var other := node as Zombie
		if other == null or other == self or other.state == State.DEAD:
			continue
		if global_position.distance_to(other.global_position) <= data.alert_radius:
			other.notify_target(_last_known_position, false)


# ---------- Поведение ----------

func _process_hunt(delta: float) -> void:
	var player_position: Vector3 = _player.global_position
	var distance: float = _flat_distance_to(player_position)
	var can_see: bool = _time_since_seen <= VISIBLE_GRACE

	if can_see and distance <= data.attack_range:
		_face(_flat(player_position - global_position), delta)
		_set_desired_velocity(Vector3.ZERO)
		if data.slam_enabled and _slam_cooldown <= 0.0:
			_start_slam()
		elif _cooldown <= 0.0:
			_start_attack()
		else:
			_play_locomotion(0.0)
		return

	if can_see and data.charge_enabled and _charge_cooldown <= 0.0 \
			and distance >= data.charge_min_distance and distance <= data.charge_max_distance:
		_start_charge()
		return

	if can_see:
		_set_state(State.CHASE)
		_move_to(_chase_point(player_position, distance), data.move_speed * _speed_multiplier, delta)
		return

	# Не видит: идёт к последней известной точке и осматривается
	_set_state(State.SEARCH)
	if _flat_distance_to(_last_known_position) <= SEARCH_REACHED_DISTANCE:
		_set_desired_velocity(Vector3.ZERO)
		rotation.y += SEARCH_TURN_SPEED * delta
		_play_locomotion(0.0)
	else:
		_move_to(_last_known_position, data.move_speed * _speed_multiplier * 0.85, delta)


func _chase_point(player_position: Vector3, distance: float) -> Vector3:
	# Упреждение движения игрока
	var predicted: Vector3 = player_position + _flat(_player.velocity) * data.prediction_time
	if distance <= FLANK_MIN_DISTANCE:
		return predicted
	# Издалека каждый заходит со своей стороны → окружают
	return predicted + Vector3(cos(_flank_angle), 0.0, sin(_flank_angle)) * FLANK_RADIUS


func _process_wander(delta: float) -> void:
	_set_state(State.WANDER)

	if _wander_wait > 0.0:
		_wander_wait -= delta
		_set_desired_velocity(Vector3.ZERO)
		_play_locomotion(0.0)
		return

	if not _has_wander_target:
		_pick_wander_target()
		if not _has_wander_target:
			_wander_wait = 1.0
			_set_desired_velocity(Vector3.ZERO)
			_play_locomotion(0.0)
			return

	if _flat_distance_to(_wander_target) <= WANDER_REACHED_DISTANCE:
		_has_wander_target = false
		_wander_wait = _rng.randf_range(1.5, 4.0)
		_set_desired_velocity(Vector3.ZERO)
		_play_locomotion(0.0)
		return

	_move_to(_wander_target, data.move_speed * data.wander_speed_factor * _speed_multiplier, delta)


func _pick_wander_target() -> void:
	_has_wander_target = false
	if data.wander_radius <= 0.0 or not _is_navigation_ready():
		return
	var angle: float = _rng.randf() * TAU
	var radius: float = sqrt(_rng.randf()) * data.wander_radius
	var candidate: Vector3 = _home_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	# Ближайшая точка на навмеше, чтобы не выбрать цель внутри стены
	_wander_target = NavigationServer3D.map_get_closest_point(_agent.get_navigation_map(), candidate)
	_has_wander_target = true
	_path_timer = 0.0


func _start_attack() -> void:
	_voice(Sfx.sounds.zombie_attack, 2.0)
	_set_state(State.ATTACK)
	_attack_elapsed = 0.0
	_attack_hit_done = false
	_play(anim_attack, true)


func _process_attack(delta: float) -> void:
	var to_player: Vector3 = _flat(_player.global_position - global_position)
	_face(to_player, delta)
	_set_desired_velocity(Vector3.ZERO)
	_attack_elapsed += delta

	if not _attack_hit_done and _attack_elapsed >= data.attack_windup:
		_attack_hit_done = true
		# Игрок успел отбежать — промах
		if to_player.length() <= data.attack_range * ATTACK_HIT_TOLERANCE:
			_player_health.take_damage(data.attack_damage * damage_multiplier, global_position, false)

	if _attack_elapsed >= data.attack_windup + ATTACK_RECOVERY:
		_cooldown = data.attack_cooldown
		_set_state(State.CHASE)


# ---------- Способности босса ----------

func _start_charge() -> void:
	_set_state(State.CHARGE)
	_special_elapsed = 0.0
	_special_hit_done = false
	_charge_direction = _flat(_player.global_position - global_position).normalized()
	_voice(Sfx.sounds.zombie_attack, 4.0)
	_play(anim_idle, true)


## Замах (стоит и смотрит на игрока) → рывок по прямой
func _process_charge(delta: float) -> void:
	_special_elapsed += delta
	if _special_elapsed < data.charge_windup:
		var to_player: Vector3 = _flat(_player.global_position - global_position)
		_face(to_player, delta)
		if to_player.length_squared() > 0.01:
			_charge_direction = to_player.normalized()
		_set_desired_velocity(Vector3.ZERO)
		return

	var dash_time: float = _special_elapsed - data.charge_windup
	_face(_charge_direction, delta)
	_apply_velocity(_charge_direction * data.charge_speed)
	_play(anim_run, false, data.charge_speed / maxf(run_anim_speed, 0.1))

	if not _special_hit_done and _flat_distance_to(_player.global_position) <= CHARGE_HIT_DISTANCE:
		_special_hit_done = true
		_player_health.take_damage(data.charge_damage * damage_multiplier, global_position, false)
		_push_player(CHARGE_SHAKE)
		_end_special(true)
		return

	var real: Vector3 = get_real_velocity()
	var blocked: bool = dash_time > 0.25 \
		and Vector2(real.x, real.z).length() < data.charge_speed * CHARGE_BLOCKED_FACTOR
	if dash_time >= data.charge_duration or blocked:
		_end_special(true)


func _start_slam() -> void:
	_set_state(State.SLAM)
	_special_elapsed = 0.0
	_special_hit_done = false
	_voice(Sfx.sounds.zombie_attack, 4.0)
	_play(anim_attack, true, 0.7)


## Медленный замах → удар по всем вокруг в радиусе slam_radius
func _process_slam(delta: float) -> void:
	_special_elapsed += delta
	_face(_flat(_player.global_position - global_position), delta)
	_set_desired_velocity(Vector3.ZERO)
	if not _special_hit_done and _special_elapsed >= data.slam_windup:
		_special_hit_done = true
		var impacts := get_node_or_null(^"/root/Impacts") as ImpactPool
		if impacts != null:
			impacts.spawn(global_position + Vector3.UP * 0.1, Vector3.UP, false)
		Sfx.play_3d(Sfx.pick(Sfx.sounds.metal_hits), global_position, 4.0, 0.5)
		if _flat_distance_to(_player.global_position) <= data.slam_radius:
			_player_health.take_damage(data.slam_damage * damage_multiplier, global_position, false)
			_push_player(SLAM_SHAKE)
		elif _player != null:
			_player.shake(SLAM_SHAKE * 0.4)  # земля дрожит и вдали
	if _special_elapsed >= data.slam_windup + ATTACK_RECOVERY:
		_end_special(false)


func _end_special(was_charge: bool) -> void:
	if was_charge:
		_charge_cooldown = data.charge_cooldown
	else:
		_slam_cooldown = data.slam_cooldown
	_cooldown = data.attack_cooldown
	_set_desired_velocity(Vector3.ZERO)
	_set_state(State.CHASE)


func _push_player(shake_strength: float) -> void:
	if _player == null:
		return
	var away: Vector3 = _flat(_player.global_position - global_position)
	if away.length_squared() < 0.01:
		away = -global_basis.z
	_player.apply_knockback(away.normalized() * data.knockback + Vector3.UP * data.knockback * 0.3)
	_player.shake(shake_strength)


func _try_stagger(is_headshot: bool) -> void:
	if data.stagger_time <= 0.0 or _stagger_cooldown > 0.0 or state == State.DEAD:
		return
	_stagger_left = data.stagger_time * (HEADSHOT_STAGGER_MULTIPLIER if is_headshot else 1.0)
	# Кулдаун, чтобы автомат не держал зомби в вечном оцепенении
	_stagger_cooldown = _stagger_left + STAGGER_COOLDOWN
	_set_state(State.STAGGER)
	_play(anim_hit, true)


func _process_stagger(delta: float) -> void:
	_set_desired_velocity(Vector3.ZERO)
	_stagger_left -= delta
	if _stagger_left <= 0.0:
		_set_state(State.CHASE if _target_known else State.WANDER)


func _set_state(new_state: State) -> void:
	if state == new_state or state == State.DEAD:
		return
	state = new_state


# ---------- Движение ----------

func _move_to(target: Vector3, speed: float, delta: float) -> void:
	_path_timer -= delta
	if _path_timer <= 0.0:
		_path_timer = PATH_UPDATE_INTERVAL
		_agent.target_position = target

	var direction: Vector3 = _flat(target - global_position)
	if _is_navigation_ready() and not _agent.is_navigation_finished():
		var next_point: Vector3 = _flat(_agent.get_next_path_position() - global_position)
		# Пустой путь (нет навмеша) → идём напрямую
		if next_point.length_squared() > 0.01:
			direction = next_point

	if _unstuck_left > 0.0:
		_unstuck_left -= delta
		direction = _unstuck_direction

	if direction.length_squared() < 0.0001:
		_set_desired_velocity(Vector3.ZERO)
		_play_locomotion(0.0)
		return

	direction = direction.normalized()
	_face(direction, delta)
	_set_desired_velocity(direction * speed)
	_play_locomotion(speed)
	_check_stuck(speed, delta)


func _check_stuck(speed: float, delta: float) -> void:
	if _unstuck_left > 0.0:
		return
	var real: Vector3 = get_real_velocity()
	var actual: float = Vector2(real.x, real.z).length()
	if speed > 0.5 and actual < speed * 0.2:
		_stuck_time += delta
	else:
		_stuck_time = 0.0

	if _stuck_time >= STUCK_TIME:
		# Упёрся: шаг в сторону и новый путь
		_stuck_time = 0.0
		_path_timer = 0.0
		var side: Vector3 = (-global_basis.z).cross(Vector3.UP).normalized()
		_unstuck_direction = side * (1.0 if _rng.randf() > 0.5 else -1.0)
		_unstuck_left = UNSTUCK_DURATION


func _face(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	var target_yaw: float = atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(data.turn_speed * delta, 0.0, 1.0))


func _set_desired_velocity(desired: Vector3) -> void:
	if use_avoidance and _agent != null and _agent.avoidance_enabled:
		_agent.velocity = desired  # результат придёт в _on_velocity_computed
	else:
		_apply_velocity(desired)


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if state == State.DEAD:
		return
	_apply_velocity(safe_velocity)


func _apply_velocity(horizontal: Vector3) -> void:
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()


func _is_navigation_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0


func _has_live_target() -> bool:
	return _player != null and is_instance_valid(_player) \
		and _player_health != null and not _player_health.is_dead


func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)


func _flat_distance_to(point: Vector3) -> float:
	return _flat(point - global_position).length()


# ---------- Реакции ----------

func _on_player_fired(_weapon: WeaponData) -> void:
	if state == State.DEAD or _player == null:
		return
	if global_position.distance_to(_player.global_position) <= data.hearing_radius:
		notify_target(_player.global_position, false)


func _on_damaged(_amount: float, _hit_position: Vector3, is_headshot: bool) -> void:
	_last_hit_headshot = is_headshot
	_flash = FLASH_TIME
	_set_flash(true)
	if _hurt_sound_cooldown <= 0.0 and not health.is_dead:
		_hurt_sound_cooldown = HURT_SOUND_COOLDOWN
		_voice(Sfx.sounds.zombie_hurt)
	if _player != null:
		notify_target(_player.global_position, true)
		_time_since_seen = 0.0  # знает, откуда стреляли
	_try_stagger(is_headshot)


func _on_died() -> void:
	killed_by_headshot = _last_hit_headshot
	state = State.DEAD
	velocity = Vector3.ZERO
	_set_flash(false)
	# Отложенно: смерть случается внутри обработки выстрела
	set_deferred(&"collision_layer", 0)
	set_deferred(&"collision_mask", 0)
	for hitbox: Hitbox in _hitboxes:
		hitbox.set_deferred(&"collision_layer", 0)
	if _agent != null:
		_agent.avoidance_enabled = false
	_voice(Sfx.sounds.zombie_death, 3.0)
	var impacts := get_node_or_null(^"/root/Impacts") as ImpactPool
	if impacts != null:
		impacts.spawn_blood(global_position)
	died.emit(self)

	if _has_anim(anim_death):
		_play(anim_death, true)
	elif visual != null:
		var fall := create_tween()
		fall.tween_property(visual, "rotation:x", deg_to_rad(90.0), 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await get_tree().create_timer(CORPSE_TIME).timeout
	if not is_inside_tree():
		return
	if visual != null:
		var sink := create_tween()
		sink.tween_property(visual, "position:y", visual.position.y - 1.2, SINK_TIME)
		await sink.finished
	queue_free()


# ---------- Звук ----------

## Рык время от времени (громче в погоне)
func _update_voice(delta: float) -> void:
	_voice_timer -= delta
	if _voice_timer > 0.0:
		return
	_voice_timer = _rng.randf_range(VOICE_INTERVAL_MIN, VOICE_INTERVAL_MAX)
	if state == State.WANDER:
		_voice(Sfx.sounds.zombie_idle, -6.0)
	elif state == State.CHASE or state == State.SEARCH:
		_voice(Sfx.sounds.zombie_idle)


func _voice(list: Array[AudioStream], extra_db: float = 0.0) -> void:
	Sfx.play_3d(Sfx.pick(list), global_position + Vector3(0.0, VOICE_HEIGHT * _model_height_factor(), 0.0),
		data.voice_volume_db + extra_db, data.voice_pitch)


## Во сколько раз модель выше стандартной (для звука и хитбоксов)
func _model_height_factor() -> float:
	if data.model_scene == null:
		return 1.0
	return data.model_scale / DEFAULT_MODEL_SCALE


# ---------- Анимация ----------

func _has_anim(anim_name: StringName) -> bool:
	return animation_player != null and anim_name != &"" and animation_player.has_animation(anim_name)


func _play(anim_name: StringName, restart: bool = false, speed_scale: float = 1.0) -> void:
	if not _has_anim(anim_name):
		return
	animation_player.speed_scale = clampf(speed_scale, 0.5, 2.0)
	if restart or animation_player.current_animation != anim_name:
		animation_player.play(anim_name, 0.15)
		if restart:
			animation_player.seek(0.0, true)


## Idle / Walk / Run в зависимости от скорости, темп анимации под скорость движения
func _play_locomotion(speed: float) -> void:
	if speed <= 0.05:
		_play(anim_idle)
		return
	if speed <= walk_run_threshold and _has_anim(anim_walk):
		_play(anim_walk, false, speed / maxf(walk_anim_speed, 0.1))
	else:
		_play(anim_run, false, speed / maxf(run_anim_speed, 0.1))


func _animate_placeholder(delta: float) -> void:
	var target_tilt: float = 0.0
	var target_offset: Vector3 = Vector3.ZERO
	var moving: bool = Vector2(velocity.x, velocity.z).length() > 0.1
	match state:
		State.CHASE, State.SEARCH, State.WANDER:
			if moving:
				target_tilt = deg_to_rad(-12.0)
		State.ATTACK:
			var total: float = data.attack_windup + ATTACK_RECOVERY
			var t: float = clampf(_attack_elapsed / total, 0.0, 1.0)
			target_offset.z = -0.4 * sin(t * PI)
			target_tilt = deg_to_rad(-25.0) * sin(t * PI)
		State.STAGGER:
			target_tilt = deg_to_rad(15.0)  # отшатнулся назад
	var weight: float = clampf(10.0 * delta, 0.0, 1.0)
	visual.rotation.x = lerpf(visual.rotation.x, target_tilt, weight)
	visual.position = visual.position.lerp(_visual_base_position + target_offset, weight)


func _set_flash(enabled: bool) -> void:
	# Overlay поверх любого материала: работает и с текстурированной моделью
	for geometry: GeometryInstance3D in _geometries:
		if is_instance_valid(geometry):
			geometry.material_overlay = _flash_material if enabled else null


# ---------- Инициализация ----------

func _resolve_references() -> bool:
	if health == null:
		health = get_node_or_null(^"Health") as Health
	if health == null:
		push_error("Zombie '%s': нет дочерней ноды Health" % name)
		return false

	if visual == null:
		visual = get_node_or_null(^"Visual") as Node3D
	if visual != null:
		_visual_base_position = visual.position
		_apply_model_override()
		if animation_player == null:
			var players: Array[Node] = visual.find_children("*", "AnimationPlayer", true, false)
			if not players.is_empty():
				animation_player = players[0] as AnimationPlayer

	for child: Node in get_children():
		if child is Hitbox:
			_hitboxes.append(child)
	_fit_hitboxes()
	return true


## Своя модель другого масштаба: хитбоксы (тело и голова) растут вместе с ней.
## Формы дублируются — они общие для всех зомби из zombie.tscn
func _fit_hitboxes() -> void:
	var factor: float = _model_height_factor()
	if is_equal_approx(factor, 1.0):
		return
	for hitbox: Hitbox in _hitboxes:
		for shape_node: Node in hitbox.get_children():
			var collision := shape_node as CollisionShape3D
			if collision == null or collision.shape == null:
				continue
			collision.position *= factor
			var shape: Shape3D = collision.shape.duplicate() as Shape3D
			if shape is CapsuleShape3D:
				var capsule := shape as CapsuleShape3D
				capsule.radius *= factor
				capsule.height *= factor
			elif shape is SphereShape3D:
				(shape as SphereShape3D).radius *= factor
			elif shape is BoxShape3D:
				(shape as BoxShape3D).size *= factor
			collision.shape = shape


## Подменяет Visual/Model моделью типа из data.model_scene (если задана)
func _apply_model_override() -> void:
	if data.model_scene == null:
		return
	var instance: Node = data.model_scene.instantiate()
	var model := instance as Node3D
	if model == null:
		if instance != null:
			instance.free()
		push_warning("Zombie '%s': model_scene типа %s не Node3D, оставлена модель по умолчанию" \
				% [name, data.display_name])
		return
	var old_model: Node = visual.get_node_or_null(^"Model")
	if old_model != null:
		# AnimationPlayer старой модели больше не нужен — найдём новый
		if animation_player != null and old_model.is_ancestor_of(animation_player):
			animation_player = null
		visual.remove_child(old_model)
		old_model.queue_free()
	model.name = "Model"
	model.scale = Vector3.ONE * data.model_scale
	model.rotation.y = PI  # модели Quaternius смотрят в +Z, зомби — в -Z
	visual.add_child(model)


func _setup_agent() -> void:
	_agent = get_node_or_null(^"NavigationAgent3D") as NavigationAgent3D
	if _agent == null:
		_agent = NavigationAgent3D.new()
		add_child(_agent)
	_agent.path_desired_distance = 0.5
	_agent.target_desired_distance = 0.6
	_agent.radius = 0.45
	_agent.height = 1.8
	_agent.max_speed = data.move_speed * (1.0 + data.speed_variation)
	_agent.avoidance_enabled = use_avoidance
	if use_avoidance:
		_agent.velocity_computed.connect(_on_velocity_computed)


func _setup_visuals() -> void:
	if visual != null:
		for node: Node in visual.find_children("*", "GeometryInstance3D", true, false):
			_geometries.append(node as GeometryInstance3D)

	# Заглушка без анимаций: красим капсулы цветом типа зомби
	if animation_player == null:
		var tint := StandardMaterial3D.new()
		tint.albedo_color = data.body_color
		for geometry: GeometryInstance3D in _geometries:
			geometry.material_override = tint

	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.albedo_color = Color(1.0, 0.1, 0.1, 0.55)


func _find_player() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null:
		push_warning("Zombie '%s': игрок не найден (группа player)" % name)
		return
	_player_health = _player.health
	var manager: WeaponManager = _player.weapon_manager
	if manager != null and not manager.fired.is_connected(_on_player_fired):
		manager.fired.connect(_on_player_fired)
