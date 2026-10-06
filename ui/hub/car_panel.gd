class_name CarPanel
extends HubWindow
## Окно «АВТОСАЛОН»: машины классов D/C/B/A — 3D-превью, характеристики, покупка и выбор.
## Для своей машины — тюнинг (двигатель, газ, управление, таран), покраска и неон.
## Выбранная машина ждёт игрока в городе у старта и едет с ним в матч по сети.

const TUNING_NAMES: Dictionary = {
	"engine": ["ДВИГАТЕЛЬ", "+7% МАКС. СКОРОСТИ"],
	"turbo": ["ГАЗ (ТУРБО)", "+12% РАЗГОНА"],
	"handling": ["УПРАВЛЕНИЕ", "+6% РУЛЯ, +8% СЦЕПЛЕНИЯ"],
	"ram": ["ТАРАН", "+25% УРОНА СБИТЫМ ЗОМБИ"],
}
## Характеристика → [подпись, тюнинг, прибавка за уровень]
const STATS: Array = [
	["speed", "СКОРОСТЬ", "engine", 0.07],
	["acceleration", "РАЗГОН", "turbo", 0.12],
	["handling", "УПРАВЛЕНИЕ", "handling", 0.06],
	["ram", "ТАРАН", "ram", 0.25],
]
const SWATCH_SIZE: float = 72.0

var _preview: CarPreview
var _shown_id: String = ""


func _ready() -> void:
	window_title = "АВТОСАЛОН"
	var selected: CarData = GameState.get_selected_car()
	_shown_id = selected.id if selected != null else ""
	GameState.coins_changed.connect(_on_coins_changed)
	GameState.cars_changed.connect(refresh)
	super._ready()


func _build_content() -> void:
	var shown: CarData = GameState.get_car(_shown_id)
	if shown == null and not GameState.cars.is_empty():
		shown = GameState.cars[0]
		_shown_id = shown.id
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 24)
	content.add_child(row)

	var left := VBoxContainer.new()
	left.add_theme_constant_override(&"separation", 8)
	row.add_child(left)
	_preview = CarPreview.new()
	left.add_child(_preview)
	if shown != null:
		_preview.show_car.call_deferred(shown, _paint_of(shown), _neon_of(shown))
		_build_info(shown, left)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 10)
	row.add_child(right)
	UIKit.label("МОНЕТЫ: %d" % GameState.coins, 26, right).modulate = UIKit.ACCENT
	UIKit.label("ВЫБРАННАЯ МАШИНА ЖДЁТ В ГОРОДЕ У СТАРТА И ЕДЕТ С ВАМИ В ИГРУ ПО СЕТИ", 20, right).modulate = UIKit.DIM
	var selected: CarData = GameState.get_selected_car()
	for car: CarData in GameState.cars:
		right.add_child(_make_car_row(car, selected != null and selected.id == car.id))
	if shown != null and GameState.owns_car(shown.id):
		_build_tuning(shown, right)
		_build_paint(shown, right)
		_build_neon(shown, right)


## Имя, класс, характеристики (с учётом тюнинга) и описание
func _build_info(car: CarData, parent: Control) -> void:
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override(&"separation", 12)
	parent.add_child(title_row)
	var badge := UIKit.label(" %s " % car.get_class_letter(), 34, title_row)
	badge.modulate = car.get_class_color()
	var title := UIKit.label(car.title, 32, title_row)
	title.modulate = UIKit.ACCENT
	for stat: Array in STATS:
		var level: int = GameState.get_car_tuning(car.id, str(stat[2])) if GameState.owns_car(car.id) else 0
		var value: float = clampf(car.get_rating(str(stat[0])) * (1.0 + float(stat[3]) * level), 0.0, 1.0)
		parent.add_child(_make_stat_bar(str(stat[1]), value, car.get_class_color()))
	var description := UIKit.label(car.description, 20, parent)
	description.modulate = UIKit.DIM
	description.custom_minimum_size = Vector2(CarPreview.VIEW_SIZE.x, 0.0)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _make_stat_bar(caption: String, value: float, color: Color) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 10)
	var label := UIKit.label(caption, 20, line)
	label.custom_minimum_size = Vector2(170.0, 0.0)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(270.0, 20.0)
	bar.size_flags_vertical = SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	back.set_corner_radius_all(4)
	bar.add_theme_stylebox_override(&"fill", fill)
	bar.add_theme_stylebox_override(&"background", back)
	line.add_child(bar)
	return line


func _make_car_row(car: CarData, selected: bool) -> Control:
	var card := UIKit.card()
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 12)
	card.add_child(line)
	var badge := UIKit.label(car.get_class_letter(), 34, line)
	badge.modulate = car.get_class_color()
	badge.custom_minimum_size = Vector2(44.0, 0.0)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var look := UIKit.button(car.title, 24)
	look.size_flags_horizontal = SIZE_EXPAND_FILL
	look.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if car.id == _shown_id:
		look.modulate = UIKit.ACCENT
	look.pressed.connect(func() -> void:
		_shown_id = car.id
		refresh())
	line.add_child(look)

	if selected:
		var label := UIKit.label("ВЫБРАНА", 24, line)
		label.modulate = UIKit.GOOD
		label.custom_minimum_size = Vector2(240.0, 0.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif GameState.owns_car(car.id):
		var choose := UIKit.button("ВЫБРАТЬ", 24, 240.0)
		choose.pressed.connect(func() -> void:
			GameState.select_car(car.id)
			_shown_id = car.id
			Sfx.play_2d(Sfx.sounds.ui_confirm, -4.0, 1.0, 0.0))
		line.add_child(choose)
	else:
		var buy := UIKit.button("КУПИТЬ %d" % car.price, 24, 240.0)
		buy.disabled = GameState.coins < car.price
		buy.pressed.connect(func() -> void:
			_shown_id = car.id
			_play(GameState.buy_car(car.id)))
		line.add_child(buy)
	return card


func _build_tuning(car: CarData, parent: Control) -> void:
	UIKit.label("ТЮНИНГ: %s" % car.title, 28, parent).modulate = UIKit.ACCENT
	for stat: String in GameState.CAR_TUNING:
		var names: Array = TUNING_NAMES.get(stat, [stat, ""])
		var line := HBoxContainer.new()
		line.add_theme_constant_override(&"separation", 12)
		parent.add_child(line)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = SIZE_EXPAND_FILL
		line.add_child(texts)
		var level: int = GameState.get_car_tuning(car.id, stat)
		UIKit.label("%s  %s" % [names[0], _level_marks(level)], 24, texts)
		UIKit.label(str(names[1]), 18, texts).modulate = UIKit.DIM
		var cost: int = GameState.get_car_tuning_cost(car.id, stat)
		var button := UIKit.button("МАКС" if cost < 0 else "+  %d" % cost, 24, 200.0)
		button.disabled = cost < 0 or GameState.coins < cost
		button.pressed.connect(func() -> void: _play(GameState.tune_car(car.id, stat)))
		line.add_child(button)


func _level_marks(level: int) -> String:
	return "■".repeat(level) + "□".repeat(maxi(GameState.CAR_TUNING_MAX - level, 0))


## Цветные квадраты покраски: заводской — бесплатно, остальные — по цене
func _build_paint(car: CarData, parent: Control) -> void:
	var current: int = GameState.get_car_paint_index(car.id)
	UIKit.label("ПОКРАСКА: %s  (%d МОНЕТ, ЗАВОДСКОЙ — БЕСПЛАТНО)" % [GameState.CAR_PAINT_NAMES[current],
		GameState.CAR_PAINT_PRICE], 24, parent).modulate = UIKit.ACCENT
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 10)
	parent.add_child(grid)
	for i in GameState.CAR_PAINTS.size():
		var swatch := _make_swatch(GameState.CAR_PAINTS[i] if i > 0 else Color(0.85, 0.85, 0.85), i == current)
		if i == 0:
			swatch.text = "—"
		var cost: int = 0 if i == 0 else GameState.CAR_PAINT_PRICE
		swatch.disabled = i != current and GameState.coins < cost
		var paint_index: int = i
		swatch.pressed.connect(func() -> void:
			if paint_index != GameState.get_car_paint_index(car.id):
				_play(GameState.paint_car(car.id, paint_index)))
		grid.add_child(swatch)


## Неон под днищем: первая установка платная, цвет и выключение — бесплатно
func _build_neon(car: CarData, parent: Control) -> void:
	var installed: bool = GameState.has_car_neon_installed(car.id)
	var current: int = GameState.get_car_neon_index(car.id)
	var caption: String = "НЕОН: ВЫБЕРИ ЦВЕТ" if installed else "НЕОН ПОД ДНИЩЕМ — %d МОНЕТ" % GameState.CAR_NEON_PRICE
	UIKit.label(caption, 24, parent).modulate = UIKit.ACCENT
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 10)
	parent.add_child(grid)
	if installed:
		var off := UIKit.button("ВЫКЛ", 22, 120.0)
		off.disabled = current < 0
		off.pressed.connect(func() -> void: _play(GameState.set_car_neon(car.id, -1)))
		grid.add_child(off)
	for i in GameState.CAR_NEONS.size():
		var swatch := _make_swatch(GameState.CAR_NEONS[i], i == current)
		swatch.disabled = not installed and GameState.coins < GameState.CAR_NEON_PRICE
		var neon_index: int = i
		swatch.pressed.connect(func() -> void:
			if neon_index != GameState.get_car_neon_index(car.id):
				_play(GameState.set_car_neon(car.id, neon_index)))
		grid.add_child(swatch)


func _make_swatch(color: Color, selected: bool) -> Button:
	var swatch := Button.new()
	swatch.custom_minimum_size = Vector2(SWATCH_SIZE, SWATCH_SIZE)
	swatch.focus_mode = Control.FOCUS_NONE
	swatch.add_theme_font_size_override(&"font_size", 28)
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = color if state != &"disabled" else color.darkened(0.5)
		box.set_corner_radius_all(10)
		box.set_border_width_all(5 if selected else 2)
		box.border_color = UIKit.ACCENT if selected else Color(0.0, 0.0, 0.0, 0.6)
		swatch.add_theme_stylebox_override(state, box)
	return swatch


func _paint_of(car: CarData) -> Color:
	return GameState.CAR_PAINTS[GameState.get_car_paint_index(car.id)] if GameState.owns_car(car.id) else Color.WHITE


func _neon_of(car: CarData) -> Color:
	var index: int = GameState.get_car_neon_index(car.id) if GameState.owns_car(car.id) else -1
	return GameState.CAR_NEONS[index] if index >= 0 else Color(0.0, 0.0, 0.0, 0.0)


func _play(success: bool) -> void:
	if success:
		Sfx.play_2d(Sfx.sounds.purchase, -4.0, 1.0, 0.0)
	else:
		Sfx.error()


func _on_coins_changed(_value: int) -> void:
	refresh()
