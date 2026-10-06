class_name MatchHUD
extends Control
## Интерфейс матча по сети (создаётся MatchManager): режим и таймер сверху, табло игроков
## справа, лента убийств, объявления, отсчёт до возрождения и окно итогов.

const FEED_TIME: float = 5.0
const FEED_MAX: int = 5
const ANNOUNCE_TIME: float = 2.5

var _match: MatchManager
var _top: Label
var _scores_box: VBoxContainer
var _feed_box: VBoxContainer
var _announce: Label
var _respawn: Label
var _results: PanelContainer
var _attacker: Label
var _attacker_left: float = 0.0
var _waiting_time: float = 0.0
var _leave_button: Button
var _announce_left: float = 0.0
var _feed_times: Array[float] = []
var _last_second: int = -1


func setup(match_manager: MatchManager) -> void:
	_match = match_manager
	refresh_scores()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_top = UIKit.label("", 26, self)
	_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	_top.offset_left = -300.0
	_top.offset_right = 300.0
	_top.offset_top = 12.0
	_top.offset_bottom = 50.0
	_top.modulate = UIKit.ACCENT

	var panel := PanelContainer.new()
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(&"panel", UIKit.panel_style(Color(0.0, 0.0, 0.0, 0.4), 8, 10.0))
	add_child(panel)
	panel.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	panel.offset_left = -330.0
	panel.offset_right = -16.0
	panel.offset_top = 230.0
	panel.offset_bottom = 230.0
	panel.grow_vertical = GROW_DIRECTION_END
	_scores_box = VBoxContainer.new()
	_scores_box.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(_scores_box)

	_feed_box = VBoxContainer.new()
	_feed_box.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_feed_box)
	_feed_box.set_anchors_and_offsets_preset(PRESET_TOP_LEFT)
	_feed_box.offset_left = 24.0
	_feed_box.offset_top = 330.0
	_feed_box.offset_right = 520.0

	_announce = UIKit.label("", 44, self)
	_announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce.set_anchors_and_offsets_preset(PRESET_CENTER)
	_announce.offset_left = -500.0
	_announce.offset_right = 500.0
	_announce.offset_top = -200.0
	_announce.offset_bottom = -130.0
	_announce.modulate = UIKit.ACCENT

	_attacker = UIKit.label("", 28, self)
	_attacker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attacker.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	_attacker.offset_left = -400.0
	_attacker.offset_right = 400.0
	_attacker.offset_top = 56.0
	_attacker.offset_bottom = 96.0
	_attacker.modulate = MatchManager.ATTACKER_COLOR

	# Если старт не приходит — можно уйти (не застрять на экране ожидания)
	_leave_button = UIKit.button("В УБЕЖИЩЕ", 26, 300.0)
	_leave_button.visible = false
	_leave_button.pressed.connect(func() -> void:
		Net.leave()
		Net.return_to_lobby())
	add_child(_leave_button)
	_leave_button.set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM, PRESET_MODE_MINSIZE)
	_leave_button.offset_top -= 140.0
	_leave_button.offset_bottom -= 140.0
	_leave_button.grow_horizontal = GROW_DIRECTION_BOTH

	_respawn = UIKit.label("", 34, self)
	_respawn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_respawn.set_anchors_and_offsets_preset(PRESET_CENTER)
	_respawn.offset_left = -400.0
	_respawn.offset_right = 400.0
	_respawn.offset_top = -40.0
	_respawn.offset_bottom = 20.0


func _process(delta: float) -> void:
	if _match == null:
		return
	# Таймер обновляем раз в секунду (без строк в каждом кадре)
	var seconds: int = ceili(_match.get_time_left())
	if seconds != _last_second:
		_last_second = seconds
		var mode_name: String = Net.MODE_NAMES[_match.get_mode()]
		_top.text = mode_name if _match.get_mode() == Net.Mode.LAST_STANDING \
			else "%s  •  %s" % [mode_name, MissionManager.format_time(seconds)]
	if _announce_left > 0.0:
		_announce_left -= delta
		_announce.modulate.a = clampf(_announce_left / 0.5, 0.0, 1.0)
	if _attacker_left > 0.0:
		_attacker_left -= delta
		_attacker.modulate.a = clampf(_attacker_left / 0.5, 0.0, 1.0)
	if _match.is_waiting():
		_waiting_time += delta
		_respawn.text = "ЖДЁМ ИГРОКОВ…  %d" % floori(_waiting_time)
		# Долго нет старта — даём выйти
		_leave_button.visible = _waiting_time > MatchManager.LOAD_TIMEOUT + 5.0
		return
	_leave_button.visible = false
	var respawn_left: float = _match.get_respawn_left()
	_respawn.text = "ВОЗРОЖДЕНИЕ ЧЕРЕЗ %d" % ceili(respawn_left) if respawn_left > 0.0 else ""
	for i in range(_feed_times.size() - 1, -1, -1):
		_feed_times[i] -= delta
		if _feed_times[i] <= 0.0 and i < _feed_box.get_child_count():
			_feed_box.get_child(i).queue_free()
			_feed_times.remove_at(i)


func announce(text: String) -> void:
	if _announce == null:
		return
	_announce.text = text
	_announce_left = ANNOUNCE_TIME
	_announce.modulate.a = 1.0


## «В ВАС СТРЕЛЯЕТ: ИМЯ» под таймером
func show_attacker(attacker_name: String) -> void:
	if _attacker == null:
		return
	_attacker.text = "▼ В ВАС СТРЕЛЯЕТ: %s" % attacker_name
	_attacker_left = 2.5
	_attacker.modulate.a = 1.0


func feed(text: String) -> void:
	if _feed_box == null:
		return
	if _feed_box.get_child_count() >= FEED_MAX:
		_feed_box.get_child(0).queue_free()
		_feed_times.remove_at(0)
	var line := UIKit.label(text, 22, _feed_box)
	line.modulate = Color(1.0, 0.85, 0.75)
	_feed_times.append(FEED_TIME)


func refresh_scores() -> void:
	if _scores_box == null or _match == null:
		return
	for child: Node in _scores_box.get_children():
		child.queue_free()
	var scores: Dictionary = _match.get_scores()
	if Net.match_mode == Net.Mode.TEAMS:
		var team_line := UIKit.label("СИНИЕ %d : %d КРАСНЫЕ" % [_team_total(scores, 0), _team_total(scores, 1)],
			22, _scores_box)
		team_line.modulate = UIKit.ACCENT
	for peer_id: int in _sorted(scores):
		var entry: Dictionary = scores[peer_id]
		var text: String = "%s  %d" % [Net.get_player_name(peer_id), int(entry["score"])]
		if Net.match_mode == Net.Mode.LAST_STANDING and not bool(entry["alive"]):
			text += "  ✝"
		var line := UIKit.label(text, 22, _scores_box)
		line.modulate = _match.color_for(peer_id)


func show_results(winner_text: String, won: bool, coins: int) -> void:
	if _results != null:
		return
	_results = PanelContainer.new()
	_results.add_theme_stylebox_override(&"panel", UIKit.panel_style())
	add_child(_results)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	_results.add_child(box)
	var title := UIKit.label("ПОБЕДА!" if won else "МАТЧ ОКОНЧЕН", 48, box)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = UIKit.GOOD if won else UIKit.ACCENT
	UIKit.label(winner_text, 30, box).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var scores: Dictionary = _match.get_scores()
	UIKit.label("ИГРОК — ОЧКИ / ЗОМБИ / ИГРОКИ / СМЕРТИ", 20, box).modulate = UIKit.DIM
	for peer_id: int in _sorted(scores):
		var entry: Dictionary = scores[peer_id]
		var line := UIKit.label("%s — %d / %d / %d / %d" % [Net.get_player_name(peer_id), int(entry["score"]),
			int(entry["zkills"]), int(entry["kills"]), int(entry["deaths"])], 24, box)
		line.modulate = _match.color_for(peer_id)
	var reward := UIKit.label("+%d МОНЕТ" % coins, 30, box)
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward.modulate = UIKit.ACCENT
	var back := UIKit.button("В ЛОББИ", 30, 380.0)
	back.pressed.connect(Net.return_to_lobby)
	box.add_child(back)
	_results.set_anchors_and_offsets_preset(PRESET_CENTER, PRESET_MODE_MINSIZE)
	_results.grow_horizontal = GROW_DIRECTION_BOTH
	_results.grow_vertical = GROW_DIRECTION_BOTH
	_respawn.text = ""


func _sorted(scores: Dictionary) -> Array:
	var ids: Array = scores.keys()
	ids.sort_custom(func(a: int, b: int) -> bool:
		return int(scores[a]["score"]) > int(scores[b]["score"]))
	return ids


func _team_total(scores: Dictionary, team: int) -> int:
	var total: int = 0
	for peer_id: int in scores:
		if Net.get_team(peer_id) == team:
			total += int(scores[peer_id]["kills"])
	return total
