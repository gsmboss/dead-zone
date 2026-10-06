class_name HubWindow
extends PanelContainer
## Базовое полноэкранное окно убежища: заголовок, «ЗАКРЫТЬ», прокручиваемое содержимое.
## Наследники переопределяют _build_content() и вызывают refresh() при изменениях.

signal closed

const SCREEN_MARGIN: float = 30.0

var window_title: String = ""
var content: VBoxContainer

var _scroll: ScrollContainer


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	add_theme_stylebox_override(&"panel", UIKit.panel_style())
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	offset_left = SCREEN_MARGIN
	offset_top = SCREEN_MARGIN
	offset_right = -SCREEN_MARGIN
	offset_bottom = -SCREEN_MARGIN

	var root := VBoxContainer.new()
	root.add_theme_constant_override(&"separation", 16)
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 16)
	root.add_child(header)

	var title := UIKit.label(window_title, 36, header)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.modulate = UIKit.ACCENT

	var close := UIKit.button("ЗАКРЫТЬ", 24, 200.0)
	close.pressed.connect(close_window)
	header.add_child(close)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	TouchScroll.attach(_scroll)  # листать пальцем, даже если он лёг на кнопку

	content = VBoxContainer.new()
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.add_theme_constant_override(&"separation", 14)
	_scroll.add_child(content)

	refresh()


## Перестроить содержимое, сохранив позицию прокрутки
func refresh() -> void:
	if content == null:
		return
	var scroll_position: int = _scroll.scroll_vertical
	for child: Node in content.get_children():
		child.queue_free()
	_build_content()
	_restore_scroll(scroll_position)


func close_window() -> void:
	closed.emit()
	queue_free()


## Переопределяется в наследниках
func _build_content() -> void:
	pass


func _restore_scroll(value: int) -> void:
	# Ждём кадр, пока контейнеры пересчитают размеры
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = value
