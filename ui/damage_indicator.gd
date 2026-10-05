class_name DamageIndicator
extends Control
## Красные дуги по краю экрана со стороны, откуда пришёл урон.
## Создаётся кодом (DamageOverlay), сам находит игрока.

const MAX_INDICATORS: int = 4
const SHOW_TIME: float = 1.2
const ARC_SPAN: float = deg_to_rad(42.0)
const ARC_WIDTH: float = 16.0
## Радиус дуги — доля от меньшей стороны экрана
const RADIUS_FACTOR: float = 0.42
const COLOR: Color = Color(1.0, 0.1, 0.05, 0.85)

var _player: Player
# Параллельные массивы без аллокаций в кадре: мировая точка и остаток времени
var _sources: Array[Vector3] = []
var _times: Array[float] = []


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_sources.resize(MAX_INDICATORS)
	_times.resize(MAX_INDICATORS)
	_times.fill(0.0)
	set_process(false)
	_connect_player.call_deferred()


func _connect_player() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null or _player.health == null:
		push_warning("DamageIndicator: игрок или его Health не найдены")
		return
	_player.health.damaged.connect(_on_damaged)


func _on_damaged(_amount: float, hit_position: Vector3, _is_headshot: bool) -> void:
	if _player == null or hit_position == Vector3.ZERO:
		return
	# Занимаем слот с наименьшим временем
	var slot: int = 0
	for i in MAX_INDICATORS:
		if _times[i] < _times[slot]:
			slot = i
	_sources[slot] = hit_position
	_times[slot] = SHOW_TIME
	set_process(true)


func _process(delta: float) -> void:
	var active: bool = false
	for i in MAX_INDICATORS:
		if _times[i] > 0.0:
			_times[i] = maxf(_times[i] - delta, 0.0)
			active = active or _times[i] > 0.0
	queue_redraw()
	if not active:
		set_process(false)


func _draw() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * RADIUS_FACTOR
	var inverse_basis: Basis = _player.global_basis.inverse()
	for i in MAX_INDICATORS:
		if _times[i] <= 0.0:
			continue
		# Направление на источник в осях игрока: -Z вперёд, +X вправо
		var local: Vector3 = inverse_basis * (_sources[i] - _player.global_position)
		var angle: float = atan2(local.x, -local.z)
		# На экране «вперёд» — вверх (угол -90°), углы растут по часовой стрелке
		var screen_angle: float = -PI * 0.5 + angle
		var color: Color = COLOR
		color.a *= clampf(_times[i] / SHOW_TIME, 0.0, 1.0)
		draw_arc(center, radius, screen_angle - ARC_SPAN * 0.5, screen_angle + ARC_SPAN * 0.5,
			24, color, ARC_WIDTH, false)
