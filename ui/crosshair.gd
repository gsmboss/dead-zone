extends Label
## Прицел: краснеет при наведении на цель, вспыхивает при попадании.

const FLASH_TIME: float = 0.12

@export var weapon_manager: WeaponManager
@export var normal_color: Color = Color(1, 1, 1, 0.85)
@export var target_color: Color = Color(1.0, 0.3, 0.3)
@export var hit_color: Color = Color(1, 1, 1)
@export var headshot_color: Color = Color(1.0, 0.8, 0.1)

var _flash: float = 0.0
var _flash_color: Color = Color.WHITE


func _ready() -> void:
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


func _update_pivot() -> void:
	pivot_offset = size * 0.5
