extends Label
## Полоска здоровья игрока в 3D-стиле: объёмная рамка с тенью, градиентная заливка
## (зелёный → жёлтый → красный), блик, «след» урона, значок аптечки, мигание при низком
## здоровье и вспышка при лечении. Рисуется кодом; нода остаётся Label для совместимости
## со сценами (текст не используется).

const BAR_POSITION: Vector2 = Vector2(24.0, 18.0)
const BAR_SIZE: Vector2 = Vector2(340.0, 44.0)
const ICON_RADIUS: float = 24.0
## Заливка догоняет значение за ~0.1 с, след урона ждёт и сползает медленно
const FILL_SPEED: float = 12.0
const TRAIL_DELAY: float = 0.45
const TRAIL_SPEED: float = 0.6
const HEAL_FLASH_TIME: float = 0.5
const LOW_PULSE_SPEED: float = 6.0
const FONT_SIZE: int = 22
## Полоска выносливости под здоровьем
const STAMINA_HEIGHT: float = 9.0
const STAMINA_COLOR: Color = Color(0.35, 0.75, 1.0)
const STAMINA_LOW_COLOR: Color = Color(1.0, 0.55, 0.2)

const FULL_COLOR: Color = Color(0.25, 0.85, 0.35)
const MID_COLOR: Color = Color(0.95, 0.8, 0.2)
const LOW_COLOR: Color = Color(0.9, 0.18, 0.12)
const TRAIL_COLOR: Color = Color(1.0, 0.95, 0.85, 0.85)
const FRAME_COLOR: Color = Color(0.08, 0.09, 0.1, 0.75)

@export_range(0.0, 1.0, 0.05) var low_threshold: float = 0.3

var _current: float = 100.0
var _max: float = 100.0
var _shown: float = 1.0   # отображаемая доля (плавно)
var _trail: float = 1.0   # след урона
var _trail_wait: float = 0.0
var _heal_flash: float = 0.0
var _time: float = 0.0
var _text: String = ""
var _stamina: float = 1.0

# Стили создаются один раз (без аллокаций в кадре)
var _frame_style: StyleBoxFlat
var _well_style: StyleBoxFlat
var _fill_style: StyleBoxFlat
var _trail_style: StyleBoxFlat


func _ready() -> void:
	text = ""
	mouse_filter = MOUSE_FILTER_IGNORE
	# Своё место в левом верхнем углу (якоря в сцене не используются)
	set_anchors_and_offsets_preset(PRESET_TOP_LEFT)
	position = BAR_POSITION
	size = Vector2(BAR_SIZE.x + ICON_RADIUS, BAR_SIZE.y + STAMINA_HEIGHT + 14.0)
	_build_styles()
	set_process(false)
	_connect_player.call_deferred()


func _connect_player() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or player.health == null:
		push_warning("HealthDisplay: игрок или его Health не найдены")
		return
	player.health.health_changed.connect(_on_health_changed)
	player.stamina_changed.connect(_on_stamina_changed)
	_current = player.health.current
	_max = player.health.max_health
	_shown = _ratio()
	_trail = _shown
	_update_text()
	queue_redraw()


func _on_health_changed(current: float, max_value: float) -> void:
	if current > _current:
		_heal_flash = HEAL_FLASH_TIME
	elif current < _current:
		_trail_wait = TRAIL_DELAY
	_current = current
	_max = max_value
	_update_text()
	set_process(true)


func _on_stamina_changed(current: float, max_value: float) -> void:
	_stamina = clampf(current / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	var target: float = _ratio()
	_shown = lerpf(_shown, target, clampf(FILL_SPEED * delta, 0.0, 1.0))
	if _trail_wait > 0.0:
		_trail_wait -= delta
	else:
		_trail = move_toward(_trail, _shown, TRAIL_SPEED * delta)
	if _trail < _shown:
		_trail = _shown
	_heal_flash = maxf(_heal_flash - delta, 0.0)
	queue_redraw()
	# Останавливаемся, когда всё догнало значение и не нужно мигать
	var settled: bool = absf(_shown - target) < 0.001 and absf(_trail - _shown) < 0.001
	# После смерти (0 HP) мигать нечему — тоже останавливаемся
	if settled and _heal_flash <= 0.0 and (target > low_threshold or target <= 0.0):
		_shown = target
		set_process(false)


func _draw() -> void:
	var bar := Rect2(Vector2(ICON_RADIUS, 4.0), BAR_SIZE)
	var ratio: float = _ratio()
	var low: bool = ratio <= low_threshold and ratio > 0.0

	# Рамка с тенью и ложбина под заливку
	draw_style_box(_frame_style, bar)
	var inner := bar.grow(-5.0)
	draw_style_box(_well_style, inner)

	# След урона
	if _trail > _shown + 0.001:
		draw_style_box(_trail_style, Rect2(inner.position, Vector2(inner.size.x * _trail, inner.size.y)))

	# Заливка: цвет по здоровью, мигание при низком, вспышка при лечении
	if _shown > 0.005:
		var color: Color = _health_color(_shown)
		if low:
			color = color.lightened(0.25 * (0.5 + 0.5 * sin(_time * LOW_PULSE_SPEED)))
		if _heal_flash > 0.0:
			color = color.lerp(Color(0.7, 1.0, 0.7), _heal_flash / HEAL_FLASH_TIME * 0.6)
		_fill_style.bg_color = color
		_fill_style.border_color = color.darkened(0.35)
		var fill := Rect2(inner.position, Vector2(maxf(inner.size.x * _shown, 8.0), inner.size.y))
		draw_style_box(_fill_style, fill)
		# Блик сверху и тень снизу — объём
		draw_rect(Rect2(fill.position + Vector2(4.0, 3.0), Vector2(fill.size.x - 8.0, fill.size.y * 0.28)),
			Color(1.0, 1.0, 1.0, 0.28))
		draw_rect(Rect2(fill.position + Vector2(3.0, fill.size.y * 0.72), Vector2(fill.size.x - 6.0, fill.size.y * 0.22)),
			Color(0.0, 0.0, 0.0, 0.18))

	# Деления по 25%
	for i in range(1, 4):
		var x: float = inner.position.x + inner.size.x * i * 0.25
		draw_line(Vector2(x, inner.position.y + 3.0), Vector2(x, inner.end.y - 3.0), Color(0.0, 0.0, 0.0, 0.3), 2.0)

	# Число
	var font: Font = ThemeDB.fallback_font
	var text_size: Vector2 = font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var baseline: float = inner.get_center().y + (font.get_ascent(FONT_SIZE) - font.get_descent(FONT_SIZE)) * 0.5
	var text_pos := Vector2(inner.get_center().x - text_size.x * 0.5, baseline)
	draw_string_outline(font, text_pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 5, Color(0.0, 0.0, 0.0, 0.8))
	draw_string(font, text_pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)

	# Выносливость: тонкая полоска под здоровьем (видна, пока не полная)
	if _stamina < 0.999:
		var stamina_rect := Rect2(Vector2(bar.position.x + 8.0, bar.end.y + 4.0),
			Vector2(bar.size.x - 16.0, STAMINA_HEIGHT))
		draw_rect(stamina_rect, Color(0.0, 0.0, 0.0, 0.55))
		var fill_color: Color = STAMINA_COLOR if _stamina > 0.25 else STAMINA_LOW_COLOR
		draw_rect(Rect2(stamina_rect.position, Vector2(stamina_rect.size.x * _stamina, STAMINA_HEIGHT)), fill_color)
		draw_rect(Rect2(stamina_rect.position, Vector2(stamina_rect.size.x * _stamina, STAMINA_HEIGHT * 0.35)),
			Color(1.0, 1.0, 1.0, 0.3))

	_draw_icon(Vector2(ICON_RADIUS, bar.get_center().y), low)


## Значок аптечки: объёмный круг с крестом слева от полоски
func _draw_icon(center: Vector2, low: bool) -> void:
	var pulse: float = 1.0 + (0.08 * sin(_time * LOW_PULSE_SPEED * 1.5) if low else 0.0)
	var r: float = ICON_RADIUS * pulse
	draw_circle(center + Vector2(0.0, 3.0), r, Color(0.0, 0.0, 0.0, 0.4))
	draw_circle(center, r, Color(0.55, 0.06, 0.05))
	draw_circle(center - Vector2(0.0, 1.5), r * 0.86, Color(0.85, 0.14, 0.1))
	draw_set_transform(center - Vector2(0.0, r * 0.4), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, r * 0.55, Color(1.0, 1.0, 1.0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var arm: float = r * 0.5
	var thick: float = r * 0.32
	draw_rect(Rect2(center - Vector2(arm, thick * 0.5), Vector2(arm * 2.0, thick)), Color.WHITE)
	draw_rect(Rect2(center - Vector2(thick * 0.5, arm), Vector2(thick, arm * 2.0)), Color.WHITE)


func _health_color(ratio: float) -> Color:
	if ratio >= 0.5:
		return MID_COLOR.lerp(FULL_COLOR, (ratio - 0.5) * 2.0)
	return LOW_COLOR.lerp(MID_COLOR, ratio * 2.0)


func _ratio() -> float:
	return clampf(_current / _max, 0.0, 1.0) if _max > 0.0 else 0.0


func _update_text() -> void:
	_text = "%d / %d" % [ceili(_current), roundi(_max)]


func _build_styles() -> void:
	_frame_style = StyleBoxFlat.new()
	_frame_style.bg_color = FRAME_COLOR
	_frame_style.set_corner_radius_all(12)
	_frame_style.border_width_bottom = 4
	_frame_style.border_color = Color(0.0, 0.0, 0.0, 0.6)
	_frame_style.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	_frame_style.shadow_size = 6
	_frame_style.shadow_offset = Vector2(0.0, 3.0)

	_well_style = StyleBoxFlat.new()
	_well_style.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	_well_style.set_corner_radius_all(8)
	_well_style.border_width_top = 3  # внутренняя тень сверху — углубление
	_well_style.border_color = Color(0.0, 0.0, 0.0, 0.5)

	_fill_style = StyleBoxFlat.new()
	_fill_style.set_corner_radius_all(8)
	_fill_style.border_width_bottom = 3

	_trail_style = StyleBoxFlat.new()
	_trail_style.bg_color = TRAIL_COLOR
	_trail_style.set_corner_radius_all(8)
