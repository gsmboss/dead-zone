class_name ScopeOverlay
extends Control
## Оптика снайперской винтовки на весь экран: чёрное поле вокруг круглого окуляра, затемнение
## по краю линзы, тонкая сетка с толстыми «столбами», дальномерные точки и красная точка в центре.
## Показывается, когда WeaponManager.is_scoped(); создаёт Crosshair. Рисуется только когда видна.

const FADE_SPEED: float = 8.0
## Радиус окуляра — доля от меньшей стороны экрана
const LENS_FACTOR: float = 0.46
const BLACK: Color = Color(0.0, 0.0, 0.0, 1.0)
const RETICLE: Color = Color(0.05, 0.05, 0.05, 0.95)
const DOT: Color = Color(1.0, 0.15, 0.1)

var weapon_manager: WeaponManager

var _alpha: float = 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	modulate.a = 0.0
	visible = false


func _process(delta: float) -> void:
	var scoped: bool = weapon_manager != null and is_instance_valid(weapon_manager) and weapon_manager.is_scoped()
	var target: float = 1.0 if scoped else 0.0
	if is_equal_approx(_alpha, target) and visible == scoped:
		return
	_alpha = move_toward(_alpha, target, FADE_SPEED * delta)
	modulate.a = _alpha
	visible = _alpha > 0.0
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * LENS_FACTOR
	var far: float = size.length()
	# Чёрное поле: толстое кольцо от края линзы до углов экрана
	draw_arc(center, radius + far * 0.5, 0.0, TAU, 72, BLACK, far, false)
	# Затемнение по краю линзы (виньетка)
	for i in 4:
		var width: float = 10.0 + i * 12.0
		draw_arc(center, radius - width * 0.5, 0.0, TAU, 64, Color(0.0, 0.0, 0.0, 0.22 - i * 0.04), width, true)
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.15, 0.15, 0.15), 4.0, true)
	# Сетка: тонкие линии через центр и толстые «столбы» у края
	var gap: float = radius * 0.08
	draw_line(center - Vector2(radius, 0.0), center + Vector2(radius, 0.0), RETICLE, 1.5)
	draw_line(center - Vector2(0.0, radius), center + Vector2(0.0, radius), RETICLE, 1.5)
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]:
		draw_line(center + direction * radius * 0.45, center + direction * radius, RETICLE, 7.0)
	# Дальномерные точки
	for i in range(1, 5):
		var step: float = gap * 1.6 * i
		for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_circle(center + direction * step, 2.2, RETICLE)
	draw_circle(center, 3.2, DOT)
