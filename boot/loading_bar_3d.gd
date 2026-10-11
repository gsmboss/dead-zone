class_name LoadingBar3D
extends Control
## Объёмная полоса загрузки: рамка с тенью, углублённый жёлоб, заливка-градиент
## с бликом, бегущие полосы «опасно» и светящийся край. Рисуется кодом, стили создаются один раз.

const HEIGHT: float = 34.0
const STRIPE_SPEED: float = 60.0
const STRIPE_STEP: float = 26.0
const FILL_LEFT: Color = Color(0.85, 0.3, 0.08)
const FILL_RIGHT: Color = Color(1.0, 0.72, 0.18)

## Доля 0..1
var value: float = 0.0:
	set(new_value):
		value = clampf(new_value, 0.0, 1.0)
		queue_redraw()

var _time: float = 0.0
var _frame_style: StyleBoxFlat
var _well_style: StyleBoxFlat
var _stripe_points := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0.0, HEIGHT + 12.0)
	_frame_style = StyleBoxFlat.new()
	_frame_style.bg_color = Color(0.06, 0.06, 0.07, 0.85)
	_frame_style.set_corner_radius_all(14)
	_frame_style.border_width_bottom = 5
	_frame_style.border_color = Color(0.0, 0.0, 0.0, 0.7)
	_frame_style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	_frame_style.shadow_size = 10
	_frame_style.shadow_offset = Vector2(0.0, 4.0)
	_well_style = StyleBoxFlat.new()
	_well_style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	_well_style.set_corner_radius_all(10)
	_well_style.border_width_top = 4
	_well_style.border_color = Color(0.0, 0.0, 0.0, 0.6)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var frame := Rect2(Vector2.ZERO, Vector2(size.x, HEIGHT + 10.0))
	draw_style_box(_frame_style, frame)
	var well: Rect2 = frame.grow(-6.0)
	draw_style_box(_well_style, well)
	if value <= 0.005:
		return
	var fill := Rect2(well.position, Vector2(maxf(well.size.x * value, 12.0), well.size.y))
	# Градиент полосками (дёшево, без текстуры)
	var steps: int = 24
	var step_width: float = fill.size.x / steps
	for i in steps:
		var t: float = float(i) / float(steps - 1)
		draw_rect(Rect2(fill.position + Vector2(step_width * i, 0.0), Vector2(step_width + 1.0, fill.size.y)),
			FILL_LEFT.lerp(FILL_RIGHT, t * value))
	# Бегущие косые полосы «опасно»
	var offset: float = fmod(_time * STRIPE_SPEED, STRIPE_STEP)
	var x: float = fill.position.x - STRIPE_STEP + offset
	while x < fill.end.x:
		var left: float = maxf(x, fill.position.x)
		var right: float = minf(x + STRIPE_STEP * 0.45, fill.end.x)
		if right > left:
			_stripe_points[0] = Vector2(left, fill.end.y)
			_stripe_points[1] = Vector2(right, fill.end.y)
			_stripe_points[2] = Vector2(minf(right + fill.size.y * 0.5, fill.end.x), fill.position.y)
			_stripe_points[3] = Vector2(minf(left + fill.size.y * 0.5, fill.end.x), fill.position.y)
			draw_colored_polygon(_stripe_points, Color(0.0, 0.0, 0.0, 0.16))
		x += STRIPE_STEP
	# Блик сверху и тень снизу — объём
	draw_rect(Rect2(fill.position + Vector2(4.0, 3.0), Vector2(fill.size.x - 8.0, fill.size.y * 0.3)),
		Color(1.0, 1.0, 1.0, 0.3))
	draw_rect(Rect2(fill.position + Vector2(2.0, fill.size.y * 0.72), Vector2(fill.size.x - 4.0, fill.size.y * 0.24)),
		Color(0.0, 0.0, 0.0, 0.2))
	# Светящийся край заливки
	var glow: float = 0.6 + 0.4 * sin(_time * 6.0)
	draw_circle(Vector2(fill.end.x - 2.0, fill.get_center().y), fill.size.y * 0.75, Color(1.0, 0.8, 0.4, 0.25 * glow))
	draw_rect(Rect2(Vector2(fill.end.x - 3.0, fill.position.y), Vector2(3.0, fill.size.y)), Color(1.0, 0.95, 0.8, glow))
