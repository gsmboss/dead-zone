extends ColorRect
## Красная вспышка при уроне и экран смерти.
## Если в уровне есть MissionManager, итог показывает HUD миссии,
## а здесь только красное затемнение без перезапуска.

const DEATH_ALPHA: float = 0.55

@export_range(0.0, 1.0, 0.05) var flash_alpha: float = 0.35
@export var fade_speed: float = 2.5
@export var restart_delay: float = 3.0
@export var death_text: String = "ВЫ ПОГИБЛИ"

var _alpha: float = 0.0
var _dead: bool = false
var _death_label: Label


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	color = Color(0.8, 0.0, 0.0, 0.0)

	_death_label = Label.new()
	_death_label.mouse_filter = MOUSE_FILTER_IGNORE
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death_label.add_theme_font_size_override(&"font_size", 56)
	_death_label.visible = false
	add_child(_death_label)
	_death_label.set_anchors_preset(PRESET_FULL_RECT)

	_connect_player.call_deferred()


func _connect_player() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or player.health == null:
		push_warning("DamageOverlay: игрок или его Health не найдены")
		return
	player.health.damaged.connect(_on_damaged)
	player.health.died.connect(_on_died)


func _process(delta: float) -> void:
	if _dead or _alpha <= 0.0:
		return
	_alpha = maxf(_alpha - fade_speed * delta, 0.0)
	color.a = _alpha


func _on_damaged(_amount: float, _hit_position: Vector3, _is_headshot: bool) -> void:
	if _dead:
		return
	_alpha = flash_alpha
	color.a = _alpha


func _on_died() -> void:
	_dead = true
	var tween := create_tween()
	tween.tween_property(self, "color:a", DEATH_ALPHA, 0.8)

	# В миссии итог и перезапуск показывает HUD миссии
	if get_tree().get_first_node_in_group(&"mission_manager") != null:
		return

	_death_label.text = death_text
	_death_label.visible = true
	await get_tree().create_timer(restart_delay).timeout
	if is_inside_tree():
		get_tree().reload_current_scene()
