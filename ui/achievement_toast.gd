class_name AchievementToast
extends CanvasLayer
## Плашка «ДОСТИЖЕНИЕ!» сверху экрана: выезжает, держится, уезжает. Несколько подряд — по очереди.
## Создаётся GameState при открытии достижения: AchievementToast.show_achievement(tree, achievement).

const SHOW_TIME: float = 3.2
const SLIDE_TIME: float = 0.35
const WIDTH: float = 560.0

static var _queue: Array[AchievementData] = []
static var _current: AchievementToast

var achievement: AchievementData
var _panel: PanelContainer


static func show_achievement(tree: SceneTree, data: AchievementData) -> void:
	if tree == null or tree.root == null or data == null:
		return
	if _current != null and is_instance_valid(_current):
		_queue.append(data)
		return
	var toast := AchievementToast.new()
	toast.achievement = data
	_current = toast
	tree.root.add_child.call_deferred(toast)


func _ready() -> void:
	layer = 95
	process_mode = PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override(&"panel", UIKit.panel_style(Color(0.08, 0.07, 0.04, 0.95), 16, 14.0))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.offset_left = -WIDTH * 0.5
	_panel.offset_right = WIDTH * 0.5
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)
	var medal := AchievementBadge.new()
	medal.color = achievement.icon_color
	medal.custom_minimum_size = Vector2(64.0, 64.0)
	row.add_child(medal)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	UIKit.label("ДОСТИЖЕНИЕ!", 18, texts).modulate = UIKit.ACCENT
	UIKit.label(achievement.title, 26, texts)
	var reward := UIKit.label("+" + UIKit.coins_text(achievement.reward), 26, row)
	reward.modulate = UIKit.GOOD
	reward.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Sfx.play_2d(Sfx.sounds.purchase, -2.0, 1.15, 0.0)
	# Выезд сверху → пауза → обратно
	_panel.offset_top = -120.0
	_panel.offset_bottom = -20.0
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(_panel, "offset_top", 16.0, SLIDE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_panel, "offset_bottom", 116.0, SLIDE_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(SHOW_TIME)
	tween.tween_property(_panel, "offset_top", -120.0, SLIDE_TIME)
	tween.parallel().tween_property(_panel, "offset_bottom", -20.0, SLIDE_TIME)
	tween.tween_callback(_next)


func _next() -> void:
	_current = null
	if not _queue.is_empty() and get_tree() != null:
		show_achievement(get_tree(), _queue.pop_front())
	queue_free()
