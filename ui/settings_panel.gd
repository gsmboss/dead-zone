class_name SettingsPanel
extends HubWindow
## Настройки по вкладкам (слева): управление, камера, кнопки, прицел, гироскоп, эффекты урона,
## звук, графика, сюжет, прочее. Работает в убежище и в меню паузы.

const TELEGRAM_URL: String = "https://t.me/SalamanderLab"
const INSTAGRAM_URL: String = "https://www.instagram.com/salamandersec/"
const SLIDER_HEIGHT: float = 64.0
const GRABBER_SIZE: int = 44

var _grabber_texture: Texture2D


func _ready() -> void:
	window_title = "НАСТРОЙКИ"
	process_mode = PROCESS_MODE_ALWAYS  # работает и на паузе
	_grabber_texture = _make_grabber_texture()
	super._ready()
	_build_tabs()


## Вкладки: каждая — своя страница настроек (последняя открытая запоминается)
const TABS: PackedStringArray = ["УПРАВЛЕНИЕ", "КАМЕРА", "КНОПКИ", "ПРИЦЕЛ", "ГИРОСКОП", "ЭФФЕКТЫ",
	"ЗВУК", "ГРАФИКА", "СЮЖЕТ", "ПРОЧЕЕ"]
const TAB_WIDTH: float = 270.0

static var _tab: int = 0

var _tab_buttons: Array[Button] = []


func _build_content() -> void:
	_tab = clampi(_tab, 0, TABS.size() - 1)
	_section(TABS[_tab])
	match _tab:
		0:
			_build_controls()
		1:
			_build_camera()
		2:
			_build_buttons()
		3:
			_build_crosshair()
		4:
			_build_gyro()
		5:
			_build_effects()
		6:
			_build_sound()
		7:
			_build_graphics()
		8:
			_build_story()
		_:
			_build_other()


## Колонка вкладок слева от содержимого (ставится один раз после построения окна)
func _build_tabs() -> void:
	var root: Node = _scroll.get_parent()
	var row := HBoxContainer.new()
	row.size_flags_vertical = SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", 16)
	root.add_child(row)
	root.move_child(row, _scroll.get_index())
	_scroll.reparent(row)
	_scroll.size_flags_horizontal = SIZE_EXPAND_FILL

	var tabs_scroll := ScrollContainer.new()
	tabs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs_scroll.custom_minimum_size = Vector2(TAB_WIDTH, 0.0)
	row.add_child(tabs_scroll)
	row.move_child(tabs_scroll, 0)
	TouchScroll.attach(tabs_scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 8)
	tabs_scroll.add_child(column)
	for i in TABS.size():
		var button := UIKit.button(TABS[i], 22)
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.pressed.connect(_select_tab.bind(i))
		column.add_child(button)
		_tab_buttons.append(button)
	_highlight_tabs()


func _select_tab(index: int) -> void:
	if index == _tab:
		return
	_tab = index
	_highlight_tabs()
	_scroll.scroll_vertical = 0  # новая вкладка — с начала (refresh сохраняет текущую прокрутку)
	refresh()


func _highlight_tabs() -> void:
	for i in _tab_buttons.size():
		_tab_buttons[i].modulate = UIKit.ACCENT if i == _tab else Color(1.0, 1.0, 1.0, 0.7)


func _build_controls() -> void:
	_slider("ЧУВСТВИТЕЛЬНОСТЬ ОБЗОРА", &"look_sensitivity", Settings.SENSITIVITY_MIN,
		Settings.SENSITIVITY_MAX, 5.0, func(v: float) -> String: return "%d" % roundi(v))
	_toggle("ИНВЕРСИЯ ОСИ Y", &"invert_y")
	_toggle("АВТООГОНЬ ПРИ НАВЕДЕНИИ", &"auto_fire")
	_toggle("ФАКЕЛ САМ ЗАЖИГАЕТСЯ НОЧЬЮ", &"torch_auto")


func _build_camera() -> void:
	_choice("ВИД", &"camera_mode", Settings.CAMERA_MODE_NAMES)
	_slider("ДИСТАНЦИЯ КАМЕРЫ (3-Е ЛИЦО)", &"camera_distance", 1.5, 4.5, 0.1,
		func(v: float) -> String: return "%.1f М" % v)
	_slider("ТРЯСКА КАМЕРЫ (ВЗРЫВЫ, БОСС)", &"camera_shake", 0.0, 1.0, 0.05, _percent)


func _build_buttons() -> void:
	var layout := UIKit.button("НАСТРОИТЬ РАСКЛАДКУ КНОПОК", 24)
	layout.pressed.connect(_open_layout_editor)
	content.add_child(layout)
	_choice("СТИЛЬ КНОПОК", &"button_style", Settings.BUTTON_STYLE_NAMES)
	_slider("РАЗМЕР КНОПОК", &"button_scale", 0.7, 1.4, 0.05, _percent)
	_slider("НЕПРОЗРАЧНОСТЬ КНОПОК", &"button_opacity", 0.15, 0.9, 0.05, _percent)


func _build_crosshair() -> void:
	_slider("РАЗМЕР ПРИЦЕЛА", &"crosshair_scale", 0.5, 2.0, 0.05, _percent)
	_choice("ЦВЕТ ПРИЦЕЛА", &"crosshair_color", Settings.CROSSHAIR_COLOR_NAMES)


func _build_gyro() -> void:
	if not OS.has_feature("mobile"):
		UIKit.label("ГИРОСКОП РАБОТАЕТ НА ТЕЛЕФОНЕ", 20, content).modulate = UIKit.DIM
	_toggle("ОБЗОР НАКЛОНОМ ТЕЛЕФОНА", &"gyro_enabled")
	_choice("КОГДА РАБОТАЕТ", &"gyro_mode", Settings.GYRO_MODE_NAMES)
	_slider("ЧУВСТВИТЕЛЬНОСТЬ ПО ГОРИЗОНТАЛИ", &"gyro_sensitivity_x", 0.1, 4.0, 0.05, _multiplier)
	_slider("ЧУВСТВИТЕЛЬНОСТЬ ПО ВЕРТИКАЛИ", &"gyro_sensitivity_y", 0.1, 4.0, 0.05, _multiplier)
	_toggle("ИНВЕРСИЯ ПО ГОРИЗОНТАЛИ", &"gyro_invert_x")
	_toggle("ИНВЕРСИЯ ПО ВЕРТИКАЛИ", &"gyro_invert_y")
	_slider("СГЛАЖИВАНИЕ", &"gyro_smoothing", 0.0, 0.9, 0.05, _percent)
	var rate_names := PackedStringArray()
	var rate_values: Array = []
	for rate: int in Settings.GYRO_RATES:
		rate_names.append("%d ГЦ" % rate)
		rate_values.append(rate)
	_choice("ЧАСТОТА ОПРОСА (FPS ГИРОСКОПА)", &"gyro_rate", rate_names, rate_values)


func _build_effects() -> void:
	_toggle("ПОКАЗЫВАТЬ, С КАКОЙ СТОРОНЫ АТАКУЮТ", &"damage_direction")
	_slider("ЯРКОСТЬ КРАСНОЙ ВСПЫШКИ ПРИ УРОНЕ", &"damage_flash", 0.0, 1.0, 0.05, _percent)
	_slider("ТОЛЧОК КАМЕРЫ ПРИ УРОНЕ", &"hit_shake", 0.0, 1.0, 0.05, _percent)
	_toggle("ПО СЕТИ: МЕТКА НАД ТЕМ, КТО В ВАС СТРЕЛЯЕТ", &"attacker_marker")
	var hint := UIKit.label("КОГТИ — УКУС ИЛИ УДАР ЗОМБИ, ПРИЦЕЛ — ВЫСТРЕЛ ИГРОКА, ЗВЕЗДА — ВЗРЫВ ИЛИ ОГОНЬ, "
		+ "КАПЛЯ — КИСЛОТА", 20, content)
	hint.modulate = UIKit.DIM
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_sound() -> void:
	_slider("ГРОМКОСТЬ", &"master_volume", 0.0, 1.0, 0.05, _percent)
	_slider("МУЗЫКА", &"music_volume", 0.0, 1.0, 0.05, _percent)


func _build_graphics() -> void:
	_toggle("ТЕНИ", &"shadows")
	_slider("РАЗРЕШЕНИЕ 3D (НИЖЕ — БЫСТРЕЕ)", &"render_scale", 0.5, 1.0, 0.05, _percent)
	_toggle("ПОКАЗЫВАТЬ FPS", &"show_fps")


func _build_story() -> void:
	_toggle("ПОКАЗЫВАТЬ КАТ-СЦЕНЫ", &"cutscenes")
	_toggle("ОЗВУЧКА КАТ-СЦЕН", &"voice_cutscenes")
	_toggle("ГОЛОСА ВЫЖИВШИХ В УБЕЖИЩЕ", &"voice_camp")
	_slider("ГРОМКОСТЬ ГОЛОСОВ", &"voice_volume", 0.0, 1.0, 0.05, _percent)
	var language: String = "РУССКИЙ" if VoiceOver.is_russian() else "АНГЛИЙСКИЙ"
	var voice_hint := UIKit.label("ЯЗЫК ОЗВУЧКИ: %s (КАК В ТЕЛЕФОНЕ)%s" % [language,
		"" if VoiceOver.is_available() else " • ГОЛОС НЕ НАЙДЕН: УСТАНОВИ СИНТЕЗ РЕЧИ GOOGLE"], 20, content)
	voice_hint.modulate = UIKit.DIM
	voice_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var replay := UIKit.button("ПОКАЗАТЬ ВСТУПЛЕНИЕ И ИНТРО МИССИЙ СНОВА", 22)
	replay.pressed.connect(func() -> void:
		GameState.reset_cutscenes()
		Sfx.play_2d(Sfx.sounds.ui_confirm, -4.0, 1.0, 0.0))
	content.add_child(replay)


func _build_other() -> void:
	var reset := UIKit.button("СБРОСИТЬ ВСЕ НАСТРОЙКИ", 24)
	reset.pressed.connect(_on_reset)
	content.add_child(reset)

	if Ads.privacy_options_required():
		UIKit.label("РЕКЛАМА", 24, content).modulate = UIKit.DIM
		var privacy := UIKit.button("НАСТРОЙКИ КОНФИДЕНЦИАЛЬНОСТИ", 22)
		privacy.pressed.connect(Ads.show_privacy_options)
		content.add_child(privacy)

	UIKit.label("SALAMANDERLAB", 24, content).modulate = UIKit.DIM
	var links := HBoxContainer.new()
	links.add_theme_constant_override(&"separation", 16)
	content.add_child(links)
	var telegram := UIKit.button("TELEGRAM", 24)
	telegram.size_flags_horizontal = SIZE_EXPAND_FILL
	telegram.pressed.connect(func() -> void: OS.shell_open(TELEGRAM_URL))
	links.add_child(telegram)
	var instagram := UIKit.button("INSTAGRAM", 24)
	instagram.size_flags_horizontal = SIZE_EXPAND_FILL
	instagram.pressed.connect(func() -> void: OS.shell_open(INSTAGRAM_URL))
	links.add_child(instagram)


func _section(title: String) -> void:
	UIKit.label(title, 28, content).modulate = UIKit.ACCENT


## Выбор из вариантов (ряд кнопок, выбранная подсвечена). values — значения вариантов,
## по умолчанию индексы 0..N-1
func _choice(title: String, key: StringName, names: PackedStringArray, values: Array = []) -> void:
	var card := UIKit.card()
	content.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	card.add_child(box)
	UIKit.label(title, 24, box)
	var row := HFlowContainer.new()
	row.add_theme_constant_override(&"h_separation", 10)
	row.add_theme_constant_override(&"v_separation", 10)
	box.add_child(row)
	var buttons: Array[Button] = []
	for i in names.size():
		var value: Variant = values[i] if i < values.size() else i
		var button := UIKit.button(names[i], 22, 150.0)
		buttons.append(button)
		row.add_child(button)
		button.pressed.connect(func() -> void:
			Sfx.click()
			Settings.set_value(key, value)
			_highlight_choice(buttons, values, Settings.get(key)))
	_highlight_choice(buttons, values, Settings.get(key))


func _highlight_choice(buttons: Array[Button], values: Array, current: Variant) -> void:
	for i in buttons.size():
		var value: Variant = values[i] if i < values.size() else i
		buttons[i].modulate = UIKit.ACCENT if value == current else Color(1.0, 1.0, 1.0, 0.75)


func _open_layout_editor() -> void:
	Sfx.click()
	var editor := ControlLayoutEditor.open(get_tree())
	visible = false
	editor.closed.connect(func() -> void:
		if is_instance_valid(self):
			visible = true)


func _percent(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


func _multiplier(v: float) -> String:
	return "x%.2f" % v


func _toggle(title: String, key: StringName) -> void:
	var check := CheckButton.new()
	check.text = title
	check.focus_mode = FOCUS_NONE
	check.custom_minimum_size = Vector2(0.0, UIKit.BUTTON_HEIGHT)
	check.add_theme_font_size_override(&"font_size", 24)
	check.button_pressed = bool(Settings.get(key))
	check.toggled.connect(func(on: bool) -> void:
		Sfx.click()
		Settings.set_value(key, on))
	content.add_child(check)


func _slider(title: String, key: StringName, min_value: float, max_value: float, step: float,
		format: Callable) -> void:
	var card := UIKit.card()
	content.add_child(card)
	var box := VBoxContainer.new()
	card.add_child(box)
	var label := UIKit.label("", 24, box)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = float(Settings.get(key))
	slider.focus_mode = FOCUS_NONE
	slider.custom_minimum_size = Vector2(0.0, SLIDER_HEIGHT)
	slider.add_theme_icon_override(&"grabber", _grabber_texture)
	slider.add_theme_icon_override(&"grabber_highlight", _grabber_texture)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	track.set_corner_radius_all(6)
	track.content_margin_top = 6.0
	track.content_margin_bottom = 6.0
	slider.add_theme_stylebox_override(&"slider", track)
	var filled := StyleBoxFlat.new()
	filled.bg_color = UIKit.ACCENT
	filled.set_corner_radius_all(6)
	slider.add_theme_stylebox_override(&"grabber_area", filled)
	slider.add_theme_stylebox_override(&"grabber_area_highlight", filled)
	box.add_child(slider)

	label.text = "%s: %s" % [title, format.call(slider.value)]
	slider.value_changed.connect(func(value: float) -> void:
		label.text = "%s: %s" % [title, format.call(value)]
		Settings.set_value(key, value, false))
	slider.drag_ended.connect(func(_changed: bool) -> void: Settings.save_settings())


func _on_reset() -> void:
	Settings.reset_to_defaults()
	refresh()


## Круглый «бегунок» слайдера, крупный под палец
func _make_grabber_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.95, 0.8))
	gradient.set_color(1, Color(0.9, 0.65, 0.2, 0.0))
	gradient.add_point(0.75, Color(0.95, 0.75, 0.25))
	gradient.add_point(0.8, Color(0.9, 0.65, 0.2, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = GRABBER_SIZE
	texture.height = GRABBER_SIZE
	return texture
