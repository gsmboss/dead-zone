class_name RaceDirector
extends Node3D
## Заезды по городу (открытый мир, одиночная игра). Старт — флаг «ЗАЕЗДЫ» на перекрёстке у своей машины:
## подъехать и остановиться → выбрать трассу (СПРИНТ, КРУГ ПО ГОРОДУ, МАРАФОН). Обратный отсчёт,
## чекпоинты-кольца по перекрёсткам, стрелка над машиной, таймер. Финиш — медаль по времени и монеты,
## лучшее время — GameState.get_race_best. Выйти из машины — заезд отменён.
## Ставит CityGenerator (lines — координаты дорог сетки, start_point — у своей машины).

## Трасса: id, название, число чекпоинтов
const ROUTES: Array[Dictionary] = [
	{"id": "sprint", "title": "СПРИНТ", "points": 7},
	{"id": "circuit", "title": "КРУГ ПО ГОРОДУ", "points": 12},
	{"id": "marathon", "title": "МАРАФОН", "points": 18},
]
## Награды: золото, серебро, бронза, просто доехал
const REWARDS: Array[int] = [300, 180, 100, 40]
const MEDALS: PackedStringArray = ["ЗОЛОТО", "СЕРЕБРО", "БРОНЗА", "ФИНИШ"]
const MEDAL_COLORS: Array[Color] = [Color(1.0, 0.82, 0.25), Color(0.85, 0.88, 0.92), Color(0.85, 0.55, 0.3),
	Color(0.8, 0.8, 0.8)]
## Время на медаль: длина трассы / скорость (м/с), дальше × множитель
const PAR_SPEED: float = 17.0
const MEDAL_FACTORS: Array[float] = [1.0, 1.25, 1.55]
const CHECK_INTERVAL: float = 0.2
const START_RADIUS: float = 7.0
const START_MAX_SPEED: float = 4.0
const CHECKPOINT_RADIUS: float = 9.0
const COUNTDOWN: float = 3.0
const RING_COLOR: Color = Color(1.0, 0.8, 0.15)
const NEXT_RING_COLOR: Color = Color(0.4, 0.8, 1.0)

## Координаты дорог сетки по X и Z (CityGenerator._lines), их полуширины и точка старта
var lines: Array[float] = []
var half_widths: Array[float] = []
var start_point: Vector3 = Vector3.ZERO
var route_seed: int = 1337

var _car: DrivableCar
var _check_left: float = 0.0
var _route: int = -1
var _points: Array[Vector3] = []
var _index: int = 0
var _time: float = 0.0
var _countdown: float = 0.0
var _racing: bool = false
var _length: float = 0.0

var _layer: CanvasLayer
var _offer: PanelContainer
var _hud: Label
var _big: Label
var _ring: Node3D
var _next_ring: Node3D
var _arrow: Node3D
var _ring_material: StandardMaterial3D
var _next_material: StandardMaterial3D


func _ready() -> void:
	if lines.size() < 3:
		push_warning("RaceDirector '%s': мало дорог для трасс" % name)
		set_process(false)
		return
	start_point = _nearest_crossing(start_point)
	_build_start()
	_build_markers()
	_build_ui()


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = CHECK_INTERVAL
		_find_car()
		if not _racing and _countdown <= 0.0:
			_update_offer()
	if _countdown > 0.0:
		_process_countdown(delta)
	elif _racing:
		_process_race(delta)


# ---------- Старт ----------

## Своя машина, за рулём которой игрок (иначе null)
func _find_car() -> void:
	_car = null
	for node: Node in get_tree().get_nodes_in_group(DrivableCar.GROUP):
		var car := node as DrivableCar
		if car != null and car.is_driven():
			_car = car
			return
	if _racing or _countdown > 0.0:
		_cancel("ЗАЕЗД ОТМЕНЁН")


func _update_offer() -> void:
	var near: bool = _car != null and _flat_distance(_car.global_position, start_point) <= START_RADIUS \
		and absf(_car.speed) <= START_MAX_SPEED
	if _offer.visible != near:
		_offer.visible = near
		if near:
			_fill_offer()


func _fill_offer() -> void:
	var box := _offer.get_child(0) as VBoxContainer
	for child: Node in box.get_children():
		child.queue_free()
	var title := UIKit.label("ЗАЕЗДЫ", 30, box)
	title.modulate = UIKit.ACCENT
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in ROUTES.size():
		var route: Dictionary = ROUTES[i]
		var best: float = GameState.get_race_best(str(route["id"]))
		var text: String = "%s • %d" % [UIKit.t(str(route["title"])), int(route["points"])]
		if best > 0.0:
			text += "  ★ " + _format_time(best)
		var button := UIKit.button(text, 22, 360.0)
		button.pressed.connect(_start.bind(i))
		box.add_child(button)


func _start(route: int) -> void:
	if _car == null:
		return
	_route = route
	_points = _make_route(route)
	_length = 0.0
	var previous: Vector3 = start_point
	for point: Vector3 in _points:
		_length += previous.distance_to(point)
		previous = point
	_index = 0
	_time = 0.0
	_countdown = COUNTDOWN
	_offer.visible = false
	_show_rings()
	Sfx.play_2d(Sfx.sounds.ui_confirm, -2.0, 1.0, 0.0)


func _process_countdown(delta: float) -> void:
	var before: int = ceili(_countdown)
	_countdown -= delta
	var now: int = ceili(_countdown)
	_big.visible = true
	if _countdown <= 0.0:
		_racing = true
		_big.text = UIKit.t("ВПЕРЁД!")
		_big.modulate = UIKit.GOOD
		Sfx.play_2d(Sfx.sounds.ui_confirm, 0.0, 1.4, 0.0)
		get_tree().create_timer(0.8).timeout.connect(func() -> void:
			if _racing:
				_big.visible = false)
	elif now != before:
		_big.text = str(now)
		_big.modulate = Color.WHITE
		Sfx.play_2d(Sfx.sounds.ui_click, 0.0, 0.8, 0.0)
	_update_hud()


# ---------- Заезд ----------

func _process_race(delta: float) -> void:
	_time += delta
	if _car == null:
		return
	if _flat_distance(_car.global_position, _points[_index]) <= CHECKPOINT_RADIUS:
		_index += 1
		if _index >= _points.size():
			_finish()
			return
		Sfx.play_2d(Sfx.sounds.ui_confirm, -4.0, 1.2, 0.0)
		_show_rings()
	_update_arrow()
	_update_hud()


func _finish() -> void:
	_racing = false
	_hide_markers()
	var par: float = _length / PAR_SPEED
	var medal: int = MEDAL_FACTORS.size()
	for i in MEDAL_FACTORS.size():
		if _time <= par * MEDAL_FACTORS[i]:
			medal = i
			break
	var route_id: String = str(ROUTES[_route]["id"])
	var record: bool = GameState.record_race(route_id, _time)
	var coins: int = REWARDS[medal]
	GameState.add_coins(coins)
	_big.visible = true
	_big.modulate = MEDAL_COLORS[medal]
	_big.text = "%s\n%s  +%d%s" % [UIKit.t(MEDALS[medal]), _format_time(_time), coins,
		("\n" + UIKit.t("НОВЫЙ РЕКОРД!")) if record else ""]
	Sfx.play_2d(Sfx.sounds.purchase, 0.0, 1.0, 0.0)
	_hud.visible = false
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if not _racing and _countdown <= 0.0:
			_big.visible = false)


func _cancel(message: String) -> void:
	_racing = false
	_countdown = 0.0
	_hide_markers()
	_hud.visible = false
	_big.visible = true
	_big.modulate = Color(1.0, 0.5, 0.4)
	_big.text = UIKit.t(message)
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if not _racing and _countdown <= 0.0:
			_big.visible = false)


## Трасса — случайная прогулка по перекрёсткам сетки (одна и та же для id: своё зерно)
func _make_route(route: int) -> Array[Vector3]:
	var rng := RandomNumberGenerator.new()
	rng.seed = route_seed + route * 7919
	var count: int = int(ROUTES[route]["points"])
	var cell := Vector2i(_nearest_index(start_point.x), _nearest_index(start_point.z))
	var last_dir := Vector2i.ZERO
	var result: Array[Vector3] = []
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var visited: Dictionary = {cell: true}
	while result.size() < count:
		var options: Array[Vector2i] = []
		for dir: Vector2i in directions:
			if dir == -last_dir:
				continue
			var next: Vector2i = cell + dir
			if next.x < 0 or next.y < 0 or next.x >= lines.size() or next.y >= lines.size():
				continue
			options.append(dir)
		if options.is_empty():
			options.append(-last_dir)
		# Сначала — туда, где ещё не были
		var fresh: Array[Vector2i] = []
		for dir: Vector2i in options:
			if not visited.has(cell + dir):
				fresh.append(dir)
		var pool: Array[Vector2i] = fresh if not fresh.is_empty() else options
		var dir_pick: Vector2i = pool[rng.randi() % pool.size()]
		# По прямой 1–2 квартала, чекпоинт — на перекрёстке
		var steps: int = rng.randi_range(1, 2)
		for k in steps:
			var ahead: Vector2i = cell + dir_pick
			if ahead.x < 0 or ahead.y < 0 or ahead.x >= lines.size() or ahead.y >= lines.size():
				break
			cell = ahead
		visited[cell] = true
		last_dir = dir_pick
		result.append(Vector3(lines[cell.x], 0.0, lines[cell.y]))
	return result


# ---------- Метки ----------

func _build_start() -> void:
	var flag := Node3D.new()
	flag.name = "RaceStart"
	add_child(flag)
	# Флаг — на углу перекрёстка, за краем дороги
	var index_x: int = _nearest_index(start_point.x)
	var index_z: int = _nearest_index(start_point.z)
	var off_x: float = (half_widths[index_x] if index_x < half_widths.size() else 4.0) + 1.5
	var off_z: float = (half_widths[index_z] if index_z < half_widths.size() else 4.0) + 1.5
	flag.position = start_point + Vector3(off_x, 0.0, off_z)
	var pole_material := StandardMaterial3D.new()
	pole_material.albedo_color = Color(0.85, 0.85, 0.85)
	var pole := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.08
	cylinder.bottom_radius = 0.1
	cylinder.height = 5.0
	cylinder.material = pole_material
	pole.mesh = cylinder
	pole.position.y = 2.5
	flag.add_child(pole)
	# Клетчатый флаг: 4×3 клетки
	var white := StandardMaterial3D.new()
	white.albedo_color = Color.WHITE
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.05, 0.05, 0.05)
	for row in 3:
		for column in 4:
			var cell := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.4, 0.35, 0.03)
			box.material = white if (row + column) % 2 == 0 else black
			cell.mesh = box
			cell.position = Vector3(0.3 + column * 0.4, 4.6 - row * 0.35, 0.0)
			flag.add_child(cell)
	var label := Label3D.new()
	label.text = "ЗАЕЗДЫ"
	label.font_size = 72
	label.outline_size = 18
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.85, 0.3)
	label.position = Vector3(0.0, 5.8, 0.0)
	flag.add_child(label)
	# Круг на асфальте — сюда подъехать
	var spot := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = START_RADIUS * 0.8
	disc.bottom_radius = START_RADIUS * 0.8
	disc.height = 0.02
	disc.radial_segments = 32
	disc.rings = 1
	var spot_material := StandardMaterial3D.new()
	spot_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spot_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spot_material.albedo_color = Color(1.0, 0.8, 0.15, 0.25)
	disc.material = spot_material
	spot.mesh = disc
	spot.position = start_point + Vector3.UP * 0.04
	spot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(spot)


func _build_markers() -> void:
	_ring_material = _glow_material(RING_COLOR, 0.85)
	_next_material = _glow_material(NEXT_RING_COLOR, 0.35)
	_ring = _make_ring(_ring_material)
	_next_ring = _make_ring(_next_material)
	_next_ring.scale = Vector3.ONE * 0.7
	_arrow = Node3D.new()
	_arrow.top_level = true
	add_child(_arrow)
	var prism := PrismMesh.new()
	prism.size = Vector3(1.0, 1.5, 0.3)
	prism.material = _glow_material(RING_COLOR, 0.95)
	var arrow_mesh := MeshInstance3D.new()
	arrow_mesh.mesh = prism
	arrow_mesh.rotation.x = -PI * 0.5  # остриё — к −Z (look_at)
	arrow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arrow.add_child(arrow_mesh)
	_hide_markers()


## Кольцо-ворота на перекрёстке и столб света, видный из-за домов
func _make_ring(material: Material) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var torus := TorusMesh.new()
	torus.inner_radius = 3.8
	torus.outer_radius = 4.3
	torus.rings = 32
	torus.ring_segments = 6
	torus.material = material
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.rotation.x = PI * 0.5  # стоит вертикально
	ring.position.y = 4.3
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var beam := CylinderMesh.new()
	beam.top_radius = 0.5
	beam.bottom_radius = 0.5
	beam.height = 40.0
	beam.radial_segments = 8
	beam.rings = 1
	beam.material = material
	var beam_instance := MeshInstance3D.new()
	beam_instance.mesh = beam
	beam_instance.position.y = 20.0
	beam_instance.transparency = 0.6
	beam_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beam_instance)
	return root


func _glow_material(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color, alpha)
	return material


func _show_rings() -> void:
	_place_ring(_ring, _index)
	_next_ring.visible = _index + 1 < _points.size()
	if _next_ring.visible:
		_place_ring(_next_ring, _index + 1)
	_arrow.visible = true


## Кольцо поперёк пути: смотрит на предыдущую точку
func _place_ring(ring: Node3D, index: int) -> void:
	ring.visible = true
	var point: Vector3 = _points[index]
	var from: Vector3 = start_point if index == 0 else _points[index - 1]
	ring.global_position = point
	var direction: Vector3 = point - from
	ring.rotation.y = atan2(direction.x, direction.z) if direction.length_squared() > 0.01 else 0.0


func _hide_markers() -> void:
	_ring.visible = false
	_next_ring.visible = false
	_arrow.visible = false


func _update_arrow() -> void:
	if _car == null or _index >= _points.size():
		return
	_arrow.global_position = _car.global_position + Vector3.UP * (_car.get_roof_height() + 1.4)
	var target: Vector3 = _points[_index]
	target.y = _arrow.global_position.y
	if _arrow.global_position.distance_squared_to(target) > 0.25:
		_arrow.look_at(target, Vector3.UP)


# ---------- Интерфейс ----------

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 12
	add_child(_layer)
	_offer = PanelContainer.new()
	_offer.add_theme_stylebox_override(&"panel", UIKit.panel_style())
	_offer.visible = false
	_layer.add_child(_offer)
	_offer.anchor_left = 0.5
	_offer.anchor_right = 0.5
	_offer.anchor_top = 0.18
	_offer.anchor_bottom = 0.18
	_offer.offset_left = -200.0
	_offer.offset_right = 200.0
	_offer.grow_vertical = Control.GROW_DIRECTION_END
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	_offer.add_child(box)

	_hud = UIKit.label("", 30)
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_theme_constant_override(&"outline_size", 10)
	_hud.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_hud.visible = false
	_layer.add_child(_hud)
	_hud.anchor_left = 0.25
	_hud.anchor_right = 0.75
	_hud.anchor_top = 0.12
	_hud.anchor_bottom = 0.2

	_big = UIKit.label("", 64)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_big.add_theme_constant_override(&"outline_size", 16)
	_big.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big.visible = false
	_layer.add_child(_big)
	_big.anchor_left = 0.1
	_big.anchor_right = 0.9
	_big.anchor_top = 0.28
	_big.anchor_bottom = 0.6


func _update_hud() -> void:
	_hud.visible = true
	var best: float = GameState.get_race_best(str(ROUTES[_route]["id"]))
	var text: String = "%s  %d/%d  •  %s" % [UIKit.t(str(ROUTES[_route]["title"])), mini(_index + 1, _points.size()),
		_points.size(), _format_time(_time)]
	if best > 0.0:
		text += "  •  ★ " + _format_time(best)
	_hud.text = text


static func _format_time(seconds: float) -> String:
	var total: int = floori(seconds * 10.0)
	return "%d:%02d.%d" % [floori(total / 600.0), floori(total / 10.0) % 60, total % 10]


# ---------- Сетка ----------

func _nearest_index(value: float) -> int:
	var best: int = 0
	for i in lines.size():
		if absf(lines[i] - value) < absf(lines[best] - value):
			best = i
	return best


func _nearest_crossing(point: Vector3) -> Vector3:
	return Vector3(lines[_nearest_index(point.x)], 0.0, lines[_nearest_index(point.z)])


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
