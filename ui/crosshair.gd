extends Label
## Прицел (рисуется, не текст): четыре черты расходятся по текущему разбросу оружия
## (бег, стрельба, прицеливание), краснеет при наведении на цель,
## при попадании — крестик и звук. Нода остаётся Label для совместимости со сценами.

const FLASH_TIME: float = 0.12
const LINE_LENGTH: float = 11.0
const LINE_WIDTH: float = 2.5
const OUTLINE_WIDTH: float = 5.0
const MIN_GAP: float = 4.0
const MAX_GAP: float = 90.0
const GAP_SMOOTH: float = 18.0
const DOT_RADIUS: float = 2.0
const OUTLINE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.55)
const DIRECTIONS: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]

@export var weapon_manager: WeaponManager
@export var normal_color: Color = Color(1, 1, 1, 0.85)
@export var target_color: Color = Color(1.0, 0.3, 0.3)
@export var hit_color: Color = Color(1, 1, 1)
@export var headshot_color: Color = Color(1.0, 0.8, 0.1)
@export var kill_color: Color = Color(1.0, 0.25, 0.2)
@export_range(-30.0, 6.0, 0.5) var hit_sound_volume_db: float = -8.0

var _flash: float = 0.0
var _flash_color: Color = Color.WHITE
var _hit_marker: HitMarker
var _headshot_popup: HeadshotPopup
var _scope: ScopeOverlay
var _gap: float = MIN_GAP
var _melee: bool = false


func _ready() -> void:
	text = ""
	custom_minimum_size = Vector2(4.0, 4.0)
	_hit_marker = HitMarker.new()
	add_child(_hit_marker)
	resized.connect(_update_pivot)
	_update_pivot()
	_connect_manager.call_deferred()


func _connect_manager() -> void:
	if weapon_manager == null:
		weapon_manager = get_tree().get_first_node_in_group(&"weapon_manager") as WeaponManager
	if weapon_manager == null:
		push_warning("Crosshair: WeaponManager не найден")
		return
	weapon_manager.hit_landed.connect(_on_hit_landed)
	# «ХЕДШОТ!» и оптика — прямо в слое HUD (прицел лежит в CenterContainer, тот задал бы им размер)
	var layer: Node = _find_hud_layer()
	if layer != null:
		_headshot_popup = HeadshotPopup.new()
		layer.add_child(_headshot_popup)
		# Оптика снайперской — под всеми кнопками HUD
		_scope = ScopeOverlay.new()
		_scope.weapon_manager = weapon_manager
		layer.add_child(_scope)
		layer.move_child(_scope, 0)
	weapon_manager.weapon_changed.connect(_on_weapon_changed)
	var weapon: WeaponData = weapon_manager.get_current_weapon()
	_melee = weapon != null and weapon.is_melee


func _process(delta: float) -> void:
	if weapon_manager == null:
		return
	# В оптике свой прицел — обычный прячем
	var scoped: bool = weapon_manager.is_scoped()
	if visible == scoped:
		visible = not scoped
	_flash = maxf(_flash - delta, 0.0)
	if _flash > 0.0:
		modulate = _flash_color
		scale = Vector2.ONE * (1.0 + _flash * 4.0)
	else:
		modulate = target_color if weapon_manager.is_target_in_sight() else _normal_color()
		scale = Vector2.ONE
	var target_gap: float = clampf(_spread_to_pixels(weapon_manager.get_current_spread()), MIN_GAP, MAX_GAP)
	_gap = lerpf(_gap, target_gap, clampf(GAP_SMOOTH * delta, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	# Размер из настроек: длина и толщина черт, точка (зазор — по разбросу оружия)
	var k: float = Settings.crosshair_scale
	var center: Vector2 = size * 0.5
	draw_circle(center, (DOT_RADIUS + 1.5) * k, OUTLINE_COLOR)
	draw_circle(center, DOT_RADIUS * k, Color.WHITE)
	if _melee:
		return  # у ближнего боя только точка
	var gap: float = maxf(_gap, MIN_GAP * k)
	for dir: Vector2 in DIRECTIONS:
		var from: Vector2 = center + dir * gap
		var to: Vector2 = center + dir * (gap + LINE_LENGTH * k)
		draw_line(from - dir, to + dir, OUTLINE_COLOR, OUTLINE_WIDTH * k)
		draw_line(from, to, Color.WHITE, LINE_WIDTH * k)


## Цвет прицела: из настроек игрока (белый по умолчанию — normal_color сцены)
func _normal_color() -> Color:
	if Settings.crosshair_color <= 0:
		return normal_color
	return Settings.CROSSHAIR_COLORS[Settings.crosshair_color]


## Угол разброса → пиксели на экране с учётом текущего FOV камеры
func _spread_to_pixels(spread_degrees: float) -> float:
	var camera: Camera3D = weapon_manager.camera
	if camera == null:
		return MIN_GAP
	var half_fov: float = deg_to_rad(camera.fov * 0.5)
	var screen_half: float = get_viewport_rect().size.y * 0.5
	return tan(deg_to_rad(spread_degrees)) / maxf(tan(half_fov), 0.01) * screen_half


func _on_weapon_changed(weapon: WeaponData) -> void:
	_melee = weapon != null and weapon.is_melee


func _find_hud_layer() -> Node:
	var node: Node = get_parent()
	while node != null and not node is CanvasLayer:
		node = node.get_parent()
	return node


func _on_hit_landed(is_headshot: bool, killed: bool) -> void:
	_flash = FLASH_TIME * (1.6 if killed else 1.0)
	_flash_color = headshot_color if is_headshot else hit_color
	var marker_color: Color = kill_color if killed else _flash_color
	_hit_marker.show_hit(marker_color, killed)
	Sfx.play_2d(Sfx.sounds.hitmarker, hit_sound_volume_db, 1.25 if killed else 1.0, 0.03)
	if is_headshot and killed and _headshot_popup != null:
		_headshot_popup.show_headshot()


func _update_pivot() -> void:
	pivot_offset = size * 0.5
	if _hit_marker != null:
		_hit_marker.position = size * 0.5
