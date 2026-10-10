class_name CampaignPanel
extends HubWindow
## Окно «СЮЖЕТ»: карта области с главами (CampaignMap), процент прохождения, лагерь
## выживших в 3D (CampDiorama3D: дома, машины, спасённые люди) и досье выбранной главы —
## место, задача, награды, «ИСТОРИЯ» (перечитать) и «НАЧАТЬ ГЛАВУ».
## При первом открытии показывается пролог «как всё началось».

const RUST: Color = Color(0.85, 0.42, 0.12)
const PANEL_BG: Color = Color(0.06, 0.055, 0.05, 0.9)
const SIDE_WIDTH: float = 470.0
const PROLOGUE_ID: String = "story_prologue"

var _map: CampaignMap
var _dossier: VBoxContainer
var _progress_bar: ProgressBar
var _progress_label: Label
var _selected: int = 0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	_selected = _current_chapter()
	_build()
	_select(_selected)
	if not GameState.has_seen_cutscene(PROLOGUE_ID):
		_show_prologue.call_deferred(false)


func _build() -> void:
	var root := Control.new()
	root.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.03, 0.03, 0.03, 0.97)
	background.mouse_filter = MOUSE_FILTER_IGNORE
	root.add_child(background)
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	# Верх: полоса «опасно», название, процент, закрыть
	var top := VBoxContainer.new()
	top.add_theme_constant_override(&"separation", 0)
	root.add_child(top)
	top.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	top.offset_bottom = 100.0
	var stripe := HazardStripe.new()
	stripe.custom_minimum_size = Vector2(0.0, 12.0)
	top.add_child(stripe)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override(&"panel", UIKit.panel_style(Color(0.04, 0.035, 0.03, 0.9), 0, 12.0))
	top.add_child(bar)
	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 18)
	bar.add_child(header)
	var title := UIKit.label(GameState.campaign.title, 32, header)
	title.modulate = RUST
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	var progress_box := VBoxContainer.new()
	progress_box.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(progress_box)
	_progress_label = UIKit.label("", 20, progress_box)
	_progress_label.modulate = UIKit.ACCENT
	_progress_bar = ProgressBar.new()
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(0.0, 16.0)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	bar_bg.set_corner_radius_all(6)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = RUST
	bar_fill.set_corner_radius_all(6)
	_progress_bar.add_theme_stylebox_override(&"background", bar_bg)
	_progress_bar.add_theme_stylebox_override(&"fill", bar_fill)
	progress_box.add_child(_progress_bar)
	var prologue := UIKit.button("ПРОЛОГ", 22, 160.0)
	prologue.pressed.connect(_show_prologue.bind(true))
	header.add_child(prologue)
	var close := UIKit.button("ЗАКРЫТЬ", 22, 180.0)
	close.pressed.connect(close_window)
	header.add_child(close)

	# Слева — карта области
	_map = CampaignMap.new()
	root.add_child(_map)
	_map.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_map.offset_left = 16.0
	_map.offset_top = 112.0
	_map.offset_right = -SIDE_WIDTH - 32.0
	_map.offset_bottom = -16.0
	_map.chapter_selected.connect(_select)

	# Справа — лагерь в 3D и досье главы
	var side := PanelContainer.new()
	var style := UIKit.panel_style(PANEL_BG, 6, 14.0)
	style.border_color = RUST.darkened(0.3)
	style.set_border_width_all(3)
	side.add_theme_stylebox_override(&"panel", style)
	root.add_child(side)
	side.set_anchors_and_offsets_preset(PRESET_RIGHT_WIDE)
	side.offset_left = -SIDE_WIDTH - 16.0
	side.offset_right = -16.0
	side.offset_top = 112.0
	side.offset_bottom = -16.0
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	TouchScroll.attach(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 10)
	scroll.add_child(column)

	# Сверху — досье главы с кнопкой старта, ниже — лагерь
	_dossier = VBoxContainer.new()
	_dossier.add_theme_constant_override(&"separation", 10)
	column.add_child(_dossier)
	UIKit.label("ЛАГЕРЬ ВЫЖИВШИХ", 24, column).modulate = RUST
	var diorama := CampDiorama3D.new()
	diorama.custom_minimum_size = Vector2(0.0, 200.0)
	column.add_child(diorama)
	var cars: Array[PackedScene] = GameState.get_owned_cars()
	var stats := UIKit.label(UIKit.t("СПАСЕНО ЛЮДЕЙ: %d   •   ДОМОВ: %d   •   МАШИН: %d") % [
		GameState.get_rescued_count(), GameState.get_house_count(), cars.size()], 20, column)
	stats.modulate = UIKit.GOOD
	_update_progress()


func _update_progress() -> void:
	var progress: float = GameState.get_campaign_progress()
	_progress_bar.value = progress * 100.0
	_progress_label.text = UIKit.t("ПРОЙДЕНО %d%%") % roundi(progress * 100.0)


func _select(index: int) -> void:
	_selected = clampi(index, 0, GameState.campaign.chapters.size() - 1)
	_map.selected = _selected
	_map.queue_redraw()
	_fill_dossier()


func _fill_dossier() -> void:
	for child: Node in _dossier.get_children():
		child.queue_free()
	if GameState.campaign.chapters.is_empty():
		return
	var chapter: ChapterData = GameState.campaign.chapters[_selected]
	var done: bool = GameState.is_chapter_done(chapter.id)
	var unlocked: bool = GameState.is_chapter_unlocked(_selected)
	var art: Texture2D = StoryPanel.art_for(chapter.id)
	if art != null:
		# Картинка главы сверху досье (закрытая — затемнена)
		var picture := TextureRect.new()
		picture.texture = art
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.custom_minimum_size = Vector2(0.0, 170.0)
		picture.clip_contents = true
		picture.modulate = Color.WHITE if unlocked else Color(0.35, 0.35, 0.38)
		_dossier.add_child(picture)
	var stripe := HazardStripe.new()
	stripe.custom_minimum_size = Vector2(0.0, 8.0)
	_dossier.add_child(stripe)
	UIKit.label(UIKit.t("ГЛАВА %d  •  %s") % [_selected + 1, UIKit.t(chapter.title)], 28, _dossier).modulate = \
		CampaignMap.DONE if done else (RUST if unlocked else UIKit.DIM)
	UIKit.label(chapter.location_name, 20, _dossier).modulate = UIKit.DIM
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	_dossier.add_child(row)
	if unlocked:
		var story := UIKit.button("ИСТОРИЯ", 22, 150.0)
		story.pressed.connect(func() -> void:
			await _play_film(chapter.intro_film, true)
			StoryPanel.open(get_tree(), chapter.title, chapter.intro_pages, "ПОНЯТНО", chapter.id))
		row.add_child(story)
		var start := UIKit.button("ПЕРЕИГРАТЬ" if done else "НАЧАТЬ ГЛАВУ", 24)
		start.size_flags_horizontal = SIZE_EXPAND_FILL
		start.custom_minimum_size.y = 84.0
		start.modulate = UIKit.GOOD
		start.pressed.connect(_start_chapter.bind(chapter))
		row.add_child(start)

	var status: String = "ПРОЙДЕНА" if done else ("ДОСТУПНА" if unlocked else UIKit.t("ЗАКРЫТА: ПРОЙДИ ГЛАВУ %d") % _selected)
	UIKit.label(UIKit.t("СТАТУС: %s") % UIKit.t(status), 20, _dossier)
	if chapter.mission != null:
		UIKit.label(UIKit.t("ЗАДАЧА: %s") % UIKit.t(chapter.mission.description).to_upper(), 20, _dossier)
		UIKit.label(UIKit.t("ЦЕЛЬ: %s") % chapter.mission.get_goal_text().to_upper(), 20, _dossier)
	var rewards := PackedStringArray()
	if chapter.rescued > 0:
		rewards.append(UIKit.t("ЛЮДИ +%d") % chapter.rescued)
	if chapter.unlock_house:
		rewards.append("НОВЫЙ ДОМ")
	if chapter.unlock_car != null:
		rewards.append(UIKit.t("МАШИНА «%s»") % UIKit.t(chapter.unlock_car_name))
	if chapter.mission != null:
		rewards.append(UIKit.coins_text(chapter.mission.reward_coins))
	UIKit.label(UIKit.t("НАГРАДА: %s") % ", ".join(rewards), 20, _dossier).modulate = UIKit.ACCENT


## Фильм (первый раз), рассказ перед главой, затем миссия
func _start_chapter(chapter: ChapterData) -> void:
	if chapter.mission == null:
		push_warning("CampaignPanel: у главы '%s' нет миссии" % chapter.id)
		return
	await _play_film(chapter.intro_film, false)
	var panel := StoryPanel.open(get_tree(), UIKit.t("ГЛАВА %d  •  %s") % [_selected + 1, UIKit.t(chapter.title)],
		chapter.intro_pages, "В БОЙ", chapter.id)
	panel.finished.connect(func() -> void: GameState.start_mission(chapter.mission))


## Пролог: фильм (при первом открытии — если его ещё не показали в убежище) и рассказ
func _show_prologue(always: bool = true) -> void:
	GameState.mark_cutscene_seen(PROLOGUE_ID)
	await _play_film(GameState.campaign.prologue_film, always)
	StoryPanel.open(get_tree(), "КАК ВСЁ НАЧАЛОСЬ", GameState.campaign.prologue_pages, "К КАРТЕ", "prologue")


## Сюжетный фильм: always — показать и повторно (кнопки ИСТОРИЯ/ПРОЛОГ), иначе только первый раз
func _play_film(film: StoryFilm, always: bool) -> void:
	if film == null or not Settings.cutscenes:
		return
	var seen_id: String = "film_" + film.id
	if not always and GameState.has_seen_cutscene(seen_id):
		return
	GameState.mark_cutscene_seen(seen_id)
	await StoryCinema.play(get_tree(), film).finished


## Первая непройденная открытая глава (или последняя)
func _current_chapter() -> int:
	var chapters: Array[ChapterData] = GameState.campaign.chapters
	for i in chapters.size():
		if not GameState.is_chapter_done(chapters[i].id):
			return i
	return maxi(chapters.size() - 1, 0)
