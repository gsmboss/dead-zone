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
## Убран без смерти (далеко от игрока в открытом мире)
signal despawned(zombie: Zombie)

enum State { WANDER, CHASE, SEARCH, ATTACK, STAGGER, DEAD, CHARGE, SLAM, RANGED, FUSE }

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
# Тактика
## Одновременно атакуют не больше стольких зомби (с очередью), остальные ждут на кольце
const MAX_ATTACKERS: int = 3
## Ближе этого зомби без очереди не подходит — кружит вокруг игрока
const WAIT_RING_DISTANCE: float = 3.2
## С этой дистанции зомби пытается занять место в очереди атак
const ENGAGE_DISTANCE: float = 4.0
## На сколько радиан вперёд по кругу смотрит точка обхода и доля скорости при ожидании
const CIRCLE_LEAD: float = 0.6
const WAIT_SPEED_FACTOR: float = 0.55
## Заход со спины: дистанция точки за игроком и разброс угла
const BEHIND_DISTANCE: float = 4.0
const BEHIND_SPREAD: float = deg_to_rad(60.0)
## Игрок «целится» в зомби, если угол меньше этого (для зигзага)
const AIMED_AT_COS: float = 0.985
const ZIGZAG_MIN_DISTANCE: float = 5.0
## Бег игрока слышен, если его скорость выше этой
const LOUD_STEP_SPEED: float = 3.0
## Золотой угол: соседние зомби берут сектора равномерно вокруг игрока
const GOLDEN_ANGLE: float = 2.39996

## Кто сейчас атакует (общая очередь всех зомби)
static var _attackers: Array[Zombie] = []
static var _flank_counter: int = 0
## Типы, о которых уже предупредили (без спама в лог на каждом спавне)
static var _warned_types: Dictionary = {}

## Плевок: пауза после выстрела и точка вылета (доля высоты модели)
const RANGED_RECOVERY: float = 0.4
const SPIT_HEIGHT: float = 1.4
## Взрывной раздувается перед взрывом
const FUSE_SWELL: float = 0.35
## Кость головы в скелетах Quaternius
const HEAD_BONE: StringName = &"Head"
## Высота кости Head у Zombie_Basic в масштабе 1.6 (под неё настроены хитбоксы zombie.tscn)
const REFERENCE_HEAD_HEIGHT: float = 1.216
## Центр хитбокса головы относительно кости Head у Zombie_Basic (в осях зомби)
const HEAD_OFFSET_REFERENCE: Vector3 = Vector3(0.018, 0.234, -0.179)
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
var _ai_time: float = 0.0
## Направление обхода по кругу: половина зомби по часовой, половина против
var _circle_direction: float = 1.0
var _has_token: bool = false
var _search_left: int = 0
var _search_target: Vector3 = Vector3.ZERO
var _searching_points: bool = false
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
var _ranged_cooldown: float = 0.0
var _exploded: bool = false
var _tint_material: StandardMaterial3D

# Хитбоксы под модель
var _size_factor: float = 1.0
var _skeleton: Skeleton3D
var _head_bone: int = -1
var _skeleton_to_body: Transform3D = Transform3D.IDENTITY
var _head_shape: CollisionShape3D
var _head_offset: Vector3 = Vector3.ZERO

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
	# Сектора по золотому углу: каждый новый зомби заходит со своей стороны
	_flank_angle = fmod(_flank_counter * GOLDEN_ANGLE, TAU)
	_flank_counter += 1
	_circle_direction = 1.0 if _flank_counter % 2 == 0 else -1.0
	_home_position = global_position
	_wander_wait = _rng.randf_range(0.0, 2.0)
	_sense_timer = _rng.randf() * SENSE_INTERVAL  # разносим проверки по разным кадрам
	_voice_timer = _rng.randf_range(0.5, VOICE_INTERVAL_MAX)
	_charge_cooldown = data.charge_cooldown * 0.5
	_slam_cooldown = 0.0

	_apply_animation_overrides()
	_ranged_cooldown = data.ranged_cooldown * _rng.randf_range(0.3, 1.0)
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
	_update_head_hitbox()

	if not is_on_floor():
		velocity.y -= _gravity * delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	_stagger_cooldown = maxf(_stagger_cooldown - delta, 0.0)
	_hurt_sound_cooldown = maxf(_hurt_sound_cooldown - delta, 0.0)
	_charge_cooldown = maxf(_charge_cooldown - delta, 0.0)
	_ranged_cooldown = maxf(_ranged_cooldown - delta, 0.0)
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
		State.RANGED:
			if _has_live_target():
				_process_ranged(delta)
				return
			_set_state(State.WANDER)
		State.FUSE:
			_process_fuse(delta)
			return

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
	if not sees and distance <= data.footstep_hearing_radius \
			and _flat(_player.velocity).length() >= LOUD_STEP_SPEED:
		# Слышит бег: знает, где игрок, но не видит
		notify_target(_player.global_position)

	if sees:
		_last_known_position = _player.global_position
		_time_since_seen = 0.0
		_searching_points = false
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

	_ai_time += delta
	# Особые типы: взрывной поджигает фитиль рядом, плевун стреляет издалека
	if data.behavior == ZombieData.Behavior.EXPLODER and can_see \
			and distance <= data.explode_trigger_distance:
		_start_fuse()
		return
	if data.behavior == ZombieData.Behavior.RANGED and can_see and _ranged_cooldown <= 0.0 \
			and distance >= data.ranged_min_distance and distance <= data.ranged_max_distance:
		_start_ranged()
		return

	# Очередь атак: вблизи пытаемся занять место, далеко или без видимости — освобождаем
	# После удара (кулдаун) место не занимаем — отходим на кольцо, пропуская других
	if can_see and distance <= ENGAGE_DISTANCE and _cooldown <= 0.0:
		_try_take_token()
	elif _has_token and (not can_see or distance > ENGAGE_DISTANCE + 1.5):
		_release_token()

	if can_see and distance <= ENGAGE_DISTANCE and not _has_token:
		# Очередь занята: держимся на кольце и обходим игрока по кругу
		_set_state(State.CHASE)
		# Точка на кольце чуть впереди по ходу обхода от текущего положения зомби
		var from_player: Vector3 = _flat(global_position - player_position)
		var around: float = atan2(from_player.z, from_player.x) + _circle_direction * CIRCLE_LEAD
		var ring: Vector3 = player_position + Vector3(cos(around), 0.0, sin(around)) * WAIT_RING_DISTANCE
		_move_to(ring, data.move_speed * _speed_multiplier * WAIT_SPEED_FACTOR, delta)
		_face(_flat(player_position - global_position), delta)
		return

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

	# Не видит: идёт к последней известной точке, потом обыскивает точки вокруг
	if state != State.SEARCH:
		_searching_points = false
		_search_left = data.search_points
	_set_state(State.SEARCH)
	var goal: Vector3 = _search_target if _searching_points else _last_known_position
	if _flat_distance_to(goal) <= SEARCH_REACHED_DISTANCE:
		if _search_left > 0 and _pick_search_point():
			_search_left -= 1
			return
		_set_desired_velocity(Vector3.ZERO)
		rotation.y += SEARCH_TURN_SPEED * delta
		_play_locomotion(0.0)
	else:
		_move_to(goal, data.move_speed * _speed_multiplier * 0.85, delta)


## Случайная точка на навмеше вокруг места, где игрока видели последним
func _pick_search_point() -> bool:
	if not _is_navigation_ready():
		return false
	var angle: float = _rng.randf() * TAU
	var radius: float = _rng.randf_range(data.search_radius * 0.4, data.search_radius)
	var candidate: Vector3 = _last_known_position + Vector3(cos(angle), 0.0, sin(angle)) * radius
	_search_target = NavigationServer3D.map_get_closest_point(_agent.get_navigation_map(), candidate)
	_searching_points = true
	_path_timer = 0.0
	return true


# ---------- Очередь атак ----------

func _exit_tree() -> void:
	_release_token()


func _try_take_token() -> void:
	if _has_token:
		return
	if not data.uses_attack_queue:
		_has_token = true
		return
	_cleanup_attackers()
	if _attackers.size() < MAX_ATTACKERS:
		_attackers.append(self)
		_has_token = true


func _release_token() -> void:
	if not _has_token:
		return
	_has_token = false
	_attackers.erase(self)


## Убираем из очереди удалённых и мёртвых (например, после смены сцены)
static func _cleanup_attackers() -> void:
	for i in range(_attackers.size() - 1, -1, -1):
		var zombie: Zombie = _attackers[i]
		if not is_instance_valid(zombie) or not zombie.is_inside_tree() or zombie.state == State.DEAD:
			_attackers.remove_at(i)


func _chase_point(player_position: Vector3, distance: float) -> Vector3:
	# Упреждение движения игрока
	var predicted: Vector3 = player_position + _flat(_player.velocity) * data.prediction_time
	if distance <= FLANK_MIN_DISTANCE:
		return predicted
	var point: Vector3
	if data.flank_from_behind:
		# Заходит со спины: точка за игроком со своим смещением по углу
		var back: Vector3 = _flat(_player.global_basis.z).normalized()
		var spread: float = (_flank_angle / TAU - 0.5) * 2.0 * BEHIND_SPREAD
		point = predicted + back.rotated(Vector3.UP, spread) * BEHIND_DISTANCE
	else:
		# Издалека каждый заходит со своей стороны → окружают
		point = predicted + Vector3(cos(_flank_angle), 0.0, sin(_flank_angle)) * FLANK_RADIUS
	return point + _zigzag_offset(distance)


## Боковое смещение, когда игрок целится в зомби (уворачивается от пуль)
func _zigzag_offset(distance: float) -> Vector3:
	if data.zigzag_amplitude <= 0.0 or distance < ZIGZAG_MIN_DISTANCE:
		return Vector3.ZERO
	var to_zombie: Vector3 = _flat(global_position - _player.global_position)
	if to_zombie.length_squared() < 0.01:
		return Vector3.ZERO
	to_zombie = to_zombie.normalized()
	var aim: Vector3 = _flat(-_player.global_basis.z).normalized()
	if aim.dot(to_zombie) < AIMED_AT_COS:
		return Vector3.ZERO
	var side: Vector3 = to_zombie.cross(Vector3.UP)
	return side * sin(_ai_time * data.zigzag_frequency * TAU) * data.zigzag_amplitude


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
		# Отдаём место в очереди, чтобы ударили другие (сразу встанет в конец)
		_release_token()


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


# ---------- Плевун и взрывной ----------

func _start_ranged() -> void:
	_set_state(State.RANGED)
	_special_elapsed = 0.0
	_special_hit_done = false
	_voice(Sfx.sounds.zombie_attack, 0.0)
	_play(anim_attack, true)


func _process_ranged(delta: float) -> void:
	_special_elapsed += delta
	_face(_flat(_player.global_position - global_position), delta)
	_set_desired_velocity(Vector3.ZERO)
	if not _special_hit_done and _special_elapsed >= data.ranged_windup:
		_special_hit_done = true
		_spit()
	if _special_elapsed >= data.ranged_windup + RANGED_RECOVERY:
		_ranged_cooldown = data.ranged_cooldown
		_set_state(State.CHASE)


## Комок кислоты по дуге в точку, где игрок будет через полёт
func _spit() -> void:
	var from: Vector3 = global_position + Vector3.UP * SPIT_HEIGHT * _size_factor - global_basis.z * 0.5
	var target: Vector3 = _player.global_position + Vector3.UP * 1.2
	var flight: float = from.distance_to(target) / maxf(data.projectile_speed, 1.0)
	target += _flat(_player.velocity) * flight * 0.7
	var projectile := AcidProjectile.new()
	projectile.damage = data.projectile_damage * damage_multiplier
	get_tree().current_scene.add_child(projectile)
	projectile.launch(from, target, data.projectile_speed)


func _start_fuse() -> void:
	_set_state(State.FUSE)
	_special_elapsed = 0.0
	_set_desired_velocity(Vector3.ZERO)
	_voice(Sfx.sounds.zombie_attack, 4.0)
	_play(anim_idle, true)


## Фитиль: раздувается и мигает, потом взрыв
func _process_fuse(delta: float) -> void:
	_special_elapsed += delta
	_set_desired_velocity(Vector3.ZERO)
	var progress: float = clampf(_special_elapsed / maxf(data.explode_fuse, 0.05), 0.0, 1.0)
	if visual != null:
		visual.scale = Vector3.ONE * (1.0 + FUSE_SWELL * progress)
	_set_flash(fmod(_special_elapsed, 0.2) < 0.1)
	if progress >= 1.0:
		_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	if visual != null:
		visual.scale = Vector3.ONE
	Explosion.create(get_tree().current_scene, global_position + Vector3.UP * 0.5,
		data.explode_radius, data.explode_damage * damage_multiplier, 1.0)
	if health != null and not health.is_dead:
		health.take_damage(health.current + 1.0, global_position, false)


func _try_stagger(is_headshot: bool) -> void:
	if data.stagger_time <= 0.0 or _stagger_cooldown > 0.0 or state == State.DEAD:
		return
	_stagger_left = data.stagger_time * (HEADSHOT_STAGGER_MULTIPLIER if is_headshot else 1.0)
	_release_token()
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
	if data.behavior == ZombieData.Behavior.EXPLODER and data.explode_on_death and not _exploded:
		# Отложенно: смерть случается внутри обработки выстрела/другого взрыва
		_explode.call_deferred()
	_release_token()
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


## Убрать зомби без смерти и награды (спавнер открытого мира)
func despawn() -> void:
	if state == State.DEAD or not is_inside_tree():
		return
	_release_token()
	state = State.DEAD
	despawned.emit(self)
	queue_free()


## Удар машиной: урон по скорости, отбрасывание; погибший отлетает
func hit_by_vehicle(damage: float, push: Vector3) -> void:
	apply_blast(damage, push)


## Урон с отбрасыванием (машина, взрыв); погибший отлетает по дуге
func apply_blast(damage: float, push: Vector3) -> void:
	if state == State.DEAD or health == null:
		return
	health.take_damage(damage, global_position + Vector3.UP, false)
	if state == State.DEAD:
		# Отлёт тела по дуге (в состоянии DEAD физика зомби не работает)
		var target: Vector3 = global_position + Vector3(push.x, 0.0, push.z) * 0.35
		var fly := create_tween().set_parallel(true)
		fly.tween_property(self, "global_position:x", target.x, 0.5).set_ease(Tween.EASE_OUT)
		fly.tween_property(self, "global_position:z", target.z, 0.5).set_ease(Tween.EASE_OUT)
		var up := create_tween()
		up.tween_property(self, "global_position:y", global_position.y + minf(push.length() * 0.08, 1.5), 0.2) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		up.tween_property(self, "global_position:y", global_position.y, 0.3) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	else:
		velocity += Vector3(push.x, 2.0, push.z)
		_try_stagger(false)


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


## Во сколько раз модель выше стандартной (для звука)
func _model_height_factor() -> float:
	return _size_factor


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
	# Overlay поверх любого материала: работает и с текстурированной моделью.
	# Без вспышки возвращается постоянный оттенок типа (если есть)
	for geometry: GeometryInstance3D in _geometries:
		if is_instance_valid(geometry):
			geometry.material_overlay = _flash_material if enabled else _tint_material


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


## Хитбоксы под реальный размер модели. Размер меряется по кости Head скелета
## (у Chubby голова в ~2 раза выше, чем у Zombie_Basic), без скелета — по model_scale.
## Формы дублируются — они общие для всех зомби из zombie.tscn.
## Хитбокс головы дальше следует за костью головы в анимации (_update_head_hitbox).
func _fit_hitboxes() -> void:
	_size_factor = _measure_size_factor()
	if not is_equal_approx(_size_factor, 1.0):
		for hitbox: Hitbox in _hitboxes:
			for shape_node: Node in hitbox.get_children():
				var collision := shape_node as CollisionShape3D
				if collision == null or collision.shape == null:
					continue
				collision.position *= _size_factor
				var shape: Shape3D = collision.shape.duplicate() as Shape3D
				if shape is CapsuleShape3D:
					var capsule := shape as CapsuleShape3D
					capsule.radius *= _size_factor
					capsule.height *= _size_factor
				elif shape is SphereShape3D:
					(shape as SphereShape3D).radius *= _size_factor
				elif shape is BoxShape3D:
					(shape as BoxShape3D).size *= _size_factor
				collision.shape = shape

	# Ползун и собака: капсула тела лежит вдоль земли
	if data.hitbox_lying:
		for hitbox: Hitbox in _hitboxes:
			if hitbox.is_head:
				continue
			for shape_node: Node in hitbox.get_children():
				var lying := shape_node as CollisionShape3D
				if lying == null or not lying.shape is CapsuleShape3D:
					continue
				var radius: float = (lying.shape as CapsuleShape3D).radius
				lying.rotation.x = PI * 0.5
				lying.position = Vector3(lying.position.x, radius, -0.2 * _size_factor)

	# Голова следует за костью
	if _skeleton == null or _head_bone < 0:
		return
	for hitbox: Hitbox in _hitboxes:
		if not hitbox.is_head:
			continue
		for shape_node: Node in hitbox.get_children():
			if shape_node is CollisionShape3D:
				_head_shape = shape_node as CollisionShape3D
				break
		break
	_head_offset = HEAD_OFFSET_REFERENCE * _size_factor
	_update_head_hitbox()


## Во сколько раз модель больше Zombie_Basic (1.0 — такая же)
func _measure_size_factor() -> float:
	var fallback: float = 1.0 if data.model_scene == null else data.model_scale / DEFAULT_MODEL_SCALE
	if visual == null:
		return fallback
	var skeletons: Array[Node] = visual.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return fallback
	_skeleton = skeletons[0] as Skeleton3D
	_head_bone = _skeleton.find_bone(HEAD_BONE)
	if _head_bone < 0:
		if not _warned_types.has(data.display_name):
			_warned_types[data.display_name] = true
			push_warning("Zombie: у типа %s в скелете нет кости %s, хитбоксы по model_scale" % [
				data.display_name, HEAD_BONE])
		_skeleton = null
		return fallback
	_skeleton_to_body = _transform_to_body(_skeleton)
	var head: Vector3 = _skeleton_to_body * _skeleton.get_bone_global_rest(_head_bone).origin
	if head.y <= 0.1:
		return fallback
	return clampf(head.y / REFERENCE_HEAD_HEIGHT, 0.5, 4.0)


## Хитбокс головы в текущей позе кости Head (каждый физический кадр, без аллокаций)
func _update_head_hitbox() -> void:
	if _head_shape == null or _skeleton == null:
		return
	var bone: Vector3 = _skeleton_to_body * _skeleton.get_bone_global_pose(_head_bone).origin
	_head_shape.position = bone + _head_offset


## Трансформ ноды в координатах зомби (по цепочке родителей, без global_*)
func _transform_to_body(node: Node3D) -> Transform3D:
	var result: Transform3D = Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != self:
		var current_3d := current as Node3D
		if current_3d != null:
			result = current_3d.transform * result
		current = current.get_parent()
	return result


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

	if data.tint.a > 0.0:
		_tint_material = StandardMaterial3D.new()
		_tint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tint_material.albedo_color = data.tint
		_set_flash(false)


## Свои имена анимаций из ZombieData (собака: Attack, HitReact_Left и т.п.)
func _apply_animation_overrides() -> void:
	if data.anim_idle != &"":
		anim_idle = data.anim_idle
	if data.anim_walk != &"":
		anim_walk = data.anim_walk
	if data.anim_run != &"":
		anim_run = data.anim_run
	if data.anim_attack != &"":
		anim_attack = data.anim_attack
	if data.anim_hit != &"":
		anim_hit = data.anim_hit
	if data.anim_death != &"":
		anim_death = data.anim_death


func _find_player() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null:
		push_warning("Zombie '%s': игрок не найден (группа player)" % name)
		return
	_player_health = _player.health
	var manager: WeaponManager = _player.weapon_manager
	if manager != null and not manager.fired.is_connected(_on_player_fired):
		manager.fired.connect(_on_player_fired)
