class_name StoryPanel
extends CanvasLayer
## Рассказ сюжета поверх всего: тёмный экран с полосами «опасно», заголовок главы,
## текст печатается по буквам, «ДАЛЕЕ ▸» / «ПРОПУСТИТЬ», кнопка в конце (НАЧАТЬ, В ЛАГЕРЬ…).
## Тап по тексту — сразу показать страницу целиком. Сам удаляется, сигнал finished.

signal finished

## Рассказ открыт: «Назад» закрывает его, а не окна под ним
static var is_open: bool = false
## Сколько рассказов открыто (эпилог открывается из finished главы — флаг одного окна сбрасывался)
static var _open_count: int = 0

const CHARS_PER_SECOND: float = 42.0
const RUST: Color = Color(0.85, 0.42, 0.12)

var _title_text: String = ""
var _pages: PackedStringArray = []
var _final_button_text: String = "ДАЛЕЕ"
var _page: int = 0
var _visible_chars: float = 0.0
var _root: Control
var _text: Label
var _counter: Label
var _next: Button


## Открыть рассказ: title — заголовок, pages — страницы, final_text — надпись последней кнопки
static func open(tree: SceneTree, title: String, pages: PackedStringArray,
		final_text: String = "ДАЛЕЕ") -> StoryPanel:
	var panel := StoryPanel.new()
	panel._title_text = title
	panel._pages = pages
	panel._final_button_text = final_text
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	parent.add_child(panel)
	return panel


func _ready() -> void:
	layer = 70
	_open_count += 1
	is_open = true
	process_mode = PROCESS_MODE_ALWAYS
	_build()
	if _pages.is_empty():
		_finish.call_deferred()
		return
	_show_page(0)
	_root.modulate.a = 0.0
	create_tween().set_ignore_time_scale(true).tween_property(_root, "modulate:a", 1.0, 0.35)


func _process(delta: float) -> void:
	if _text == null or _page >= _pages.size():
		return
	var total: int = _text.get_total_character_count()
	if _visible_chars < total:
		_visible_chars = minf(_visible_chars + CHARS_PER_SECOND * delta, total)
		_text.visible_characters = int(_visible_chars)
	if Input.is_action_just_pressed(&"pause"):
		_finish()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var background := ColorRect.new()
	background.color = Color(0.03, 0.025, 0.025, 0.96)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(background)

	for top: bool in [true, false]:
		var stripe := HazardStripe.new()
		_root.add_child(stripe)
		stripe.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		if top:
			stripe.offset_bottom = 14.0
		else:
			stripe.offset_top = -14.0

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 22)
	_root.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 90.0
	box.offset_right = -90.0
	box.offset_top = 50.0
	box.offset_bottom = -40.0

	var header := HBoxContainer.new()
	box.add_child(header)
	var title := UIKit.label(_title_text, 40, header)
	title.modulate = RUST
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	var skip := UIKit.button("ПРОПУСТИТЬ  ▸▸", 22, 240.0)
	skip.pressed.connect(_finish)
	header.add_child(skip)

	_text = UIKit.label("", 32, box)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.mouse_filter = Control.MOUSE_FILTER_STOP
	_text.gui_input.connect(_on_text_input)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override(&"separation", 20)
	box.add_child(footer)
	_counter = UIKit.label("", 22, footer)
	_counter.modulate = UIKit.DIM
	_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next = UIKit.button("ДАЛЕЕ  ▸", 30, 300.0)
	_next.custom_minimum_size.y = 88.0
	_next.pressed.connect(_on_next)
	footer.add_child(_next)


func _show_page(index: int) -> void:
	_page = index
	_text.text = _pages[index]
	_visible_chars = 0.0
	_text.visible_characters = 0
	_counter.text = "%d / %d" % [index + 1, _pages.size()]
	var last: bool = index >= _pages.size() - 1
	_next.text = (_final_button_text + "  ▸") if last else "ДАЛЕЕ  ▸"
	_next.modulate = UIKit.GOOD if last else Color.WHITE


func _on_text_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		# Тап по тексту — показать страницу сразу (или перейти дальше)
		if _text.visible_characters < _text.get_total_character_count():
			_visible_chars = _text.get_total_character_count()
			_text.visible_characters = -1
		else:
			_on_next()


func _on_next() -> void:
	if _text.visible_characters != -1 and _text.visible_characters < _text.get_total_character_count():
		_visible_chars = _text.get_total_character_count()
		_text.visible_characters = -1
		return
	if _page + 1 < _pages.size():
		_show_page(_page + 1)
	else:
		_finish()


func _exit_tree() -> void:
	_open_count = maxi(_open_count - 1, 0)
	is_open = _open_count > 0


func _finish() -> void:
	if is_queued_for_deletion():
		return
	finished.emit()
	queue_free()
