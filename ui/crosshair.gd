extends Label
## Прицел: краснеет при наведении на цель, при попадании — крестик и звук.

const FLASH_TIME: float = 0.12

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


func _ready() -> void:
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


func _process(delta: float) -> void:
	if weapon_manager == null:
		return
	_flash = maxf(_flash - delta, 0.0)
	if _flash > 0.0:
		modulate = _flash_color
		scale = Vector2.ONE * (1.0 + _flash * 4.0)
	else:
		modulate = target_color if weapon_manager.is_target_in_sight() else normal_color
		scale = Vector2.ONE


func _on_hit_landed(is_headshot: bool, killed: bool) -> void:
	_flash = FLASH_TIME * (1.6 if killed else 1.0)
	_flash_color = headshot_color if is_headshot else hit_color
	var marker_color: Color = kill_color if killed else _flash_color
	_hit_marker.show_hit(marker_color, killed)
	Sfx.play_2d(Sfx.sounds.hitmarker, hit_sound_volume_db, 1.25 if killed else 1.0, 0.03)


func _update_pivot() -> void:
	pivot_offset = size * 0.5
	if _hit_marker != null:
		_hit_marker.position = size * 0.5
