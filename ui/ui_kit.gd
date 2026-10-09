class_name UIKit
extends RefCounted
## Общие функции для интерфейса, создаваемого кодом (крупно, под пальцы).

const BUTTON_HEIGHT: float = 72.0
const ACCENT: Color = Color(0.95, 0.75, 0.25)
const DIM: Color = Color(0.75, 0.75, 0.75)
const GOOD: Color = Color(0.55, 1.0, 0.55)
## Цвет кнопок меню (3D-стиль)
const BUTTON_COLOR: Color = Color(0.24, 0.27, 0.3)


static func label(text: String, font_size: int = 26, parent: Node = null) -> Label:
	var result := Label.new()
	result.text = text
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override(&"font_size", font_size)
	result.add_theme_constant_override(&"outline_size", 6)
	result.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	# Перенос слов в горизонтальном ряду без растяжения сжимает подпись до ширины буквы
	# («Р/Ж/А/В/Ы/Й» столбиком) — там перенос выключаем
	result.ready.connect(func() -> void: _fix_wrap.call_deferred(result), CONNECT_ONE_SHOT)
	if parent != null:
		parent.add_child(result)
	return result


## Подпись в HBox/HFlow без растяжения и без своей ширины — без переноса
static func _fix_wrap(target: Label) -> void:
	if not is_instance_valid(target) or target.autowrap_mode == TextServer.AUTOWRAP_OFF:
		return
	var parent: Node = target.get_parent()
	var in_row: bool = parent is HBoxContainer or parent is HFlowContainer
	if in_row and (target.size_flags_horizontal & Control.SIZE_EXPAND) == 0 and target.custom_minimum_size.x <= 0.0:
		target.autowrap_mode = TextServer.AUTOWRAP_OFF


## Число со словом в нужном падеже: count(3, "волна", "волны", "волн") → «3 волны»
static func count(value: int, one: String, few: String, many: String) -> String:
	var tail: int = absi(value) % 100
	var last: int = tail % 10
	var word: String = many
	if tail < 11 or tail > 14:
		if last == 1:
			word = one
		elif last >= 2 and last <= 4:
			word = few
	return "%d %s" % [value, word]


## Ряд вкладок: выбранная подсвечена; on_select(index) — при нажатии на другую
static func tab_bar(names: PackedStringArray, current: int, on_select: Callable) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override(&"h_separation", 10)
	row.add_theme_constant_override(&"v_separation", 10)
	for i in names.size():
		var tab := button(names[i], 24, 170.0)
		if i == current:
			tab.modulate = ACCENT
			var active := _button_box(BUTTON_COLOR.lightened(0.25), 3, 4)
			tab.add_theme_stylebox_override(&"normal", active)
			tab.add_theme_stylebox_override(&"hover", active)
		var index: int = i
		tab.pressed.connect(func() -> void:
			if index != current:
				on_select.call(index))
		row.add_child(tab)
	return row


## «N МОНЕТ / МОНЕТА / МОНЕТЫ» заглавными
static func coins_text(value: int) -> String:
	return count(value, "МОНЕТА", "МОНЕТЫ", "МОНЕТ")


static func button(text: String, font_size: int = 26, min_width: float = 0.0) -> Button:
	var result := Button.new()
	result.text = text
	result.focus_mode = Control.FOCUS_NONE
	result.custom_minimum_size = Vector2(min_width, BUTTON_HEIGHT)
	result.add_theme_font_size_override(&"font_size", font_size)
	apply_3d_style(result)
	result.pressed.connect(func() -> void: Sfx.click())
	return result


## Объёмная кнопка: толстый нижний край (боковина), тень; при нажатии «вдавливается»
static func apply_3d_style(target: Button) -> void:
	target.add_theme_stylebox_override(&"normal", _button_box(BUTTON_COLOR, 7, 0))
	target.add_theme_stylebox_override(&"hover", _button_box(BUTTON_COLOR.lightened(0.12), 7, 0))
	target.add_theme_stylebox_override(&"pressed", _button_box(BUTTON_COLOR.darkened(0.1), 2, 5))
	target.add_theme_stylebox_override(&"disabled", _button_box(BUTTON_COLOR.darkened(0.45), 4, 3))
	target.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	target.add_theme_color_override(&"font_disabled_color", Color(1.0, 1.0, 1.0, 0.35))
	target.add_theme_constant_override(&"outline_size", 4)
	target.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.6))


## edge — высота боковины снизу, sink — насколько содержимое опущено (нажатие)
static func _button_box(color: Color, edge: int, sink: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(14)
	box.border_width_bottom = edge
	box.border_width_top = sink
	box.border_color = color.darkened(0.55)
	box.border_blend = false
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	box.shadow_size = 6 if sink == 0 else 2
	box.shadow_offset = Vector2(0.0, 4.0 if sink == 0 else 1.0)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 8.0 + sink
	box.content_margin_bottom = 8.0
	return box


static func panel_style(color: Color = Color(0.08, 0.09, 0.1, 0.94),
		radius: int = 18, margin: float = 24.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


## Карточка внутри окна (светлее фона)
static func card() -> PanelContainer:
	var result := PanelContainer.new()
	result.add_theme_stylebox_override(&"panel", panel_style(Color(1.0, 1.0, 1.0, 0.06), 14, 18.0))
	return result
