class_name UIKit
extends RefCounted
## Общие функции для интерфейса, создаваемого кодом (крупно, под пальцы).

const BUTTON_HEIGHT: float = 72.0
const ACCENT: Color = Color(0.95, 0.75, 0.25)
const DIM: Color = Color(0.75, 0.75, 0.75)
const GOOD: Color = Color(0.55, 1.0, 0.55)


static func label(text: String, font_size: int = 26, parent: Node = null) -> Label:
	var result := Label.new()
	result.text = text
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override(&"font_size", font_size)
	result.add_theme_constant_override(&"outline_size", 6)
	result.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	if parent != null:
		parent.add_child(result)
	return result


static func button(text: String, font_size: int = 26, min_width: float = 0.0) -> Button:
	var result := Button.new()
	result.text = text
	result.focus_mode = Control.FOCUS_NONE
	result.custom_minimum_size = Vector2(min_width, BUTTON_HEIGHT)
	result.add_theme_font_size_override(&"font_size", font_size)
	return result


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
