extends Label
## Здоровье игрока в HUD.

@export var normal_color: Color = Color(1, 1, 1)
@export var low_health_color: Color = Color(1.0, 0.3, 0.3)
@export_range(0.0, 1.0, 0.05) var low_threshold: float = 0.3


func _ready() -> void:
	text = ""
	_connect_player.call_deferred()


func _connect_player() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or player.health == null:
		push_warning("HealthDisplay: игрок или его Health не найдены")
		return
	player.health.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health.current, player.health.max_health)


func _on_health_changed(current: float, max_value: float) -> void:
	text = "HP %d" % ceili(current)
	var is_low: bool = max_value > 0.0 and current / max_value <= low_threshold
	modulate = low_health_color if is_low else normal_color
