class_name StarRating
extends Control
## Звёзды рейтинга миссии (рисуются, не текст). play() — звёзды выпрыгивают по очереди.

const POINTS: int = 5
const INNER_RATIO: float = 0.45
const POP_TIME: float = 0.35
const POP_DELAY: float = 0.3
const FILLED_COLOR: Color = Color(1.0, 0.8, 0.2)
const EMPTY_COLOR: Color = Color(1.0, 1.0, 1.0, 0.25)
const OUTLINE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.7)

@export var max_stars: int = 3
@export var star_radius: float = 26.0
@export var spacing: float = 10.0

var _filled: int = 0
# Масштаб каждой звезды (для анимации появления)
var _scales: PackedFloat32Array = PackedFloat32Array()
var _polygon: PackedVector2Array = PackedVector2Array()
var _outline: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_build_polygon()
	_scales.resize(max_stars)
	_scales.fill(1.0)
	custom_minimum_size = Vector2(
		max_stars * star_radius * 2.0 + (max_stars - 1) * spacing, star_radius * 2.0)


## Показать filled звёзд сразу
func set_stars(filled: int) -> void:
	_filled = clampi(filled, 0, max_stars)
	_scales.fill(1.0)
	queue_redraw()


## Звёзды появляются по одной с отскоком и звуком
func play(filled: int) -> void:
	_filled = clampi(filled, 0, max_stars)
	_scales.fill(0.0)
	queue_redraw()
	var tween := create_tween()
	for i in max_stars:
		tween.tween_interval(POP_DELAY if i > 0 else 0.15)
		tween.tween_callback(_on_star_pop.bind(i))
		tween.tween_method(_set_star_scale.bind(i), 0.0, 1.0, POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_star_pop(index: int) -> void:
	if index < _filled:
		Sfx.play_2d(Sfx.sounds.ui_confirm, -6.0, 1.0 + index * 0.12, 0.0)


func _set_star_scale(value: float, index: int) -> void:
	if index >= 0 and index < _scales.size():
		_scales[index] = value
		queue_redraw()


func _draw() -> void:
	var step: float = star_radius * 2.0 + spacing
	var origin_x: float = (size.x - (max_stars * step - spacing)) * 0.5 + star_radius
	for i in max_stars:
		var star_scale: float = _scales[i] if i < _scales.size() else 1.0
		if star_scale <= 0.01:
			continue
		var center := Vector2(origin_x + i * step, size.y * 0.5)
		draw_set_transform(center, 0.0, Vector2.ONE * star_scale)
		draw_colored_polygon(_polygon, FILLED_COLOR if i < _filled else EMPTY_COLOR)
		draw_polyline(_outline, OUTLINE_COLOR, 2.0, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _build_polygon() -> void:
	_polygon.clear()
	for i in POINTS * 2:
		var radius: float = star_radius if i % 2 == 0 else star_radius * INNER_RATIO
		var angle: float = -PI * 0.5 + i * PI / POINTS
		_polygon.append(Vector2(cos(angle), sin(angle)) * radius)
	_outline = _polygon.duplicate()
	_outline.append(_polygon[0])
