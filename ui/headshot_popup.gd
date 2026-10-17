class_name HeadshotPopup
extends Control
## «ХЕДШОТ!» над прицелом при убийстве в голову: рисованный череп, надпись, впрыгивание с
## покачиванием и затухание; серия хедшотов подряд — «ХЕДШОТ ×N». Короткое замедление времени
## (не по сети и не в кат-сцене; можно выключить в настройках). Создаёт Crosshair.

const SHOW_TIME: float = 1.1
const COMBO_TIME: float = 3.0
const SLOWMO_SCALE: float = 0.35
const SLOWMO_TIME: float = 0.14
const GOLD: Color = Color(1.0, 0.82, 0.2)

var _label: Label
var _skull: SkullIcon
var _combo: int = 0
var _combo_left: float = 0.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_CENTER)
	offset_left = -220.0
	offset_right = 220.0
	offset_top = -190.0
	offset_bottom = -90.0
	pivot_offset = Vector2(220.0, 50.0)
	var row := HBoxContainer.new()
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 10)
	add_child(row)
	row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_skull = SkullIcon.new()
	row.add_child(_skull)
	_label = UIKit.label("", 44, row)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.modulate = GOLD
	modulate.a = 0.0
	visible = false


func _process(delta: float) -> void:
	if _combo_left > 0.0:
		_combo_left -= delta
		if _combo_left <= 0.0:
			_combo = 0


func show_headshot() -> void:
	_combo = _combo + 1 if _combo_left > 0.0 else 1
	_combo_left = COMBO_TIME
	_label.text = "ХЕДШОТ!" if _combo <= 1 else UIKit.t("ХЕДШОТ ×%d") % _combo
	visible = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 1.0
	scale = Vector2.ONE * 0.4
	rotation = deg_to_rad(-8.0)
	# Анимация в реальном времени — даже при замедлении
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_property(self, "scale", Vector2.ONE * 1.25, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "rotation", deg_to_rad(4.0), 0.12)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.1)
	_tween.parallel().tween_property(self, "rotation", 0.0, 0.1)
	_tween.tween_interval(SHOW_TIME * 0.5)
	_tween.tween_property(self, "modulate:a", 0.0, SHOW_TIME * 0.4)
	_tween.tween_callback(func() -> void: visible = false)
	Sfx.play_2d(Sfx.sounds.ui_confirm, -2.0, 1.5 + 0.1 * mini(_combo, 5), 0.0)
	_slow_motion()


## Миг замедления — «смак» хедшота
func _slow_motion() -> void:
	if not Settings.headshot_slowmo or Net.in_match or CutscenePlayer.active or Engine.time_scale < 0.99:
		return
	Engine.time_scale = SLOWMO_SCALE
	get_tree().create_timer(SLOWMO_TIME, true, false, true).timeout.connect(func() -> void:
		if not CutscenePlayer.active:
			Engine.time_scale = 1.0)


## Рисованный череп (без текстур)
class SkullIcon:
	extends Control

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(56.0, 64.0)

	func _draw() -> void:
		var c: Vector2 = size * 0.5 + Vector2(0.0, -4.0)
		var bone: Color = Color(1.0, 0.95, 0.85)
		var dark: Color = Color(0.08, 0.05, 0.05)
		draw_circle(c, 24.0, Color(0.0, 0.0, 0.0, 0.5))
		draw_circle(c, 21.0, bone)
		draw_rect(Rect2(c + Vector2(-12.0, 12.0), Vector2(24.0, 14.0)), bone)
		draw_circle(c + Vector2(-8.0, 2.0), 6.0, dark)
		draw_circle(c + Vector2(8.0, 2.0), 6.0, dark)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, 8.0), c + Vector2(-3.5, 14.0),
			c + Vector2(3.5, 14.0)]), dark)
		for i in 3:
			var x: float = -7.0 + i * 7.0
			draw_line(c + Vector2(x, 18.0), c + Vector2(x, 26.0), dark, 2.0)
