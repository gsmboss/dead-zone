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
var _death_tween: Tween
var _health: Health


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

	# Индикатор направления урона поверх красной вспышки
	add_child(DamageIndicator.new())

	_connect_player.call_deferred()


func _connect_player() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or player.health == null:
		push_warning("DamageOverlay: игрок или его Health не найдены")
		return
	_health = player.health
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	# Воскрешение (реклама) и возрождение по сети: health.reset() — снимаем затемнение
	_health.health_changed.connect(_on_health_changed)


func _process(delta: float) -> void:
	if _dead or _alpha <= 0.0:
		return
	_alpha = maxf(_alpha - fade_speed * delta, 0.0)
	color.a = _alpha


func _on_damaged(amount: float, _hit_position: Vector3, _is_headshot: bool) -> void:
	if _dead:
		return
	# Сильнее удар — ярче вспышка; яркость — из настроек
	var strength: float = clampf(0.6 + amount / 40.0, 0.6, 1.3)
	_alpha = maxf(_alpha, flash_alpha * strength * Settings.damage_flash)
	color.a = _alpha


func _on_health_changed(_current: float, _max_value: float) -> void:
	if not _dead or _health == null or _health.is_dead:
		return
	_dead = false
	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()
	_alpha = 0.0
	color.a = 0.0
	_death_label.visible = false


func _on_died() -> void:
	_dead = true
	_death_tween = create_tween()
	_death_tween.tween_property(self, "color:a", DEATH_ALPHA, 0.8)

	# В миссии итог и перезапуск показывает HUD миссии
	if get_tree().get_first_node_in_group(&"mission_manager") != null:
		return

	_death_label.text = death_text
	_death_label.visible = true
	await get_tree().create_timer(restart_delay).timeout
	if is_inside_tree():
		get_tree().reload_current_scene()
