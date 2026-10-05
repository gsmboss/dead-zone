class_name MissionBoardPanel
extends HubWindow
## Доска миссий: описание, награда, рекорд, кнопка «НАЧАТЬ».

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

	UIKit.label(mission.title, 32, box)
	if not mission.description.is_empty():
		UIKit.label(mission.description, 22, box).modulate = UIKit.DIM

	var info := "Награда: %d монет" % mission.reward_coins
	if GameState.is_mission_completed(mission.id):
		info += "  •  ПРОЙДЕНА, рекорд %d очков" % GameState.get_best_score(mission.id)
	var info_label := UIKit.label(info, 22, box)
	info_label.modulate = UIKit.GOOD if GameState.is_mission_completed(mission.id) else UIKit.ACCENT

	var start := UIKit.button("НАЧАТЬ", 28)
	start.pressed.connect(func() -> void: GameState.start_mission(mission))
	box.add_child(start)
	return card
