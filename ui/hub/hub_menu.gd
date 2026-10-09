class_name HubMenu
extends Control
## Меню убежища: сетка крупных плиток (значок, название, состояние) поверх затемнения.
## Плитка шлёт chosen(id) — окно открывает HubHUD. Закрыть — «✕», тап мимо или «назад».

signal chosen(id: StringName)
signal closed

const ICON_DIR: String = "res://ui/hub/icons/"
const TILE_SIZE: Vector2 = Vector2(168.0, 156.0)
const ICON_SIZE: float = 54.0
const COLUMNS: int = 6
## [id, название, значок, цвет]
const TILES: Array = [
	[&"story", "СЮЖЕТ", "story", Color(1.0, 0.75, 0.45)],
	[&"missions", "МИССИИ", "missions", Color(1.0, 0.5, 0.45)],
	[&"shop", "ОРУЖЕЙНАЯ", "shop", Color(1.0, 0.85, 0.4)],
	[&"character", "ПЕРСОНАЖ", "character", Color(0.8, 0.85, 1.0)],
	[&"companion", "НАПАРНИК", "companion", Color(1.0, 0.8, 0.6)],
	[&"cars", "МАШИНЫ", "cars", Color(0.75, 1.0, 0.75)],
	[&"base", "БАЗА", "base", Color(0.9, 0.8, 0.65)],
	[&"daily", "ЕЖЕДНЕВНО", "daily", Color(1.0, 0.9, 0.5)],
	[&"online", "ПО СЕТИ", "online", Color(0.7, 0.95, 1.0)],
	[&"settings", "НАСТРОЙКИ", "settings", Color(0.85, 0.85, 0.85)],
	[&"tutorial", "ОБУЧЕНИЕ", "tutorial", Color(0.7, 1.0, 0.85)],
]

var _panel: PanelContainer


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override(&"panel", UIKit.panel_style(Color(0.07, 0.08, 0.1, 0.96), 20, 20.0))
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	_panel.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 12)
	box.add_child(header)
	var title := UIKit.label("УБЕЖИЩЕ", 34, header)
	title.modulate = UIKit.ACCENT
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var coins := UIKit.label(UIKit.coins_text(GameState.coins), 24, header)
	coins.modulate = UIKit.ACCENT
	coins.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var close := UIKit.button("✕", 30, 80.0)
	close.pressed.connect(close_menu)
	header.add_child(close)

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override(&"h_separation", 12)
	grid.add_theme_constant_override(&"v_separation", 12)
	box.add_child(grid)
	for entry: Array in TILES:
		grid.add_child(_make_tile(entry[0], str(entry[1]), str(entry[2]), entry[3]))

	# Появление: панель «впрыгивает»
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	_panel.scale = Vector2.ONE * 0.92
	_animate_in.call_deferred()


func _animate_in() -> void:
	_panel.pivot_offset = _panel.size * 0.5
	_panel.create_tween().tween_property(_panel, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close_menu() -> void:
	closed.emit()
	queue_free()


func _on_dim_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tap:
		close_menu()


func _make_tile(id: StringName, title_text: String, icon_name: String, tint: Color) -> Button:
	var tile := UIKit.button("", 20)
	tile.custom_minimum_size = TILE_SIZE
	tile.pressed.connect(func() -> void:
		chosen.emit(id)
		queue_free())
	var box := VBoxContainer.new()
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 4)
	tile.add_child(box)
	box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	box.offset_top = 10.0
	box.offset_bottom = -12.0
	var path: String = ICON_DIR + icon_name + ".svg"
	var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	if texture != null:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.modulate = tint
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		box.add_child(icon)
	var title := UIKit.label(title_text, 22, box)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	var status_text: String = _status(id)
	if not status_text.is_empty():
		var status := UIKit.label(status_text, 15, box)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.autowrap_mode = TextServer.AUTOWRAP_OFF
		status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		status.custom_minimum_size.x = TILE_SIZE.x - 20.0
		status.modulate = UIKit.GOOD if _is_highlighted(id) else UIKit.DIM
	if _is_highlighted(id):
		tile.modulate = Color(1.15, 1.1, 0.85)
	return tile


## Подпись-состояние под названием плитки
func _status(id: StringName) -> String:
	match id:
		&"story":
			return UIKit.t("ПРОЙДЕНО %d%%") % roundi(GameState.get_campaign_progress() * 100.0)
		&"missions":
			return "КАРТА ЗАРАЖЕНИЯ"
		&"shop":
			return "ОРУЖИЕ И ПРИПАСЫ"
		&"character":
			var skin: PlayerSkin = GameState.get_selected_skin()
			return skin.display_name if skin != null else ""
		&"companion":
			var companion: CompanionData = GameState.get_selected_companion()
			return companion.title if companion != null else "ИДЁШЬ ОДИН"
		&"cars":
			var car: CarData = GameState.get_selected_car()
			return car.title if car != null else ""
		&"base":
			return UIKit.t("СПАСЕНО: %d") % GameState.get_rescued_count()
		&"daily":
			return "НАГРАДА ЖДЁТ!" if GameState.has_unclaimed_rewards() else "НАГРАДЫ И ЗАДАНИЯ"
		&"online":
			return "WI-FI, ДО 4 ИГРОКОВ"
		&"settings":
			return "ГРАФИКА, УПРАВЛЕНИЕ"
		&"tutorial":
			return "ПРОЙДЕНО ✓" if GameState.has_seen_cutscene(TutorialDirector.DONE_FLAG) else "2 МИНУТЫ"
	return ""


func _is_highlighted(id: StringName) -> bool:
	match id:
		&"daily":
			return GameState.has_unclaimed_rewards()
		&"tutorial":
			return not GameState.has_seen_cutscene(TutorialDirector.DONE_FLAG)
	return false
