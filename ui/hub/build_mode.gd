class_name BuildMode
extends Control
## Режим стройки в убежище (как в Minecraft): игрок ходит и смотрит как обычно, в центре экрана —
## прицел; зелёный куб показывает, куда встанет блок (красный — нельзя, причина в строке сверху),
## оранжевый — какой блок будет разобран. Справа — палитра блоков по разделам, ПОСТАВИТЬ, УБРАТЬ,
## ПОВЕРНУТЬ, ГОТОВО. На ПК: F/Ctrl — поставить, R — убрать, Q — повернуть.
## Создаёт HubHUD; сам ничего не сохраняет — GameState.place_block / remove_block.

signal closed

const RAY_LENGTH: float = 7.0
const PALETTE_WIDTH: float = 290.0
const PLACE_COLOR: Color = Color(0.3, 1.0, 0.4, 0.33)
const BLOCKED_COLOR: Color = Color(1.0, 0.25, 0.2, 0.33)
const REMOVE_COLOR: Color = Color(1.0, 0.6, 0.1, 0.3)
const STATUS_TIME: float = 2.0

## Отступ сверху (баннер рекламы и т.п.)
var top_offset: float = 12.0

var _builder: BaseBuilder
var _player: Player
var _piece: BuildPiece
var _rotation: int = 0
var _place_cell: Vector3i = Vector3i.MAX
var _remove_cell: Vector3i = Vector3i.MAX
var _reason: String = ""
var _shown_reason: String = "-"
var _ray: PhysicsRayQueryParameters3D
var _ghost: MeshInstance3D
var _ghost_material: StandardMaterial3D
var _remove_ghost: MeshInstance3D
var _info: Label
var _status: Label
var _status_left: float = 0.0
var _place_button: Button
var _palette_buttons: Dictionary = {}  # id → Button
var _blocked: Array[Control] = []


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_builder = get_tree().get_first_node_in_group(BaseBuilder.GROUP) as BaseBuilder
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _builder == null or _player == null:
		push_warning("BuildMode: нет BaseBuilder или игрока — стройка недоступна")
	_ray = PhysicsRayQueryParameters3D.new()
	_ray.collision_mask = PhysicsLayers.WORLD
	_build_ui()
	_build_ghosts()
	for piece: BuildPiece in GameState.build_catalog.pieces:
		if piece != null:
			_select(piece)
			break
	GameState.coins_changed.connect(_on_resources_changed)
	GameState.inventory_changed.connect(_update_info)
	GameState.blocks_changed.connect(_on_blocks_changed)
	_set_touch_blocking(true)


func _exit_tree() -> void:
	_set_touch_blocking(false)
	for ghost: Node in [_ghost, _remove_ghost]:
		if ghost != null and is_instance_valid(ghost):
			ghost.queue_free()


func close() -> void:
	closed.emit()
	queue_free()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"fire"):
		_place()
	elif Input.is_action_just_pressed(&"reload"):
		_remove()
	elif Input.is_action_just_pressed(&"switch_weapon"):
		_rotate()
	if _status_left > 0.0:
		_status_left -= delta
		if _status_left <= 0.0:
			_shown_reason = "-"  # вернуть подсказку о месте


func _physics_process(_delta: float) -> void:
	_update_target()
	var reason: String = _reason if _status_left <= 0.0 else _shown_reason
	if reason != _shown_reason and _status_left <= 0.0:
		_shown_reason = reason
		_status.text = reason if not reason.is_empty() else "МОЖНО СТАВИТЬ"
		_status.modulate = UIKit.GOOD if reason.is_empty() else Color(1.0, 0.45, 0.35)
		_place_button.modulate = Color.WHITE if reason.is_empty() else Color(1.0, 1.0, 1.0, 0.5)


# ---------- Цель (куда смотрит прицел) ----------

func _update_target() -> void:
	_place_cell = Vector3i.MAX
	_remove_cell = Vector3i.MAX
	_reason = "НАВЕДИ ПРИЦЕЛ НА ЗЕМЛЮ ИЛИ БЛОК"
	if _builder == null or _player == null or _player.camera == null:
		_hide_ghosts()
		return
	var camera: Camera3D = _player.camera
	var origin: Vector3 = camera.global_position
	var direction: Vector3 = -camera.global_basis.z
	_ray.from = origin
	_ray.to = origin + direction * RAY_LENGTH
	var hit: Dictionary = _builder.get_world_3d().direct_space_state.intersect_ray(_ray)
	var hit_distance: float = RAY_LENGTH
	if not hit.is_empty():
		var position_value: Vector3 = hit["position"]
		var normal: Vector3 = hit["normal"]
		hit_distance = origin.distance_to(position_value)
		_place_cell = BaseBuilder.cell_at(position_value + normal * 0.5)
		if hit["rid"] == _builder.get_body_rid():
			_remove_cell = BaseBuilder.cell_at(position_value - normal * 0.5)
	# Блоки без коллизии (спальник, костёр) — ищем по лучу до точки попадания
	if _remove_cell == Vector3i.MAX or not _builder.has_block(_remove_cell):
		_remove_cell = Vector3i.MAX
		var step: float = 0.1
		var travelled: float = 0.3
		while travelled < hit_distance:
			var cell: Vector3i = BaseBuilder.cell_at(origin + direction * travelled)
			if _builder.has_block(cell):
				_remove_cell = cell
				break
			travelled += step
	if _place_cell != Vector3i.MAX:
		_reason = _builder.can_place(_place_cell, _piece, _player)
		_ghost.visible = true
		_ghost.global_position = BaseBuilder.cell_center(_place_cell)
		_ghost_material.albedo_color = PLACE_COLOR if _reason.is_empty() else BLOCKED_COLOR
	else:
		_ghost.visible = false
	_remove_ghost.visible = _remove_cell != Vector3i.MAX
	if _remove_ghost.visible:
		_remove_ghost.global_position = BaseBuilder.cell_center(_remove_cell)


func _hide_ghosts() -> void:
	if _ghost != null:
		_ghost.visible = false
	if _remove_ghost != null:
		_remove_ghost.visible = false


# ---------- Действия ----------

func _place() -> void:
	if _place_cell == Vector3i.MAX or not _reason.is_empty():
		Sfx.error()
		_show_status(_reason if not _reason.is_empty() else "НЕКУДА СТАВИТЬ", false)
		return
	if GameState.place_block(_place_cell, _piece.id, _rotation):
		Sfx.play_3d(Sfx.pick(Sfx.sounds.metal_hits), BaseBuilder.cell_center(_place_cell), -2.0, 0.8)
		_pop(_place_button)
	else:
		Sfx.error()


func _remove() -> void:
	if _remove_cell == Vector3i.MAX:
		Sfx.error()
		_show_status("НАВЕДИ ПРИЦЕЛ НА СВОЙ БЛОК", false)
		return
	var at: Vector3 = BaseBuilder.cell_center(_remove_cell)
	var piece: BuildPiece = GameState.remove_block(_remove_cell)
	if piece == null:
		return
	Sfx.play_3d(Sfx.pick(Sfx.sounds.metal_hits), at, -4.0, 1.2)
	var refund: String = "+%d МОНЕТ" % floori(piece.price * GameState.BLOCK_REFUND)
	_show_status("РАЗОБРАНО: %s  %s" % [piece.title, refund], true)


func _rotate() -> void:
	_rotation = (_rotation + 1) % 4
	Sfx.click()
	_update_info()
	_show_status("ПОВОРОТ %d°" % (_rotation * 90), true)


func _select(piece: BuildPiece) -> void:
	_piece = piece
	for piece_id: String in _palette_buttons:
		(_palette_buttons[piece_id] as Button).modulate = UIKit.ACCENT if piece_id == piece.id \
			else Color(1.0, 1.0, 1.0, 0.8)
	_update_info()


func _show_status(text: String, good: bool) -> void:
	_status.text = text
	_status.modulate = UIKit.GOOD if good else Color(1.0, 0.45, 0.35)
	_status_left = STATUS_TIME
	_shown_reason = text


func _on_resources_changed(_coins: int) -> void:
	_update_info()


func _on_blocks_changed(_cell: Vector3i) -> void:
	_update_info()


func _update_info() -> void:
	if _info == null or _piece == null:
		return
	var rotation_text: String = "  •  ПОВОРОТ %d°" % (_rotation * 90) if _piece.kind == BuildPiece.Kind.MODEL else ""
	_info.text = "%s — %s%s\nМОНЕТЫ: %d  •  ЛОМ: %d  •  БЛОКОВ: %d/%d" % [_piece.title, _piece.get_price_text(),
		rotation_text, GameState.coins, GameState.get_item_count(GameState.SCRAP_ID), GameState.get_block_count(),
		GameState.MAX_BLOCKS]


# ---------- Интерфейс ----------

func _build_ui() -> void:
	# Прицел
	var crosshair := BuildCrosshair.new()
	add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(PRESET_CENTER, PRESET_MODE_MINSIZE)
	crosshair.grow_horizontal = GROW_DIRECTION_BOTH
	crosshair.grow_vertical = GROW_DIRECTION_BOTH

	# Сверху слева — что выбрано, ресурсы, подсказка
	var info_panel := PanelContainer.new()
	info_panel.mouse_filter = MOUSE_FILTER_IGNORE
	info_panel.add_theme_stylebox_override(&"panel", UIKit.panel_style(Color(0.0, 0.0, 0.0, 0.55), 10, 12.0))
	add_child(info_panel)
	info_panel.set_anchors_and_offsets_preset(PRESET_TOP_LEFT)
	info_panel.offset_left = 16.0
	info_panel.offset_top = top_offset
	var info_box := VBoxContainer.new()
	info_box.mouse_filter = MOUSE_FILTER_IGNORE
	info_panel.add_child(info_box)
	var title := UIKit.label("СТРОЙКА", 26, info_box)
	title.modulate = UIKit.ACCENT
	_info = UIKit.label("", 20, info_box)
	_info.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status = UIKit.label("", 22, info_box)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF

	# Сверху справа — УБРАТЬ, ПОВЕРНУТЬ, ГОТОВО
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override(&"separation", 10)
	add_child(top_row)
	top_row.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT, PRESET_MODE_MINSIZE)
	top_row.grow_horizontal = GROW_DIRECTION_BEGIN
	top_row.offset_right = -16.0
	top_row.offset_top = top_offset
	var remove := UIKit.button("УБРАТЬ", 22, 150.0)
	remove.modulate = Color(1.0, 0.75, 0.5)
	remove.pressed.connect(_remove)
	top_row.add_child(remove)
	var rotate := UIKit.button("ПОВЕРНУТЬ", 22, 170.0)
	rotate.pressed.connect(_rotate)
	top_row.add_child(rotate)
	var done := UIKit.button("ГОТОВО", 22, 150.0)
	done.modulate = UIKit.GOOD
	done.pressed.connect(close)
	top_row.add_child(done)
	_blocked.append(top_row)

	# Справа — палитра блоков по разделам
	var palette := PanelContainer.new()
	palette.add_theme_stylebox_override(&"panel", UIKit.panel_style(Color(0.05, 0.05, 0.06, 0.82), 10, 8.0))
	add_child(palette)
	palette.set_anchors_and_offsets_preset(PRESET_RIGHT_WIDE)
	palette.offset_left = -PALETTE_WIDTH - 16.0
	palette.offset_right = -16.0
	palette.offset_top = top_offset + UIKit.BUTTON_HEIGHT + 14.0
	palette.offset_bottom = -150.0
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	palette.add_child(scroll)
	TouchScroll.attach(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 6)
	scroll.add_child(column)
	for category in BuildPiece.CATEGORY_NAMES.size():
		var header := UIKit.label(BuildPiece.CATEGORY_NAMES[category], 20, column)
		header.modulate = UIKit.DIM
		for piece: BuildPiece in GameState.build_catalog.pieces:
			if piece == null or piece.category != category:
				continue
			var button := UIKit.button("%s\n%s" % [piece.title, piece.get_price_text()], 17)
			button.size_flags_horizontal = SIZE_EXPAND_FILL
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var texture: Texture2D = _builder.get_texture(piece) if _builder != null else null
			if texture != null:
				button.icon = texture
				button.expand_icon = true
				button.add_theme_constant_override(&"icon_max_width", 44)
			button.pressed.connect(_select.bind(piece))
			column.add_child(button)
			_palette_buttons[piece.id] = button
	_blocked.append(palette)

	# Снизу справа — большая ПОСТАВИТЬ (левее — кнопка прыжка убежища)
	_place_button = UIKit.button("ПОСТАВИТЬ", 30, PALETTE_WIDTH)
	_place_button.custom_minimum_size.y = 110.0
	_place_button.pressed.connect(_place)
	add_child(_place_button)
	_place_button.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT, PRESET_MODE_MINSIZE)
	_place_button.grow_horizontal = GROW_DIRECTION_BEGIN
	_place_button.grow_vertical = GROW_DIRECTION_BEGIN
	_place_button.offset_right = -16.0
	_place_button.offset_bottom = -24.0
	_blocked.append(_place_button)


func _build_ghosts() -> void:
	if _builder == null:
		return
	_ghost_material = _ghost_material_for(PLACE_COLOR)
	_ghost = _make_ghost(1.02, _ghost_material)
	_remove_ghost = _make_ghost(1.06, _ghost_material_for(REMOVE_COLOR))


func _make_ghost(size_value: float, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size_value
	var ghost := MeshInstance3D.new()
	ghost.mesh = mesh
	ghost.material_override = material
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.visible = false
	ghost.top_level = true
	_builder.add_child(ghost)
	return ghost


func _ghost_material_for(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	return material


## Касания по панелям стройки не двигают игрока и не крутят камеру
func _set_touch_blocking(enabled: bool) -> void:
	if _player == null or _player.touch_controls == null:
		return
	var areas: Array[Control] = _player.touch_controls.blocked_areas
	for area: Control in _blocked:
		if enabled and not area in areas:
			areas.append(area)
		elif not enabled:
			areas.erase(area)


func _pop(target: Control) -> void:
	target.pivot_offset = target.size * 0.5
	target.scale = Vector2.ONE * 0.92
	create_tween().tween_property(target, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)


## Прицел стройки — крестик в центре экрана
class BuildCrosshair:
	extends Control

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(40.0, 40.0)

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		for width: float in [5.0, 2.0]:
			var color: Color = Color(0.0, 0.0, 0.0, 0.6) if width > 3.0 else Color.WHITE
			draw_line(center - Vector2(14.0, 0.0), center + Vector2(14.0, 0.0), color, width)
			draw_line(center - Vector2(0.0, 14.0), center + Vector2(0.0, 14.0), color, width)
