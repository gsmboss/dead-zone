class_name MissionBoardPanel
extends HubWindow
## Доска миссий: описание, уровень, награда, звёзды, рекорд, кнопка «НАЧАТЬ».

var missions: Array[MissionData] = []


func _ready() -> void:
	window_title = "МИССИИ"
	super._ready()


func _build_content() -> void:
	var has_any: bool = false
	for mission: MissionData in missions:
		if mission == null:
			continue
		has_any = true
		content.add_child(_make_mission_card(mission))
	if not has_any:
		UIKit.label("Нет доступных миссий", 26, content).modulate = UIKit.DIM


func _make_mission_card(mission: MissionData) -> Control:
	var card := UIKit.card()
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	card.add_child(box)

	var level: int = GameState.get_mission_level(mission.id)
	UIKit.label(mission.title if level <= 1 else "%s  •  УРОВЕНЬ %d" % [mission.title, level], 32, box)
	if not mission.description.is_empty():
		UIKit.label(mission.description, 22, box).modulate = UIKit.DIM

	var reward: int = roundi(mission.reward_coins * GameState.get_reward_multiplier(mission.id))
	var info := "Награда: %d монет" % reward
	if GameState.is_mission_completed(mission.id):
		info += "  •  рекорд %d очков" % GameState.get_best_score(mission.id)
	var info_label := UIKit.label(info, 22, box)
	info_label.modulate = UIKit.GOOD if GameState.is_mission_completed(mission.id) else UIKit.ACCENT
	if GameState.is_mission_completed(mission.id):
		var stars := StarRating.new()
		stars.star_radius = 18.0
		stars.size_flags_horizontal = SIZE_SHRINK_BEGIN
		stars.set_stars(GameState.get_mission_stars(mission.id))
		box.add_child(stars)

	var start := UIKit.button("НАЧАТЬ", 28)
	start.pressed.connect(func() -> void: GameState.start_mission(mission))
	box.add_child(start)
	return card
