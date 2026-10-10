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
## Игрок в машине: зомби бьют машину (раз в столько секунд проверяем, в машине ли он)
const CAR_CHECK_INTERVAL: float = 0.5
const FLANK_RADIUS: float = 2.0
## Ближе этого — идёт прямо на игрока, без обхода с фланга
const FLANK_MIN_DISTANCE: float = 4.0
const SEARCH_REACHED_DISTANCE: float = 1.2
const SEARCH_TURN_SPEED: float = 1.2
const WANDER_REACHED_DISTANCE: float = 0.8
const STAGGER_COOLDOWN: float = 1.0
const HEADSHOT_STAGGER_MULTIPLIER: float = 1.8
const STUCK_TIME: float = 0.6
const UNSTUCK_DURATION: float = 0.6
## Ступенька (бордюр, тротуар), на которую зомби шагает без прыжка
const STEP_HEIGHT: float = 0.4
## Перед стеной путь сворачивает вдоль неё на это время
const WALL_FOLLOW_TIME: float = 0.35
## После стольких застреваний подряд — перенос на ближайшую точку навмеша
const MAX_UNSTUCK_TRIES: int = 4
## Дальше этого от навмеша зомби считается «выпавшим» с него
const OFF_MESH_DISTANCE: float = 0.8
## Мягкое расталкивание толпы: радиус, сила и как часто пересчитывать
const SEPARATION_RADIUS: float = 1.1
const SEPARATION_WEIGHT: float = 1.2
const SEPARATION_INTERVAL: float = 0.1
## Все живые зомби (для расталкивания без поиска по группе)
static var _all: Array[Zombie] = []
var _separation: Vector3 = Vector3.ZERO
var _separation_timer: float = 0.0
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

## Мультиплеер (хост): цель — ближайший живой игрок, включая чужих (ставит MatchManager)
static var multi_target: bool = false
const RETARGET_INTERVAL: float = 1.0
## Дальний зомби (дальше этого от цели): анимация ~20 к/с вместо каждого кадра, хитбокс головы не двигаем
const FAR_DISTANCE: float = 26.0
const LOD_CHECK_INTERVAL: float = 0.5
const FAR_ANIM_STEP: float = 0.05

## Кто сейчас атакует (общая очередь всех зомби)
static var _attackers: Array[Zombie] = []
static var _flank_counter: int = 0
## Типы, о которых уже предупредили (без спама в лог на каждом спавне)
static var _warned_types: Dictionary = {}

## Плевок: пауза после выстрела и точка вылета (доля высоты модели)
const RANGED_RECOVERY: float = 0.4
const SPIT_HEIGHT: float = 1.4
## Крик бандита не чаще, сек
const TAUNT_COOLDOWN: float = 7.0
## Взрывной раздувается перед взрывом
const FUSE_SWELL: float = 0.35
## Ниже этой высоты зомби считается провалившимся за карту
const FALL_LIMIT_Y: float = -15.0
## Кость головы в скелетах Quaternius
const HEAD_BONE: StringName = &"Head"
## Высота кости Head у Zombie_Basic в масштабе 1.6 (под неё настроены хитбоксы zombie.tscn)
const REFERENCE_HEAD_HEIGHT: float = 1.216
## Центр хитбокса головы относительно кости Head у Zombie_Basic (в осях зомби)
const HEAD_OFFSET_REFERENCE: Vector3 = Vector3(0.018, 0.234, -0.179)
## Масштаб модели Visual/Model в zombie.tscn (под него настроены хитбоксы)
const DEFAULT_MODEL_SCALE: float = 1.6

@export var data: ZombieData

## Мультиплеер на клиенте: копия зомби хоста — без ИИ, только позиция и анимации из сети
var net_puppet: bool = false
var net_id: int = 0

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
var _far: bool = false
var _lod_timer: float = 0.0
var _anim_accum: float = 0.0
## Машина, в которой сидит цель (бьём её, а не игрока)
var _target_car: DrivableCar
var _car_check_left: float = 0.0
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
var _unstuck_tries: int = 0
var _unstuck_side: float = 1.0
var _wall_normal: Vector3 = Vector3.ZERO
var _wall_follow_left: float = 0.0
var _wall_follow_direction: Vector3 = Vector3.ZERO

# Бой
var _cooldown: float = 0.0
var _attack_elapsed: float = 0.0
var _attack_hit_done: bool = false
var _stagger_left: float = 0.0
var _stagger_cooldown: float = 0.0
## Капкан держит на месте (секунд осталось)
var _hold_left: float = 0.0
## Крик соседа-крикуна: ускорение, пока _boost_left > 0
var _boost_left: float = 0.0
var _base_speed_multiplier: float = 1.0
## Каска (ZombieData.helmet_health) и броня спереди (front_armor)
var _helmet_left: float = 0.0
var _helmet: Node3D
var _armor_plate: Node3D
var _armor_sound_cooldown: float = 0.0

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
# Бандит
var _shots_left: int = 0
var _shot_timer: float = 0.0
var _taunt_cooldown: float = 0.0
var _taunt_label: Label3D
static var _tracer_material: StandardMaterial3D
var _exploded: bool = false
var _tint_material: StandardMaterial3D

# Хитбоксы под модель
var _size_factor: float = 1.0
var _skeleton: Skeleton3D
var _head_bone: int = -1
var _skeleton_to_body: Transform3D = Transform3D.IDENTITY
var _head_shape: CollisionShape3D
var _head_offset: Vector3 = Vector3.ZERO

# Сеть
var _retarget_timer: float = 0.0
var _net_position: Vector3 = Vector3.ZERO
var _net_yaw: float = 0.0
var _net_state: int = State.WANDER
var _net_last_state: int = -1
var _net_speed: float = 0.0
var _net_has_state: bool = false

# Звук
var _voice_timer: float = 0.0
var _hurt_sound_cooldown: float = 0.0


func _ready() -> void:
	add_to_group(&"zombies")
	_all.append(self)
	collision_layer = PhysicsLayers.ENEMY
	# Друг с другом не сталкиваются (толпа запирала сама себя в проходах) — держат дистанцию
	# мягким расталкиванием (_update_separation)
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.PLAYER

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
	_separation_timer = _rng.randf() * SEPARATION_INTERVAL  # не все зомби в один кадр
	_speed_multiplier = 1.0 + _rng.randf_range(-data.speed_variation, data.speed_variation)
	_base_speed_multiplier = _speed_multiplier
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
	_setup_armor()
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
	if net_puppet:
		_puppet_process(delta)
		return
	if multi_target:
		_retarget_timer -= delta
		if _retarget_timer <= 0.0:
			_retarget_timer = RETARGET_INTERVAL
			_pick_nearest_target()
	if global_position.y < FALL_LIMIT_Y:
		despawn()  # провалился за карту — убираем без награды
		return
	_update_lod(delta)
	if not _far:
		_update_head_hitbox()

	if not is_on_floor():
		velocity.y -= _gravity * delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	_stagger_cooldown = maxf(_stagger_cooldown - delta, 0.0)
	_hurt_sound_cooldown = maxf(_hurt_sound_cooldown - delta, 0.0)
	_charge_cooldown = maxf(_charge_cooldown - delta, 0.0)
	_ranged_cooldown = maxf(_ranged_cooldown - delta, 0.0)
	_taunt_cooldown = maxf(_taunt_cooldown - delta, 0.0)
	_slam_cooldown = maxf(_slam_cooldown - delta, 0.0)
	_hold_left = maxf(_hold_left - delta, 0.0)
	_armor_sound_cooldown = maxf(_armor_sound_cooldown - delta, 0.0)
	if _boost_left > 0.0:
		_boost_left -= delta
		if _boost_left <= 0.0:
			_speed_multiplier = _base_speed_multiplier
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
	# Игрок в машине: кузов не загораживает его
	if _target_car != null and is_instance_valid(_target_car):
		query.exclude = [get_rid(), _target_car.get_rid()]
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
	_car_check_left -= delta
	if _car_check_left <= 0.0:
		_car_check_left = CAR_CHECK_INTERVAL
		_target_car = DrivableCar.find_car_with(_player)
	if _target_car != null and is_instance_valid(_target_car):
		# Игрок в машине: «дистанция» — до кузова, иначе спереди и сзади зомби не дотянуться
		distance = _target_car.distance_to_body(global_position)
	var can_see: bool = _time_since_seen <= VISIBLE_GRACE

	_ai_time += delta
	# Особые типы: взрывной поджигает фитиль рядом, плевун стреляет издалека
	if data.behavior == ZombieData.Behavior.EXPLODER and can_see \
			and distance <= data.explode_trigger_distance:
		_start_fuse()
		return
	if (data.behavior == ZombieData.Behavior.RANGED or data.behavior == ZombieData.Behavior.GUNNER
			or data.behavior == ZombieData.Behavior.SCREAMER) \
			and can_see and _ranged_cooldown <= 0.0 \
			and distance >= data.ranged_min_distance and distance <= data.ranged_max_distance \
			and _has_line_of_fire():
		_start_ranged()
		return
	# Бандит между очередями (и крикун между криками) не лезет в рукопашную: держит дистанцию и ходит боком
	if (data.behavior == ZombieData.Behavior.GUNNER or data.behavior == ZombieData.Behavior.SCREAMER) \
			and can_see and distance > data.ranged_min_distance \
			and distance <= data.preferred_distance * 1.4:
		_set_state(State.CHASE)
		_strafe(player_position, distance, delta)
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
	_all.erase(self)


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
		var car: DrivableCar = DrivableCar.find_car_with(_player)
		if car != null and not car.is_broken():
			# Игрок в машине — достаётся кузову (сломанная уже не защищает)
			if car.distance_to_body(global_position) <= data.attack_range * ATTACK_HIT_TOLERANCE:
				car.take_damage(data.attack_damage * damage_multiplier, global_position, self)
		elif car != null:
			if car.distance_to_body(global_position) <= data.attack_range * ATTACK_HIT_TOLERANCE:
				_player_health.take_damage_from(data.attack_damage * damage_multiplier, global_position, false,
				Health.Kind.MELEE, "", self)
		# Игрок успел отбежать — промах
		elif to_player.length() <= data.attack_range * ATTACK_HIT_TOLERANCE:
			_player_health.take_damage_from(data.attack_damage * damage_multiplier, global_position, false,
			Health.Kind.MELEE, "", self)

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
		_player_health.take_damage_from(data.charge_damage * damage_multiplier, global_position, false,
			Health.Kind.MELEE, "", self)
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
			_player_health.take_damage_from(data.slam_damage * damage_multiplier, global_position, false,
			Health.Kind.MELEE, "", self)
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
	_shots_left = data.burst_shots
	_shot_timer = data.ranged_windup
	if data.behavior == ZombieData.Behavior.GUNNER:
		_play(data.anim_shoot if _has_anim(data.anim_shoot) else anim_idle, true)
		return
	if data.behavior == ZombieData.Behavior.SCREAMER:
		_play(data.anim_scream if _has_anim(data.anim_scream) else anim_attack, true)
		return
	_voice(Sfx.sounds.zombie_attack, 0.0)
	_play(anim_attack, true)


func _process_ranged(delta: float) -> void:
	if data.behavior == ZombieData.Behavior.GUNNER:
		_process_gunner(delta)
		return
	_special_elapsed += delta
	_face(_flat(_player.global_position - global_position), delta)
	_set_desired_velocity(Vector3.ZERO)
	if not _special_hit_done and _special_elapsed >= data.ranged_windup:
		_special_hit_done = true
		if data.behavior == ZombieData.Behavior.SCREAMER:
			_scream()
		else:
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


# ---------- Крикун (SCREAMER) ----------

## Крик: зомби в радиусе узнают, где игрок, и бегут быстрее; миссия присылает подмогу
func _scream() -> void:
	_voice(Sfx.sounds.zombie_attack, 9.0)
	_voice(Sfx.sounds.zombie_hurt, 6.0)
	_spawn_scream_ring()
	if _player == null:
		return
	var target: Vector3 = _player.global_position
	var radius_squared: float = data.scream_radius * data.scream_radius
	for other: Zombie in _all:
		if other == self or not is_instance_valid(other) or other.state == State.DEAD or other.net_puppet:
			continue
		if other.global_position.distance_squared_to(global_position) > radius_squared:
			continue
		other.notify_target(target)
		other.boost(data.scream_boost_time, data.scream_boost)
	if _flat_distance_to(target) <= data.scream_radius:
		_player.shake(0.25)
	if data.scream_reinforcements > 0 and not net_puppet:
		var manager := get_tree().get_first_node_in_group(&"mission_manager") as MissionManager
		if manager != null:
			manager.call_reinforcements(data.scream_reinforcements)


## Ускорение от крика (не складывается: берётся большее время)
func boost(seconds: float, factor: float) -> void:
	if state == State.DEAD or seconds <= 0.0:
		return
	_boost_left = maxf(_boost_left, seconds)
	_speed_multiplier = _base_speed_multiplier * maxf(factor, 1.0)


## Волна крика — расходящееся кольцо у ног
func _spawn_scream_ring() -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.75, 0.35, 1.0, 0.7)
	torus.material = material
	ring.mesh = torus
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(ring)
	ring.global_position = global_position + Vector3.UP * (1.4 * _size_factor)
	var tween := ring.create_tween().set_parallel(true)
	var final_scale: float = minf(data.scream_radius, 12.0)
	tween.tween_property(ring, "scale", Vector3(final_scale, 1.0, final_scale), 0.8) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.8)
	tween.chain().tween_callback(ring.queue_free)


# ---------- Каска и броня ----------

func _setup_armor() -> void:
	if data.helmet_health > 0.0:
		_helmet_left = data.helmet_health
		_build_helmet()
	if data.front_armor < 1.0:
		_build_armor_plate()
	if _helmet_left <= 0.0 and data.front_armor >= 1.0:
		return
	for hitbox: Hitbox in _hitboxes:
		hitbox.damage_filter = _filter_damage.bind(hitbox)


## Каска поглощает выстрелы в голову, броня — в тело спереди (искры и звон вместо крови)
func _filter_damage(amount: float, hit_position: Vector3, is_head: bool, hitbox: Hitbox) -> float:
	if state == State.DEAD:
		return amount
	if is_head and _helmet_left > 0.0:
		_helmet_left -= amount
		_ring_metal(hit_position, 1.3)
		if _helmet_left <= 0.0:
			_knock_off_helmet(hit_position)
		# Удар по каске оглушает, но урон проходит малой долей и не как хедшот
		if hitbox.health != null:
			hitbox.health.take_damage(amount * data.helmet_pass, hit_position, false)
		return 0.0
	if not is_head and data.front_armor < 1.0:
		var forward: Vector3 = -global_basis.z
		var to_hit: Vector3 = _flat(hit_position - global_position)
		if to_hit.length_squared() > 0.0001 and forward.dot(to_hit.normalized()) > 0.35:
			_ring_metal(hit_position, 0.8)
			return amount * data.front_armor
	return amount


func _ring_metal(at: Vector3, pitch: float) -> void:
	var impacts := get_node_or_null(^"/root/Impacts") as ImpactPool
	if impacts != null:
		impacts.spawn(at, _flat(at - global_position).normalized(), false)
	if _armor_sound_cooldown <= 0.0:
		_armor_sound_cooldown = 0.12
		Sfx.play_3d(Sfx.pick(Sfx.sounds.metal_hits), at, 0.0, pitch)


## Каска на голове: следует за хитбоксом головы (он сам ходит за костью Head)
func _build_helmet() -> void:
	var head := _find_head_shape()
	if head == null:
		return
	var radius: float = 0.27 * _size_factor
	var sphere := head.shape as SphereShape3D
	if sphere != null:
		radius = sphere.radius
	var material := StandardMaterial3D.new()
	material.albedo_color = data.helmet_color
	material.roughness = 0.45
	material.metallic = 0.4
	_helmet = Node3D.new()
	_helmet.name = "Helmet"
	head.add_child(_helmet)
	var dome := SphereMesh.new()
	dome.radius = radius * 1.08
	dome.height = radius * 1.08
	dome.is_hemisphere = true
	dome.material = material
	var dome_instance := MeshInstance3D.new()
	dome_instance.mesh = dome
	dome_instance.position = Vector3(0.0, radius * 0.05, 0.0)
	_helmet.add_child(dome_instance)
	var brim := CylinderMesh.new()
	brim.top_radius = radius * 1.25
	brim.bottom_radius = radius * 1.25
	brim.height = radius * 0.08
	brim.material = material
	var brim_instance := MeshInstance3D.new()
	brim_instance.mesh = brim
	brim_instance.position = Vector3(0.0, radius * 0.05, 0.0)
	_helmet.add_child(brim_instance)


## Каска слетает: летит вверх и назад, кувыркаясь, и исчезает
func _knock_off_helmet(hit_position: Vector3) -> void:
	if _helmet == null:
		return
	var helmet: Node3D = _helmet
	_helmet = null
	var start: Transform3D = helmet.global_transform
	helmet.top_level = true
	helmet.global_transform = start
	var away: Vector3 = _flat(start.origin - hit_position)
	away = away.normalized() if away.length_squared() > 0.0001 else -global_basis.z
	var tween := helmet.create_tween().set_parallel(true)
	tween.tween_property(helmet, "global_position", start.origin + away * 1.6 + Vector3.UP * 0.4, 0.35) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(helmet, "rotation", helmet.rotation + Vector3(4.0, 0.0, 2.5), 0.7)
	tween.chain().tween_property(helmet, "global_position:y", global_position.y + 0.1, 0.35) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_interval(2.0)
	tween.chain().tween_callback(helmet.queue_free)
	Sfx.play_3d(Sfx.pick(Sfx.sounds.metal_hits), hit_position, 4.0, 1.6)


## Нагрудник бугая: пластина спереди тела (видно, куда не стрелять)
func _build_armor_plate() -> void:
	if visual == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = data.armor_color
	material.roughness = 0.5
	material.metallic = 0.5
	_armor_plate = Node3D.new()
	_armor_plate.name = "ArmorPlate"
	visual.add_child(_armor_plate)
	var plate := BoxMesh.new()
	plate.size = Vector3(0.85, 0.75, 0.08) * _size_factor
	plate.material = material
	var plate_instance := MeshInstance3D.new()
	plate_instance.mesh = plate
	plate_instance.position = Vector3(0.0, 0.95, -0.42) * _size_factor
	plate_instance.rotation.x = -0.12
	_armor_plate.add_child(plate_instance)
	# Заклёпки
	var rivet := SphereMesh.new()
	rivet.radius = 0.035 * _size_factor
	rivet.height = 0.07 * _size_factor
	rivet.material = material
	for x: float in [-0.32, 0.32]:
		for y: float in [0.7, 1.2]:
			var rivet_instance := MeshInstance3D.new()
			rivet_instance.mesh = rivet
			rivet_instance.position = Vector3(x, y, -0.47) * _size_factor
			_armor_plate.add_child(rivet_instance)


func _find_head_shape() -> CollisionShape3D:
	if _head_shape != null:
		return _head_shape
	for hitbox: Hitbox in _hitboxes:
		if not hitbox.is_head:
			continue
		for shape_node: Node in hitbox.get_children():
			if shape_node is CollisionShape3D:
				return shape_node as CollisionShape3D
	return null


# ---------- Бандит (GUNNER) ----------

## Прицелился → очередь из burst_shots выстрелов → короткая пауза
func _process_gunner(delta: float) -> void:
	_face(_flat(_player.global_position - global_position), delta)
	_set_desired_velocity(Vector3.ZERO)
	_shot_timer -= delta
	if _shot_timer > 0.0:
		return
	if _shots_left > 0:
		_shots_left -= 1
		_shot_timer = data.shot_interval
		_fire_shot()
		return
	_ranged_cooldown = data.ranged_cooldown * _rng.randf_range(0.8, 1.25)
	_circle_direction = -_circle_direction  # после очереди — шаг в другую сторону
	_set_state(State.CHASE)


## Выстрел: попадание по шансу (дальше и по бегущему — хуже), стена между — пуля в стену
func _fire_shot() -> void:
	var muzzle: Vector3 = global_position + Vector3.UP * SPIT_HEIGHT * _size_factor - global_basis.z * 0.55
	var target: Vector3 = _player.global_position + Vector3.UP * 1.25
	var distance: float = muzzle.distance_to(target)
	var moving: float = clampf(_flat(_player.velocity).length() / 5.0, 0.0, 1.0)
	var chance: float = data.accuracy * clampf(1.15 - distance / maxf(data.ranged_max_distance, 1.0) * 0.6, 0.3, 1.0) \
		* (1.0 - 0.45 * moving)
	var hit: bool = _rng.randf() < chance
	if not hit:
		# Промах: пуля летит рядом с игроком
		var side: Vector3 = _flat(target - muzzle).cross(Vector3.UP).normalized()
		target += side * _rng.randf_range(-1.2, 1.2) + Vector3.UP * _rng.randf_range(-0.6, 0.8)
	var query := PhysicsRayQueryParameters3D.create(muzzle, target + (target - muzzle).normalized() * 2.0,
		PhysicsLayers.WORLD)
	query.exclude = [get_rid()]
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3 = target
	if not result.is_empty():
		var wall: Vector3 = result["position"]
		if muzzle.distance_to(wall) < distance - 0.3 or not hit:
			end = wall
			hit = false
			var impacts := get_node_or_null(^"/root/Impacts") as ImpactPool
			if impacts != null:
				impacts.spawn(wall, result["normal"], false)
	if hit and _player_health != null:
		_player_health.take_damage_from(data.shot_damage * damage_multiplier, muzzle, false,
			Health.Kind.BULLET, data.display_name, self)
	if data.gun_sound != null:
		Sfx.play_3d(data.gun_sound, muzzle, -2.0, _rng.randf_range(0.92, 1.08))
	_spawn_tracer(muzzle, end)
	_flash_muzzle(muzzle)


## Есть ли прямая линия выстрела до цели (не стреляет в стену)
func _has_line_of_fire() -> bool:
	if data.behavior != ZombieData.Behavior.GUNNER:
		return true
	var from: Vector3 = global_position + Vector3.UP * SPIT_HEIGHT * _size_factor
	var query := PhysicsRayQueryParameters3D.create(from, _player.global_position + Vector3.UP * 1.2,
		PhysicsLayers.WORLD)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Ходит боком вокруг цели, держа дистанцию preferred_distance
func _strafe(player_position: Vector3, distance: float, delta: float) -> void:
	var from_player: Vector3 = _flat(global_position - player_position)
	var around: float = atan2(from_player.z, from_player.x) + _circle_direction * 0.5
	var keep: float = lerpf(distance, data.preferred_distance, 0.5)
	var point: Vector3 = player_position + Vector3(cos(around), 0.0, sin(around)) * keep
	_move_to(point, data.move_speed * _speed_multiplier * 0.6, delta)
	_face(_flat(player_position - global_position), delta)


## След пули — тонкая светящаяся полоска, гаснет за 0.08 с
func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var length: float = from.distance_to(to)
	if length < 0.5:
		return
	if _tracer_material == null:
		_tracer_material = StandardMaterial3D.new()
		_tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tracer_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tracer_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_tracer_material.albedo_color = Color(1.0, 0.85, 0.5, 0.9)
	var box := BoxMesh.new()
	box.size = Vector3(0.03, 0.03, length)
	var tracer := MeshInstance3D.new()
	tracer.mesh = box
	tracer.material_override = _tracer_material
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(tracer)
	tracer.global_position = (from + to) * 0.5
	tracer.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	get_tree().create_timer(0.08, false).timeout.connect(tracer.queue_free)


func _flash_muzzle(at: Vector3) -> void:
	var impacts := get_node_or_null(^"/root/Impacts") as ImpactPool
	if impacts != null:
		impacts.spawn(at, -global_basis.z, false)


## Крик бандита над головой, когда он замечает цель
func _taunt() -> void:
	if not data.human or _taunt_cooldown > 0.0:
		return
	var line: String = VoiceOver.pick_random_line(data.taunts_ru, data.taunts_en)
	if line.is_empty():
		return
	_taunt_cooldown = TAUNT_COOLDOWN * _rng.randf_range(0.8, 1.6)
	if _taunt_label == null:
		_taunt_label = Label3D.new()
		_taunt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_taunt_label.font_size = 40
		_taunt_label.outline_size = 12
		_taunt_label.pixel_size = 0.004
		_taunt_label.no_depth_test = true
		_taunt_label.modulate = Color(1.0, 0.55, 0.4)
		_taunt_label.position = Vector3.UP * 2.3 * _size_factor
		add_child(_taunt_label)
	_taunt_label.text = line
	_taunt_label.visible = true
	_taunt_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(2.2)
	tween.tween_property(_taunt_label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func() -> void: _taunt_label.visible = false)


## Встроенные стволы модели человека: показываем только held_weapon
## Стволы, встроенные в модели Quaternius Characters_* (у зомби-крикуна прячутся все)
const BUILT_IN_WEAPONS: PackedStringArray = ["Axe", "Guitar", "Knife", "Pistol", "Rifle", "Shotgun", "SMG",
	"Spear", "WoodenBat_Barbed", "WoodenBat_Saw"]


func _setup_held_weapon() -> void:
	if visual == null:
		return
	if not data.human:
		for node: Node in visual.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.skin == null and (String(mesh_instance.name) in BUILT_IN_WEAPONS
					or String(mesh_instance.get_parent().name) in BUILT_IN_WEAPONS):
				mesh_instance.visible = false
		return
	for node: Node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.skin == null:
			mesh_instance.visible = String(mesh_instance.name) == data.held_weapon \
				or String(mesh_instance.get_parent().name) == data.held_weapon


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
	# Копия на клиенте: только вид взрыва, урон считает хост
	var blast_damage: float = 0.0 if net_puppet else data.explode_damage * damage_multiplier
	Explosion.create(get_tree().current_scene, global_position + Vector3.UP * 0.5,
		data.explode_radius, blast_damage, 1.0)
	if health != null and not health.is_dead:
		health.take_damage(health.current + 1.0, global_position, false)


func _try_stagger(is_headshot: bool) -> void:
	# Взрывник с запалом не сбивается выстрелом (иначе остаётся раздутым и не взрывается)
	if data.stagger_time <= 0.0 or _stagger_cooldown > 0.0 or state == State.DEAD or state == State.FUSE:
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
	if new_state == State.CHASE and (state == State.WANDER or state == State.SEARCH):
		_taunt()
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

	# Расходимся с соседями: толпа обтекает друг друга, а не слипается в одну точку
	_update_separation(delta)
	if _separation.length_squared() > 0.0001 and direction.length_squared() > 0.0001:
		direction = direction.normalized() + _separation * SEPARATION_WEIGHT

	if _unstuck_left > 0.0:
		_unstuck_left -= delta
		direction = _unstuck_direction
	else:
		direction = _steer_around_wall(direction, delta)

	if direction.length_squared() < 0.0001:
		_set_desired_velocity(Vector3.ZERO)
		_play_locomotion(0.0)
		return

	direction = direction.normalized()
	_face(direction, delta)
	_set_desired_velocity(direction * speed)
	_play_locomotion(speed)
	_check_stuck(speed, delta)


## Отталкивание от живых зомби рядом (раз в SEPARATION_INTERVAL, без аллокаций)
func _update_separation(delta: float) -> void:
	_separation_timer -= delta
	if _separation_timer > 0.0:
		return
	_separation_timer = SEPARATION_INTERVAL
	_separation = Vector3.ZERO
	var radius_sq: float = SEPARATION_RADIUS * SEPARATION_RADIUS
	for other: Zombie in _all:
		if other == self or not is_instance_valid(other) or other.state == State.DEAD:
			continue
		var offset: Vector3 = global_position - other.global_position
		offset.y = 0.0
		var distance_sq: float = offset.length_squared()
		if distance_sq >= radius_sq:
			continue
		if distance_sq < 0.0001:
			# Стоят в одной точке — расходимся в случайную сторону
			offset = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
			distance_sq = maxf(offset.length_squared(), 0.0001)
		var distance: float = sqrt(distance_sq)
		_separation += offset / distance * (1.0 - distance / SEPARATION_RADIUS)
	if _separation.length_squared() > 1.0:
		_separation = _separation.normalized()


func _check_stuck(speed: float, delta: float) -> void:
	if _unstuck_left > 0.0:
		return
	var real: Vector3 = get_real_velocity()
	var actual: float = Vector2(real.x, real.z).length()
	if speed > 0.5 and actual < speed * 0.2:
		_stuck_time += delta
	else:
		_stuck_time = 0.0

	if actual > speed * 0.6:
		_unstuck_tries = 0

	if _stuck_time >= STUCK_TIME:
		_stuck_time = 0.0
		_path_timer = 0.0
		_unstuck_tries += 1
		if _unstuck_tries == 1:
			_snap_to_navmesh(false)  # вытолкнули с навмеша — вернуть
		if _unstuck_tries >= MAX_UNSTUCK_TRIES:
			_unstuck_tries = 0
			_snap_to_navmesh(true)
			return
		_unstuck_direction = _pick_unstuck_direction()
		_unstuck_left = UNSTUCK_DURATION


## Направление выхода из застревания: чередуем стороны вдоль стены, третья попытка — назад
func _pick_unstuck_direction() -> Vector3:
	var forward: Vector3 = _flat(-global_basis.z)
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var normal: Vector3 = _wall_normal if _wall_normal.length_squared() > 0.01 else -forward
	var tangent: Vector3 = normal.cross(Vector3.UP).normalized()
	if _unstuck_tries == 1:
		_unstuck_side = 1.0 if _rng.randf() < 0.5 else -1.0
	else:
		_unstuck_side = -_unstuck_side
	if _unstuck_tries >= 3:
		# Отступить от препятствия и чуть в сторону
		return (normal * 0.8 + tangent * _unstuck_side * 0.6).normalized()
	return (tangent * _unstuck_side + normal * 0.3).normalized()


## Упёрся в стену — идём вдоль неё в сторону цели, а не «бодаем» стену
func _steer_around_wall(direction: Vector3, delta: float) -> Vector3:
	if _wall_follow_left > 0.0:
		_wall_follow_left -= delta
		# Стена кончилась — снова прямо к цели
		if _wall_normal.length_squared() < 0.01 and _wall_follow_left < WALL_FOLLOW_TIME * 0.5:
			_wall_follow_left = 0.0
		return _wall_follow_direction
	if _wall_normal.length_squared() < 0.01 or direction.length_squared() < 0.0001:
		return direction
	var into_wall: float = direction.normalized().dot(-_wall_normal)
	if into_wall < 0.5:
		return direction  # скользит вдоль, move_and_slide справится сам
	var tangent: Vector3 = _wall_normal.cross(Vector3.UP).normalized()
	if tangent.dot(direction) < 0.0:
		tangent = -tangent
	_wall_follow_direction = (tangent + _wall_normal * 0.25).normalized()
	_wall_follow_left = WALL_FOLLOW_TIME
	return _wall_follow_direction


## Вернуть на навмеш, если вытолкнули (машина, взрыв) или безнадёжно застрял
func _snap_to_navmesh(force: bool) -> void:
	if _agent == null or not _is_navigation_ready():
		return
	var map: RID = _agent.get_navigation_map()
	var closest: Vector3 = NavigationServer3D.map_get_closest_point(map, global_position)
	var offset: Vector3 = closest - global_position
	if not force and _flat(offset).length() < OFF_MESH_DISTANCE:
		return
	if force and _flat(offset).length() < 0.05:
		# Уже на навмеше: шагнуть к следующей точке пути
		closest = NavigationServer3D.map_get_closest_point(map, _agent.get_next_path_position())
	global_position = closest + Vector3.UP * 0.1
	velocity = Vector3.ZERO
	_path_timer = 0.0


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
	if _hold_left > 0.0:
		horizontal = Vector3.ZERO  # в капкане: рвётся, но с места не сходит
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()
	_wall_normal = Vector3.ZERO
	if is_on_wall() and _is_wall_static():
		_wall_normal = _flat(get_wall_normal())
		if _wall_normal.length_squared() > 0.0001:
			_wall_normal = _wall_normal.normalized()
		_try_step_up(horizontal)


## Стена — часть мира, а не игрок или другой зомби (их обходит очередь атак)
func _is_wall_static() -> bool:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if absf(collision.get_normal().y) >= 0.7:
			continue
		var collider: Object = collision.get_collider()
		var layer: int = 0
		if collider is CollisionObject3D:
			layer = (collider as CollisionObject3D).collision_layer
		elif collider is CSGShape3D:
			layer = (collider as CSGShape3D).collision_layer
		if (layer & PhysicsLayers.WORLD) != 0:
			return true
	return false


## Шаг на низкое препятствие (бордюр, тротуар): если сверху свободно — поднимаемся
func _try_step_up(horizontal: Vector3) -> void:
	if not is_on_floor() or horizontal.length_squared() < 0.01:
		return
	var step := Vector3.UP * STEP_HEIGHT
	var forward: Vector3 = horizontal.normalized() * 0.3
	var start: Transform3D = global_transform
	if test_move(start, step):
		return  # над головой препятствие
	if test_move(start.translated(step), forward):
		return  # высокая стена — не ступенька
	global_position += step + forward
	apply_floor_snap()


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

func _on_player_fired(weapon: WeaponData) -> void:
	if state == State.DEAD or _player == null:
		return
	var hearing: float = data.hearing_radius * (weapon.hearing_multiplier if weapon != null else 1.0)
	if global_position.distance_to(_player.global_position) <= hearing:
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
	_set_far(false)  # анимация смерти — обычным темпом (_physics_process у мёртвых не идёт)
	_set_flash(false)
	_speed_multiplier = _base_speed_multiplier
	# Хитбокс головы у мёртвого не двигается — каска слетает, нагрудник падает вперёд
	if _helmet != null:
		_knock_off_helmet(global_position - global_basis.z)
	if _armor_plate != null:
		_armor_plate.create_tween().tween_property(_armor_plate, "rotation:x", -1.3, 0.5) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
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
	if killed_by_headshot and not net_puppet:
		_headshot_death()

	if _has_anim(anim_death):
		_play(anim_death, true)
	elif visual != null:
		var fall := create_tween()
		fall.tween_property(visual, "rotation:x", deg_to_rad(90.0), 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Твин принадлежит зомби: умирает вместе с ним при смене сцены и стоит на паузе
	var corpse := create_tween()
	corpse.tween_interval(CORPSE_TIME)
	if visual != null:
		corpse.tween_property(visual, "position:y", visual.position.y - 1.2, SINK_TIME)
	corpse.tween_callback(queue_free)


# ---------- Хедшот ----------

const NECK_BONE: StringName = &"Neck"
const NECK_BLOOD_TIME: float = 1.3
const HEADSHOT_PUSH: float = 0.55
static var _blood_mesh: SphereMesh


## Голова лопается (кость Head сжимается), из шеи бьёт кровь, тело откидывает назад
func _headshot_death() -> void:
	var head_position: Vector3 = global_position + Vector3.UP * 1.7
	if _skeleton != null and _head_bone >= 0:
		head_position = global_transform * (_skeleton_to_body * _skeleton.get_bone_global_pose(_head_bone).origin)
		var pop := HeadPopModifier.new()
		pop.name = "HeadPop"
		pop.bone = _head_bone
		_skeleton.add_child(pop)
		_spawn_neck_blood(head_position)
	var impacts := get_node_or_null(^"/root/Impacts") as ImpactPool
	if impacts != null:
		for direction: Vector3 in [Vector3.UP, Vector3(0.6, 0.8, 0.0), Vector3(-0.6, 0.8, 0.0)]:
			impacts.spawn(head_position, direction, true)
	Sfx.play_3d(Sfx.pick(Sfx.sounds.flesh_hits), head_position, 4.0, 0.65)
	# Откидывает от стрелявшего (только модель — тело уже без коллизий)
	if visual != null and _player != null and is_instance_valid(_player):
		var away: Vector3 = global_position - _player.global_position
		away.y = 0.0
		if away.length_squared() > 0.01:
			var local_away: Vector3 = (global_basis.inverse() * away.normalized()) * HEADSHOT_PUSH
			var push := create_tween()
			push.tween_property(visual, "position", visual.position + local_away, 0.25) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Фонтан крови из шеи: следует за костью Neck, пока тело падает
func _spawn_neck_blood(fallback_position: Vector3) -> void:
	var parent: Node3D = self
	var neck: int = _skeleton.find_bone(NECK_BONE)
	if neck >= 0:
		var attachment := BoneAttachment3D.new()
		attachment.bone_name = NECK_BONE
		_skeleton.add_child(attachment)
		parent = attachment
	if _blood_mesh == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.45, 0.0, 0.0)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_blood_mesh = SphereMesh.new()
		_blood_mesh.radius = 0.035
		_blood_mesh.height = 0.07
		_blood_mesh.radial_segments = 6
		_blood_mesh.rings = 3
		_blood_mesh.material = material
	var blood := CPUParticles3D.new()
	blood.mesh = _blood_mesh
	blood.amount = 36
	blood.lifetime = 0.7
	blood.local_coords = false
	blood.direction = Vector3.UP
	blood.spread = 28.0
	blood.initial_velocity_min = 2.5
	blood.initial_velocity_max = 4.5
	blood.gravity = Vector3(0.0, -9.8, 0.0)
	blood.scale_amount_min = 0.6
	blood.scale_amount_max = 1.3
	parent.add_child(blood)
	if parent == self:
		blood.global_position = fallback_position
	else:
		# Кость Neck в масштабе модели — частицы мира не сжимаются (local_coords = false)
		blood.position = Vector3.UP * 0.08
	blood.emitting = true
	var stop := create_tween()
	stop.tween_interval(NECK_BLOOD_TIME)
	stop.tween_callback(func() -> void:
		if is_instance_valid(blood):
			blood.emitting = false)


# ---------- Мультиплеер ----------

## Состояние от хоста (копия на клиенте)
func net_apply_state(position_value: Vector3, yaw: float, state_value: int, hp: float) -> void:
	_net_position = position_value
	_net_yaw = yaw
	_net_state = state_value
	if not _net_has_state:
		_net_has_state = true
		global_position = position_value
		rotation.y = yaw
	if health != null and not health.is_dead:
		health.current = clampf(hp, 0.0, health.max_health)


## Хост сообщил о смерти
func net_kill() -> void:
	if state == State.DEAD or health == null:
		return
	health.take_damage(health.current + 1.0, global_position + Vector3.UP, false)


func _puppet_process(delta: float) -> void:
	_update_head_hitbox()
	_update_voice(delta)
	if not _net_has_state:
		return
	var before: Vector3 = global_position
	var weight: float = clampf(10.0 * delta, 0.0, 1.0)
	if global_position.distance_squared_to(_net_position) > 36.0:
		global_position = _net_position
	else:
		global_position = global_position.lerp(_net_position, weight)
	rotation.y = lerp_angle(rotation.y, _net_yaw, weight)
	var moved: float = Vector2(global_position.x - before.x, global_position.z - before.z).length()
	_net_speed = lerpf(_net_speed, moved / maxf(delta, 0.001), 0.2)
	var changed: bool = _net_state != _net_last_state
	_net_last_state = _net_state
	match _net_state:
		State.RANGED when data.behavior == ZombieData.Behavior.GUNNER:
			if changed:
				_play(data.anim_shoot, true)
		State.ATTACK, State.SLAM, State.RANGED, State.FUSE:
			if changed:
				_play(anim_attack, true)
		State.STAGGER:
			if changed:
				_play(anim_hit, true)
		_:
			_play_locomotion(_net_speed)


## Ближайший живой игрок (свой или чужой) — новая цель
func _pick_nearest_target() -> void:
	var best: Player = null
	var best_distance: float = INF
	for group: StringName in [&"player", &"remote_player"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var candidate := node as Player
			if candidate == null or candidate.health == null or candidate.health.is_dead \
					or not candidate.is_inside_tree():
				continue
			var distance: float = global_position.distance_squared_to(candidate.global_position)
			if distance < best_distance:
				best_distance = distance
				best = candidate
	if best != null and best != _player:
		_player = best
		_player_health = best.health


## Убрать зомби без смерти и награды (спавнер открытого мира)
func despawn() -> void:
	if state == State.DEAD or not is_inside_tree():
		return
	_release_token()
	state = State.DEAD
	despawned.emit(self)
	queue_free()


## Удар машиной: урон по скорости, отбрасывание; погибший отлетает
## Капкан: держит на месте seconds секунд (босса — вдвое меньше); бить рядом стоящего может
func hold(seconds: float) -> void:
	if state == State.DEAD or net_puppet or seconds <= 0.0:
		return
	var duration: float = seconds * (0.5 if data != null and data.is_boss else 1.0)
	_hold_left = maxf(_hold_left, duration)
	_play(anim_hit, true)


func is_held() -> bool:
	return _hold_left > 0.0


func hit_by_vehicle(damage: float, push: Vector3) -> void:
	apply_blast(damage, push)


## Урон с отбрасыванием (машина, взрыв); погибший отлетает по дуге
## Обезвредить взрывника: смерть без взрыва (воскрешение игрока рядом)
func defuse() -> void:
	_exploded = true


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
	if data.human:
		return  # люди не стонут как зомби
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
		_setup_held_weapon()
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
		# Модели без головы (Zombie_Ribcage — одни ноги) — это нормально: хитбоксы по model_scale
		if not _warned_types.has(data.display_name):
			_warned_types[data.display_name] = true
			print_verbose("Zombie: у типа %s нет кости %s, хитбоксы по model_scale" % [
				data.display_name, HEAD_BONE])
		_skeleton = null
		return fallback
	_skeleton_to_body = _transform_to_body(_skeleton)
	var head: Vector3 = _skeleton_to_body * _skeleton.get_bone_global_rest(_head_bone).origin
	if head.y <= 0.1:
		return fallback
	return clampf(head.y / REFERENCE_HEAD_HEIGHT, 0.5, 4.0)


## Хитбокс головы в текущей позе кости Head (каждый физический кадр, без аллокаций)
## Дальние зомби дешевле: анимация обновляется вручную шагами FAR_ANIM_STEP (на телефоне — заметный выигрыш
## при толпе), голова не отслеживается (в даль попасть точно в голову всё равно трудно)
func _update_lod(delta: float) -> void:
	_lod_timer -= delta
	if _lod_timer <= 0.0:
		_lod_timer = LOD_CHECK_INTERVAL
		var far: bool = _player != null and is_instance_valid(_player) \
			and global_position.distance_squared_to(_player.global_position) > FAR_DISTANCE * FAR_DISTANCE
		if far != _far:
			_set_far(far)
	if _far and animation_player != null:
		_anim_accum += delta
		if _anim_accum >= FAR_ANIM_STEP:
			animation_player.advance(_anim_accum)
			_anim_accum = 0.0


func _set_far(far: bool) -> void:
	_far = far
	_anim_accum = 0.0
	if animation_player != null:
		animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL \
			if far else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE


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
	_set_far(false)  # новый AnimationPlayer — в обычном режиме
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
