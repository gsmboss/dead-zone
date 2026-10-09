extends Control
## HUD убежища: монеты, кнопка взаимодействия, окна миссий и оружейной.
## Все элементы создаются кодом.

## Миссии для доски
@export var missions: Array[MissionData] = []

var _coins_label: Label
var _menu_bar: HBoxContainer
var _exit_panel: Control
var _daily_button: Button
var _menu: HubMenu
var _interact_button: Button
var _current: Interactable
var _window: HubWindow
var _player: Player


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	add_to_group(&"hub_hud")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()
	_connect_world.call_deferred()
	Ads.show_banner()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"interact"):
		_interact()
	if Input.is_action_just_pressed(&"pause") and not CutscenePlayer.is_blocking_input() \
			and not ControlLayoutEditor.is_open and not StoryPanel.is_open:
		_on_back()


## «Назад» в убежище: закрыть окно, иначе спросить про выход
func _on_back() -> void:
	if _menu != null:
		_menu.close_menu()
		return
	if _exit_panel != null:
		_exit_panel.queue_free()
		_exit_panel = null
		return
	if _window != null:
		_window.close_window()
		return
	_show_exit_confirm()


## Первый заход: предложить обучение (один раз; потом — кнопка в настройках, вкладка СЮЖЕТ)
const TUTORIAL_OFFERED: String = "tutorial_offered"
const DIALOG_WIDTH: float = 680.0


func offer_tutorial() -> void:
	if _exit_panel != null or _window != null or GameState.has_seen_cutscene(TutorialDirector.DONE_FLAG) \
			or GameState.has_seen_cutscene(TUTORIAL_OFFERED):
		return
	GameState.mark_cutscene_seen(TUTORIAL_OFFERED)
	var row: HBoxContainer = _open_dialog("ОБУЧЕНИЕ",
		"ДВЕ МИНУТЫ НА ПОЛИГОНЕ: ХОДЬБА, ОБЗОР, СТРЕЛЬБА, ПРИЦЕЛ И ПЕРВЫЕ ЗОМБИ. НАГРАДА — 150 МОНЕТ.")
	var go := UIKit.button("ПРОЙТИ", 28, 240.0)
	go.modulate = UIKit.GOOD
	go.pressed.connect(GameState.start_tutorial)
	row.add_child(go)
	var later := UIKit.button("ПОЗЖЕ", 28, 240.0)
	later.pressed.connect(_on_back)
	row.add_child(later)


func _show_exit_confirm() -> void:
	var row: HBoxContainer = _open_dialog("ВЫЙТИ ИЗ ИГРЫ?", "")
	var stay := UIKit.button("ОСТАТЬСЯ", 28, 240.0)
	stay.pressed.connect(_on_back)
	row.add_child(stay)
	var quit := UIKit.button("ВЫЙТИ", 28, 240.0)
	quit.pressed.connect(func() -> void:
		GameState.save_game()
		get_tree().quit())
	row.add_child(quit)


## Окно по центру экрана: заголовок, текст (можно пустой), ряд кнопок — его и возвращает.
## CenterContainer пересчитывает размер при каждой раскладке: текст с переносом не раздувает окно
func _open_dialog(title_text: String, body_text: String) -> HBoxContainer:
	var center := CenterContainer.new()
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_exit_panel = center
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", UIKit.panel_style())
	panel.custom_minimum_size.x = DIALOG_WIDTH
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 16)
	panel.add_child(box)
	var title := UIKit.label(title_text, 40, box)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = UIKit.ACCENT
	if not body_text.is_empty():
		var text := UIKit.label(body_text, 24, box)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	center.modulate.a = 0.0
	create_tween().tween_property(center, "modulate:a", 1.0, 0.2)
	return row


func _build_ui() -> void:
	# Меню — одной строкой сверху: не закрывает джойстик и кнопки слева, монеты справа
	_menu_bar = HBoxContainer.new()
	_menu_bar.add_theme_constant_override(&"separation", 10)
	add_child(_menu_bar)
	_menu_bar.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	_menu_bar.offset_left = 16.0
	_menu_bar.offset_right = -16.0
	# Сверху по центру — баннер рекламы (только на телефоне): меню под ним
	_menu_bar.offset_top = _menu_top()
	_menu_bar.offset_bottom = _menu_top() + UIKit.BUTTON_HEIGHT

	# Сверху — только главное: меню (все разделы плитками), сюжет и ежедневные награды
	var menu := _add_menu_button("☰  МЕНЮ", open_menu)
	menu.add_theme_font_size_override(&"font_size", 24)
	menu.custom_minimum_size.x = 180.0
	menu.modulate = UIKit.ACCENT
	var story := _add_menu_button("СЮЖЕТ", _choose.bind(&"story"))
	story.modulate = Color(1.0, 0.75, 0.45)
	_daily_button = _add_menu_button("ЕЖЕДНЕВНО", _choose.bind(&"daily"))

	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	spacer.mouse_filter = MOUSE_FILTER_IGNORE
	_menu_bar.add_child(spacer)
	_coins_label = UIKit.label("", 26, _menu_bar)
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coins_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_coins_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_coins_label.modulate = UIKit.ACCENT

	_interact_button = UIKit.button("", 30, 380.0)
	_interact_button.visible = false
	_interact_button.pressed.connect(_interact)
	add_child(_interact_button)
	_interact_button.set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM)
	_interact_button.offset_left = -190.0
	_interact_button.offset_right = 190.0
	_interact_button.offset_top = -140.0
	_interact_button.offset_bottom = -50.0


## Победа в главе: в убежище — её концовка (после последней — и эпилог)
func _show_pending_story() -> void:
	var pending: String = GameState.pop_pending_story()
	if pending.is_empty():
		return
	var parts: PackedStringArray = pending.split("|")
	var chapter: ChapterData = GameState.campaign.find(parts[0])
	if chapter == null:
		return
	var rewards := PackedStringArray()
	if chapter.rescued > 0:
		rewards.append(UIKit.t("СПАСЕНО ЛЮДЕЙ: %d") % chapter.rescued)
	if chapter.unlock_house:
		rewards.append("В ЛАГЕРЕ НОВЫЙ ДОМ")
	if chapter.unlock_car != null:
		rewards.append(UIKit.t("НОВАЯ МАШИНА: %s") % UIKit.t(chapter.unlock_car_name))
	var pages: PackedStringArray = chapter.outro_pages.duplicate()
	if not rewards.is_empty():
		pages.append("\n".join(rewards) + UIKit.t("\n\nПРОЙДЕНО %d%% СЮЖЕТА") % roundi(GameState.get_campaign_progress() * 100.0))
	# Пока идёт рассказ, игрок за ним не ходит и не прыгает (ДАЛЕЕ над кнопкой прыжка)
	_set_player_controls(false)
	if chapter.outro_film != null and Settings.cutscenes:
		await StoryCinema.play(get_tree(), chapter.outro_film).finished
		_set_player_controls(false)
	var panel := StoryPanel.open(get_tree(), UIKit.t("ГЛАВА ПРОЙДЕНА  •  %s") % UIKit.t(chapter.title), pages, "В ЛАГЕРЬ")
	if parts.size() > 1 and parts[1] == "epilogue":
		panel.finished.connect(func() -> void:
			var film: StoryFilm = GameState.campaign.epilogue_film
			if film != null and Settings.cutscenes:
				await StoryCinema.play(get_tree(), film).finished
				_set_player_controls(false)
			var epilogue := StoryPanel.open(get_tree(), "ЭПИЛОГ", GameState.campaign.epilogue_pages, "КОНЕЦ")
			epilogue.finished.connect(_on_story_closed))
	else:
		panel.finished.connect(_on_story_closed)


func _on_story_closed() -> void:
	if _window == null:
		_set_player_controls(true)


## Меню-сетка всех разделов (HubMenu)
func open_menu() -> void:
	if _menu != null or _window != null or _exit_panel != null:
		return
	_menu = HubMenu.new()
	_menu.chosen.connect(_on_menu_chosen)
	_menu.closed.connect(_on_menu_closed)
	add_child(_menu)
	_set_player_controls(false)
	Ads.hide_banner()  # баннер сверху не закрывает заголовок меню


func _on_menu_closed() -> void:
	_menu = null
	_set_player_controls(true)
	Ads.show_banner()


func _on_menu_chosen(id: StringName) -> void:
	_menu = null
	_set_player_controls(true)
	_choose(id)


## Открыть раздел убежища по id (плитка меню или кнопка сверху)
func _choose(id: StringName) -> void:
	match id:
		&"story":
			_open_window(CampaignPanel.new())
		&"missions":
			var select := MissionSelect.new()
			select.missions = missions
			_open_window(select)
		&"shop":
			_open_window(ShopPanel.new())
		&"character":
			_open_window(SkinPanel.new())
		&"cars":
			_open_window(CarPanel.new())
		&"base":
			_open_window(BasePanel.new())
		&"daily":
			_open_window(DailyPanel.new())
		&"online":
			_open_window(LobbyPanel.new())
		&"settings":
			_open_window(SettingsPanel.new())
		&"tutorial":
			GameState.start_tutorial()


## Кнопка в верхней строке меню убежища
func _add_menu_button(text: String, callback: Callable) -> Button:
	var button := UIKit.button(text, 19)
	button.pressed.connect(callback)
	_menu_bar.add_child(button)
	return button


func _connect_world() -> void:
	_show_pending_story.call_deferred()
	# Вернулись из матча по сети — сразу в лобби
	if Net.is_online():
		_open_window.call_deferred(LobbyPanel.new())
	_player = get_tree().get_first_node_in_group(&"player") as Player
	GameState.coins_changed.connect(_update_coins)
	GameState.progress_changed.connect(_update_daily_badge)
	_update_coins(GameState.coins)
	_update_daily_badge()
	for node: Node in get_tree().get_nodes_in_group(&"interactables"):
		var interactable := node as Interactable
		if interactable != null:
			interactable.player_entered.connect(_on_player_entered)
			interactable.player_exited.connect(_on_player_exited)
			interactable.prompt_changed.connect(_on_prompt_changed)


func _update_coins(coins: int) -> void:
	_coins_label.text = UIKit.t("МОНЕТЫ: %d") % coins
	# Счётчик «подпрыгивает» при изменении
	_coins_label.pivot_offset = Vector2(_coins_label.size.x, _coins_label.size.y * 0.5)
	_coins_label.scale = Vector2.ONE * 1.25
	create_tween().tween_property(_coins_label, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## «!» на кнопке, если есть что забрать
func _update_daily_badge() -> void:
	var has_rewards: bool = GameState.has_unclaimed_rewards()
	_daily_button.text = "ЕЖЕДНЕВНО  !" if has_rewards else "ЕЖЕДНЕВНО"
	_daily_button.modulate = UIKit.ACCENT if has_rewards else Color.WHITE


func _on_player_entered(interactable: Interactable) -> void:
	_current = interactable
	_interact_button.text = interactable.prompt
	_interact_button.visible = _window == null


func _on_prompt_changed(interactable: Interactable) -> void:
	if _current == interactable:
		_interact_button.text = interactable.prompt


func _on_player_exited(interactable: Interactable) -> void:
	if _current == interactable:
		_current = null
		_interact_button.visible = false


func _interact() -> void:
	if _current == null or _window != null or _menu != null:
		return
	match _current.action_id:
		&"missions", &"shop":
			_choose(_current.action_id)
		_:
			_current.interact()


func _menu_top() -> float:
	return 12.0 + (Ads.BANNER_RESERVE if Ads.is_supported() else 0.0)


func _exit_tree() -> void:
	Ads.hide_banner()


func _open_window(window: HubWindow) -> void:
	if _window != null:
		window.free()
		return
	_window = window
	window.closed.connect(_on_window_closed)
	add_child(window)
	_interact_button.visible = false
	_menu_bar.visible = false
	Ads.hide_banner()  # окна на весь экран — баннер не перекрывает кнопки
	_set_player_controls(false)


func _on_window_closed() -> void:
	_window = null
	_interact_button.visible = _current != null
	_menu_bar.visible = true
	Ads.show_banner()
	# Меню «выезжает» сверху
	_menu_bar.modulate.a = 0.0
	_menu_bar.position.y = -40.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_menu_bar, "modulate:a", 1.0, 0.25)
	tween.tween_property(_menu_bar, "position:y", _menu_top(), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_set_player_controls(true)


func _set_player_controls(enabled: bool) -> void:
	if _player == null:
		return
	_player.input_enabled = enabled
	if _player.touch_controls != null:
		_player.touch_controls.visible = enabled
