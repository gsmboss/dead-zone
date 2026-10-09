class_name MissionSelect
extends HubWindow
## Выбор миссии в стиле апокалипсиса: 3D-карта заражения на фоне (MissionMap3D),
## слева список миссий с иконками и звёздами, справа досье выбранной миссии
## (тип, локация, цель, враги, опасность, награда, рекорд) и кнопка «В БОЙ».
## Открывается терминалом МИССИИ вместо обычного окна.

const RUST: Color = Color(0.85, 0.42, 0.12)
const PANEL_BG: Color = Color(0.06, 0.055, 0.05, 0.88)
const LIST_WIDTH: float = 400.0
const DOSSIER_WIDTH: float = 560.0
const MAX_DANGER: int = 5

var missions: Array[MissionData] = []

var _map: MissionMap3D
var _rows: Array[Button] = []
var _selected: int = 0
var _dossier: VBoxContainer
var _coins_label: Label


func _ready() -> void:
	# Своя разметка вместо стандартного окна HubWindow
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	var valid: Array[MissionData] = []
	for mission: MissionData in missions:
		if mission != null:
			valid.append(mission)
	missions = valid
	_build()
	if not missions.is_empty():
		_select(0)


func _build() -> void:
	var root := Control.new()
	root.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(root)

	_map = MissionMap3D.new()
	root.add_child(_map)
	_map.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_map.set_missions(missions)

	# Верхняя полоса: «опасно», название, монеты, закрыть
	var top := VBoxContainer.new()
	top.add_theme_constant_override(&"separation", 0)
	root.add_child(top)
	top.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	top.offset_bottom = 110.0
	var stripe := HazardStripe.new()
	stripe.custom_minimum_size = Vector2(0.0, 14.0)
	top.add_child(stripe)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override(&"panel", UIKit.panel_style(Color(0.04, 0.035, 0.03, 1.0), 0, 14.0))
	top.add_child(bar)
	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 20)
	bar.add_child(header)
	var title := UIKit.label("КАРТА ЗАРАЖЕНИЯ", 40, header)
	title.modulate = RUST
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_coins_label = UIKit.label("МОНЕТЫ: %d" % GameState.coins, 28, header)
	_coins_label.modulate = UIKit.ACCENT
	_coins_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var close := UIKit.button("ЗАКРЫТЬ", 24, 200.0)
	close.pressed.connect(close_window)
	header.add_child(close)

	# Слева — список миссий
	var list_panel := PanelContainer.new()
	list_panel.add_theme_stylebox_override(&"panel", _rust_panel())
	root.add_child(list_panel)
	list_panel.set_anchors_and_offsets_preset(PRESET_LEFT_WIDE)
	list_panel.offset_left = 20.0
	list_panel.offset_top = 124.0
	list_panel.offset_right = 20.0 + LIST_WIDTH
	list_panel.offset_bottom = -20.0
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_panel.add_child(scroll)
	TouchScroll.attach(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", 10)
	scroll.add_child(list)
	for i in missions.size():
		list.add_child(_make_row(i))

	# Справа — досье миссии
	var dossier_panel := PanelContainer.new()
	dossier_panel.add_theme_stylebox_override(&"panel", _rust_panel())
	root.add_child(dossier_panel)
	dossier_panel.set_anchors_and_offsets_preset(PRESET_RIGHT_WIDE)
	dossier_panel.offset_left = -20.0 - DOSSIER_WIDTH
	dossier_panel.offset_top = 124.0
	dossier_panel.offset_right = -20.0
	dossier_panel.offset_bottom = -20.0
	var dossier_scroll := ScrollContainer.new()
	dossier_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dossier_panel.add_child(dossier_scroll)
	TouchScroll.attach(dossier_scroll)
	_dossier = VBoxContainer.new()
	_dossier.size_flags_horizontal = SIZE_EXPAND_FILL
	_dossier.add_theme_constant_override(&"separation", 12)
	dossier_scroll.add_child(_dossier)


func _make_row(index: int) -> Control:
	var mission: MissionData = missions[index]
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	row.add_child(MissionIcon.create(mission, 64.0))
	var button := UIKit.button(mission.title, 24)
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.pressed.connect(func() -> void: _select(index))
	row.add_child(button)
	_rows.append(button)
	return row


func _select(index: int) -> void:
	_selected = clampi(index, 0, missions.size() - 1)
	for i in _rows.size():
		_rows[i].modulate = RUST.lightened(0.2) if i == _selected else Color.WHITE
	_map.focus(_selected)
	_fill_dossier(missions[_selected])


func _fill_dossier(mission: MissionData) -> void:
	for child: Node in _dossier.get_children():
		child.queue_free()
	var color: Color = MissionIcon.color_for(mission)

	var stripe := HazardStripe.new()
	stripe.custom_minimum_size = Vector2(0.0, 10.0)
	_dossier.add_child(stripe)

	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 16)
	_dossier.add_child(head)
	head.add_child(MissionIcon.create(mission, 84.0))
	var head_texts := VBoxContainer.new()
	head_texts.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(head_texts)
	var level: int = GameState.get_mission_level(mission.id)
	var endless: bool = _is_endless(mission)
	var title_text: String = mission.title if level <= 1 or endless else "%s  •  УР. %d" % [mission.title, level]
	UIKit.label(title_text, 36, head_texts).modulate = color.lightened(0.25)
	UIKit.label("%s  •  %s" % [mission.get_type_name(), mission.get_location_name()], 22, head_texts).modulate = UIKit.DIM

	# «В БОЙ» сразу под названием — не нужно листать вниз
	_dossier.add_child(_make_go_button(mission))

	if not mission.description.is_empty():
		UIKit.label(mission.description, 22, _dossier)

	_fact("ЦЕЛЬ", mission.get_goal_text())
	_fact("ВРАГИ", _enemies_text(mission))
	var danger_row := HBoxContainer.new()
	danger_row.add_theme_constant_override(&"separation", 12)
	_dossier.add_child(danger_row)
	var danger_label := UIKit.label("ОПАСНОСТЬ", 22, danger_row)
	danger_label.modulate = RUST
	danger_label.custom_minimum_size = Vector2(150.0, 0.0)
	danger_row.add_child(DangerMeter.create(_danger(mission), MAX_DANGER))

	if endless:
		var reward: String = "за каждого убитого"
		if mission.type == MissionData.Type.ENDLESS:
			reward = "%d за волну + за убитых" % mission.coins_per_wave
		_fact("МОНЕТЫ", reward)
		if mission.type == MissionData.Type.ENDLESS:
			_fact("РЕКОРД", "%d волн" % GameState.get_best_score(mission.id))
	else:
		var coins: int = roundi(mission.reward_coins * GameState.get_reward_multiplier(mission.id))
		_fact("НАГРАДА", "%d монет + за убитых" % coins)
		if GameState.is_mission_completed(mission.id):
			_fact("РЕКОРД", "%d очков" % GameState.get_best_score(mission.id))
		var stars := StarRating.new()
		stars.star_radius = 22.0
		stars.size_flags_horizontal = SIZE_SHRINK_BEGIN
		stars.set_stars(GameState.get_mission_stars(mission.id))
		_dossier.add_child(stars)

	var bottom := HazardStripe.new()
	bottom.custom_minimum_size = Vector2(0.0, 10.0)
	_dossier.add_child(bottom)


func _make_go_button(mission: MissionData) -> Button:
	var go := UIKit.button("В БОЙ", 34)
	go.custom_minimum_size = Vector2(0.0, 92.0)
	UIKit.apply_3d_style(go)
	for state: StringName in [&"normal", &"hover", &"pressed"]:
		var box := go.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		if box != null:
			box.bg_color = Color(0.7, 0.18, 0.08) if state != &"pressed" else Color(0.55, 0.12, 0.05)
			box.border_color = Color(0.3, 0.06, 0.02)
			go.add_theme_stylebox_override(state, box)
	go.pressed.connect(func() -> void: GameState.start_mission(mission))
	return go


## Строка досье «ЗАГОЛОВОК  значение»
func _fact(title: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	_dossier.add_child(row)
	var key := UIKit.label(title, 22, row)
	key.modulate = RUST
	key.custom_minimum_size = Vector2(150.0, 0.0)
	key.autowrap_mode = TextServer.AUTOWRAP_OFF
	var text := UIKit.label(value, 22, row)
	text.size_flags_horizontal = SIZE_EXPAND_FILL


func _enemies_text(mission: MissionData) -> String:
	var names := PackedStringArray()
	for data: ZombieData in [mission.walker, mission.runner, mission.tank]:
		if data != null:
			names.append(data.display_name)
	for special: ZombieData in mission.specials:
		if special != null and not special.display_name in names:
			names.append(special.display_name)
	if mission.boss != null:
		names.append(mission.boss.display_name)
	return ", ".join(names)


## Опасность 1..5: тип, уровень повтора, босс
func _danger(mission: MissionData) -> int:
	var base: int = 2
	match mission.type:
		MissionData.Type.SURVIVE, MissionData.Type.DEFEND, MissionData.Type.FREE_ROAM:
			base = 3
		MissionData.Type.ENDLESS:
			base = 4
	if mission.boss != null and mission.type == MissionData.Type.WAVES:
		base = 5
	if not _is_endless(mission):
		base += GameState.get_mission_level(mission.id) - 1
	return clampi(base, 1, MAX_DANGER)


func _is_endless(mission: MissionData) -> bool:
	return mission.type == MissionData.Type.ENDLESS or mission.type == MissionData.Type.FREE_ROAM


func _rust_panel() -> StyleBoxFlat:
	var style := UIKit.panel_style(PANEL_BG, 6, 18.0)
	style.border_color = RUST.darkened(0.3)
	style.set_border_width_all(3)
	return style
