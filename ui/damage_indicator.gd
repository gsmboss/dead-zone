class_name DamageIndicator
extends Control
## Откуда пришёл урон: красное свечение края экрана с той стороны, дуга, стрелка-шеврон
## и значок (когти — укус/удар зомби, прицел — выстрел, звезда — взрыв, огонь, капля — кислота).
## По сети над стрелкой — имя стрелявшего; стрелка следит за ним, пока видна.
## Создаётся кодом (DamageOverlay), сам находит игрока. Без аллокаций в кадре.

const MAX_INDICATORS: int = 4
const SHOW_TIME: float = 1.6
const ARC_SPAN: float = deg_to_rad(46.0)
const ARC_WIDTH: float = 14.0
## Радиус дуги — доля от меньшей стороны экрана
const RADIUS_FACTOR: float = 0.36
## Свечение края: радиусы и прозрачность слоёв (мягкий градиент без текстур)
const GLOW_RADII: PackedFloat32Array = [300.0, 230.0, 165.0, 105.0]
const GLOW_ALPHA: PackedFloat32Array = [0.07, 0.09, 0.11, 0.14]
const KIND_COLORS: Array[Color] = [
	Color(0.95, 0.08, 0.05),  # MELEE — укус, удар
	Color(1.0, 0.25, 0.12),   # BULLET — выстрел игрока
	Color(1.0, 0.55, 0.1),    # EXPLOSION
	Color(1.0, 0.45, 0.05),   # FIRE
	Color(0.55, 0.95, 0.15),  # ACID
]

var _player: Player
# Параллельные массивы фиксированного размера (без аллокаций в кадре)
var _sources: Array[Vector3] = []
var _targets: Array[Node3D] = []
var _times: Array[float] = []
var _kinds: PackedInt32Array = []
var _names: PackedStringArray = []
var _font: Font


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_sources.resize(MAX_INDICATORS)
	_targets.resize(MAX_INDICATORS)
	_times.resize(MAX_INDICATORS)
	_times.fill(0.0)
	_kinds.resize(MAX_INDICATORS)
	_names.resize(MAX_INDICATORS)
	_font = ThemeDB.fallback_font
	set_process(false)
	_connect_player.call_deferred()


func _connect_player() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null or _player.health == null:
		push_warning("DamageIndicator: игрок или его Health не найдены")
		return
	_player.health.damaged.connect(_on_damaged)
	_player.health.died.connect(_clear)


func _on_damaged(_amount: float, hit_position: Vector3, _is_headshot: bool) -> void:
	if _player == null or not Settings.damage_direction or hit_position == Vector3.ZERO:
		return
	var health: Health = _player.health
	var source: Node3D = health.last_source if is_instance_valid(health.last_source) else null
	# Тот же источник — обновляем его слот, иначе занимаем самый старый
	var slot: int = -1
	if source != null:
		for i in MAX_INDICATORS:
			if _times[i] > 0.0 and _targets[i] == source:
				slot = i
				break
	if slot < 0:
		slot = 0
		for i in MAX_INDICATORS:
			if _times[i] < _times[slot]:
				slot = i
	_sources[slot] = hit_position
	_targets[slot] = source
	_times[slot] = SHOW_TIME
	_kinds[slot] = clampi(health.last_kind, 0, KIND_COLORS.size() - 1)
	_names[slot] = UIKit.t(health.last_source_name)
	set_process(true)


func _clear() -> void:
	_times.fill(0.0)
	queue_redraw()


func _process(delta: float) -> void:
	var active: bool = false
	for i in MAX_INDICATORS:
		if _times[i] > 0.0:
			_times[i] = maxf(_times[i] - delta, 0.0)
			if _targets[i] != null:
				if is_instance_valid(_targets[i]) and _targets[i].is_inside_tree():
					_sources[i] = _targets[i].global_position  # стрелка следит за атакующим
				else:
					_targets[i] = null
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
		var direction := Vector2(cos(screen_angle), sin(screen_angle))
		var fade: float = clampf(_times[i] / SHOW_TIME, 0.0, 1.0)
		# Быстрая вспышка в начале, потом плавное затухание
		var pulse: float = 1.0 + 0.35 * clampf((_times[i] - SHOW_TIME + 0.25) / 0.25, 0.0, 1.0)
		var color: Color = KIND_COLORS[_kinds[i]]

		_draw_edge_glow(center, direction, color, fade * pulse)

		var arc_color := Color(color, 0.85 * fade)
		draw_arc(center, radius, screen_angle - ARC_SPAN * 0.5, screen_angle + ARC_SPAN * 0.5,
			24, arc_color, ARC_WIDTH * pulse, true)
		# Шеврон — остриё наружу, к атакующему
		var tip: Vector2 = center + direction * (radius + 34.0)
		var side := Vector2(-direction.y, direction.x)
		var back: Vector2 = tip - direction * 26.0
		draw_colored_polygon(PackedVector2Array([tip, back + side * 20.0, back - side * 20.0]),
			Color(color.lightened(0.2), 0.95 * fade))
		var icon_center: Vector2 = center + direction * (radius - 40.0)
		_draw_kind_icon(_kinds[i], icon_center, Color(1.0, 1.0, 1.0, 0.9 * fade), Color(color, 0.8 * fade))
		if not _names[i].is_empty():
			var text_size: Vector2 = _font.get_string_size(_names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
			var text_pos: Vector2 = center + direction * (radius + 74.0) - Vector2(text_size.x * 0.5, -8.0)
			text_pos.x = clampf(text_pos.x, 8.0, size.x - text_size.x - 8.0)
			text_pos.y = clampf(text_pos.y, 30.0, size.y - 10.0)
			draw_string_outline(_font, text_pos, _names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6,
				Color(0.0, 0.0, 0.0, 0.8 * fade))
			draw_string(_font, text_pos, _names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 24,
				Color(1.0, 0.85, 0.8, fade))


## Красное свечение у края экрана в стороне атаки («обводка» той стороны)
func _draw_edge_glow(center: Vector2, direction: Vector2, color: Color, strength: float) -> void:
	# Точка, где луч из центра выходит за край экрана
	var tx: float = INF if is_zero_approx(direction.x) else absf(center.x / direction.x)
	var ty: float = INF if is_zero_approx(direction.y) else absf(center.y / direction.y)
	var edge: Vector2 = center + direction * minf(tx, ty)
	var intensity: float = clampf(strength, 0.0, 1.4) * Settings.damage_flash
	for layer in GLOW_RADII.size():
		draw_circle(edge, GLOW_RADII[layer], Color(color, GLOW_ALPHA[layer] * intensity * 1.6))


## Значок типа урона
func _draw_kind_icon(kind: int, at: Vector2, color: Color, back: Color) -> void:
	draw_circle(at, 22.0, Color(0.0, 0.0, 0.0, back.a * 0.6))
	draw_arc(at, 22.0, 0.0, TAU, 24, back, 3.0, true)
	match kind:
		Health.Kind.BULLET:
			# Прицел
			draw_arc(at, 11.0, 0.0, TAU, 20, color, 3.0, true)
			draw_line(at + Vector2(-17.0, 0.0), at + Vector2(-6.0, 0.0), color, 3.0)
			draw_line(at + Vector2(6.0, 0.0), at + Vector2(17.0, 0.0), color, 3.0)
			draw_line(at + Vector2(0.0, -17.0), at + Vector2(0.0, -6.0), color, 3.0)
			draw_line(at + Vector2(0.0, 6.0), at + Vector2(0.0, 17.0), color, 3.0)
		Health.Kind.EXPLOSION, Health.Kind.FIRE:
			# Вспышка-звезда
			for ray in 8:
				var a: float = TAU * ray / 8.0
				var length: float = 15.0 if ray % 2 == 0 else 9.0
				draw_line(at, at + Vector2(cos(a), sin(a)) * length, color, 3.0)
		Health.Kind.ACID:
			# Капля
			draw_circle(at + Vector2(0.0, 4.0), 8.0, color)
			draw_colored_polygon(PackedVector2Array([at + Vector2(0.0, -14.0), at + Vector2(7.0, 1.0),
				at + Vector2(-7.0, 1.0)]), color)
		_:
			# Когти: три царапины
			for claw in 3:
				var offset: float = (claw - 1) * 8.0
				draw_line(at + Vector2(offset - 6.0, -13.0), at + Vector2(offset + 4.0, 13.0), color, 3.5)
