class_name CampaignMap
extends Control
## Карта области для сюжета (рисуется кодом): тёмная карта с сеткой, дорогами и рекой,
## путь между главами (пройденный — оранжевый, дальше — пунктир), точки глав:
## пройдена — зелёная с галочкой, текущая — пульсирует, закрыта — серая с замком.
## Тап по точке — сигнал chapter_selected.

signal chapter_selected(index: int)

const NODE_RADIUS: float = 26.0
const BG: Color = Color(0.09, 0.085, 0.075, 0.95)
const GRID: Color = Color(1.0, 1.0, 1.0, 0.04)
const ROAD: Color = Color(0.32, 0.3, 0.27, 0.6)
const RIVER: Color = Color(0.2, 0.32, 0.42, 0.55)
const DONE: Color = Color(0.4, 0.85, 0.45)
const CURRENT: Color = Color(1.0, 0.6, 0.15)
const LOCKED: Color = Color(0.4, 0.4, 0.42)
const PATH_DONE: Color = Color(0.9, 0.5, 0.15, 0.9)
const PATH_TODO: Color = Color(0.6, 0.6, 0.6, 0.35)
const MARGIN: float = 46.0
## Дороги и река в долях карты (декор)
const ROADS: Array = [
	[Vector2(0.0, 0.82), Vector2(0.3, 0.7), Vector2(0.6, 0.72), Vector2(1.0, 0.6)],
	[Vector2(0.35, 0.0), Vector2(0.36, 0.5), Vector2(0.5, 1.0)],
	[Vector2(0.6, 0.72), Vector2(0.72, 0.4), Vector2(0.9, 0.15)],
]
const RIVER_POINTS: Array[Vector2] = [Vector2(0.0, 0.42), Vector2(0.22, 0.38), Vector2(0.4, 0.46),
	Vector2(0.58, 0.32), Vector2(0.8, 0.36), Vector2(1.0, 0.28)]

var selected: int = 0

var _chapters: Array[ChapterData] = []
var _time: float = 0.0
var _points := PackedVector2Array()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	clip_contents = true
	_chapters = GameState.campaign.chapters
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()  # пульс текущей главы


## Центр точки главы в пикселях карты
func get_point(index: int) -> Vector2:
	var chapter: ChapterData = _chapters[index]
	var area := Vector2(size.x - MARGIN * 2.0, size.y - MARGIN * 2.0)
	return Vector2(MARGIN, MARGIN) + chapter.map_position * area


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	# Сетка
	var step: float = 48.0
	var x: float = 0.0
	while x < size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), GRID, 1.0)
		x += step
	var y: float = 0.0
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), GRID, 1.0)
		y += step
	# Река и дороги
	_points.resize(RIVER_POINTS.size())
	for i in RIVER_POINTS.size():
		_points[i] = RIVER_POINTS[i] * size
	draw_polyline(_points, RIVER, 10.0)
	for road: Array in ROADS:
		_points.resize(road.size())
		for i in road.size():
			_points[i] = (road[i] as Vector2) * size
		draw_polyline(_points, ROAD, 5.0)
	# Рамка
	draw_rect(Rect2(Vector2(4.0, 4.0), size - Vector2(8.0, 8.0)), Color(0.85, 0.42, 0.12, 0.6), false, 3.0)

	# Путь между главами
	for i in range(1, _chapters.size()):
		var from: Vector2 = get_point(i - 1)
		var to: Vector2 = get_point(i)
		if GameState.is_chapter_done(_chapters[i - 1].id) and GameState.is_chapter_unlocked(i):
			draw_line(from, to, PATH_DONE, 5.0)
		else:
			draw_dashed_line(from, to, PATH_TODO, 3.0, 12.0)

	var font: Font = ThemeDB.fallback_font
	for i in _chapters.size():
		_draw_node(i, font)


func _draw_node(index: int, font: Font) -> void:
	var chapter: ChapterData = _chapters[index]
	var center: Vector2 = get_point(index)
	var done: bool = GameState.is_chapter_done(chapter.id)
	var unlocked: bool = GameState.is_chapter_unlocked(index)
	var color: Color = DONE if done else (CURRENT if unlocked else LOCKED)
	var radius: float = NODE_RADIUS
	if unlocked and not done:
		# Текущая глава пульсирует
		var pulse: float = 0.5 + 0.5 * sin(_time * 4.0)
		draw_circle(center, radius + 8.0 + pulse * 10.0, Color(color, 0.25 * (1.0 - pulse)))
	if index == selected:
		draw_arc(center, radius + 7.0, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.9), 3.0, false)
	draw_circle(center + Vector2(0.0, 4.0), radius, Color(0.0, 0.0, 0.0, 0.5))
	draw_circle(center, radius, color.darkened(0.35))
	draw_circle(center - Vector2(0.0, 2.0), radius * 0.82, color)
	# Значок: галочка, номер или замок
	if done:
		draw_polyline(PackedVector2Array([center + Vector2(-10.0, 0.0), center + Vector2(-3.0, 8.0),
			center + Vector2(11.0, -8.0)]), Color.WHITE, 4.0)
	elif unlocked:
		var number: String = str(index + 1)
		var text_size: Vector2 = font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
		draw_string(font, center + Vector2(-text_size.x * 0.5, 9.0), number, HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
			Color.WHITE)
	else:
		draw_rect(Rect2(center + Vector2(-8.0, -1.0), Vector2(16.0, 12.0)), Color(0.9, 0.9, 0.9))
		draw_arc(center + Vector2(0.0, -2.0), 6.0, PI, TAU, 10, Color(0.9, 0.9, 0.9), 3.0, false)
	# Подпись
	var label: String = UIKit.t(chapter.title)
	var label_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	var label_pos := Vector2(center.x - label_size.x * 0.5, center.y + radius + 22.0)
	label_pos.x = clampf(label_pos.x, 6.0, size.x - label_size.x - 6.0)
	draw_string_outline(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0.0, 0.0, 0.0, 0.8))
	draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
		Color.WHITE if unlocked else Color(0.7, 0.7, 0.7))


func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	for i in _chapters.size():
		if mouse.position.distance_to(get_point(i)) <= NODE_RADIUS + 14.0:
			selected = i
			Sfx.click()
			chapter_selected.emit(i)
			accept_event()
			return
