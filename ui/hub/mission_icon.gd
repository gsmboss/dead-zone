class_name MissionIcon
extends Control
## Значок типа миссии (рисуется): волны, охота, выживание, оборона, припасы,
## бесконечный режим, город; босс — череп.

var mission: MissionData
var accent: Color = Color(0.95, 0.55, 0.15)


static func create(mission_data: MissionData, icon_size: float) -> MissionIcon:
	var icon := MissionIcon.new()
	icon.mission = mission_data
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	return icon


## Цвет миссии (маяк на карте, иконка) по типу
static func color_for(mission_data: MissionData) -> Color:
	if mission_data == null:
		return Color.GRAY
	if mission_data.boss != null and mission_data.type == MissionData.Type.WAVES:
		return Color(0.9, 0.15, 0.12)
	match mission_data.type:
		MissionData.Type.WAVES:
			return Color(0.95, 0.55, 0.15)
		MissionData.Type.KILL_COUNT:
			return Color(0.9, 0.3, 0.2)
		MissionData.Type.SURVIVE:
			return Color(0.85, 0.75, 0.2)
		MissionData.Type.DEFEND:
			return Color(0.3, 0.6, 0.95)
		MissionData.Type.COLLECT:
			return Color(0.35, 0.85, 0.4)
		MissionData.Type.ENDLESS:
			return Color(0.7, 0.35, 0.95)
		MissionData.Type.FREE_ROAM:
			return Color(0.25, 0.85, 0.85)
	return Color.GRAY


func _draw() -> void:
	if mission == null:
		return
	accent = color_for(mission)
	var r: float = minf(size.x, size.y) * 0.5
	var c: Vector2 = size * 0.5
	# Ржавая шайба с ободком
	draw_circle(c + Vector2(0.0, 3.0), r, Color(0.0, 0.0, 0.0, 0.45))
	draw_circle(c, r, accent.darkened(0.55))
	draw_circle(c, r * 0.86, Color(0.1, 0.1, 0.1))
	draw_arc(c, r * 0.86, 0.0, TAU, 32, accent, 2.5, false)
	var ink: Color = accent.lightened(0.2)
	var w: float = maxf(r * 0.1, 2.0)
	if mission.boss != null and mission.type == MissionData.Type.WAVES:
		_skull(c, r * 0.5, ink)
		return
	match mission.type:
		MissionData.Type.WAVES:
			for i in 3:
				var y: float = c.y - r * 0.3 + i * r * 0.3
				draw_polyline(PackedVector2Array([Vector2(c.x - r * 0.45, y), Vector2(c.x - r * 0.15, y - r * 0.15),
					Vector2(c.x + r * 0.15, y), Vector2(c.x + r * 0.45, y - r * 0.15)]), ink, w)
		MissionData.Type.KILL_COUNT:
			draw_arc(c, r * 0.42, 0.0, TAU, 24, ink, w, false)
			draw_line(c - Vector2(r * 0.6, 0.0), c + Vector2(r * 0.6, 0.0), ink, w)
			draw_line(c - Vector2(0.0, r * 0.6), c + Vector2(0.0, r * 0.6), ink, w)
		MissionData.Type.SURVIVE:
			draw_arc(c, r * 0.5, 0.0, TAU, 24, ink, w, false)
			draw_line(c, c + Vector2(0.0, -r * 0.35), ink, w)
			draw_line(c, c + Vector2(r * 0.28, 0.0), ink, w)
		MissionData.Type.DEFEND:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.4, -r * 0.45), c + Vector2(r * 0.4, -r * 0.45),
				c + Vector2(r * 0.4, r * 0.05), c + Vector2(0.0, r * 0.5), c + Vector2(-r * 0.4, r * 0.05)]), ink)
		MissionData.Type.COLLECT:
			draw_rect(Rect2(c - Vector2(r * 0.42, r * 0.3), Vector2(r * 0.84, r * 0.6)), ink)
			draw_rect(Rect2(c - Vector2(r * 0.42, r * 0.3), Vector2(r * 0.84, r * 0.14)), accent.darkened(0.3))
		MissionData.Type.ENDLESS:
			draw_arc(c - Vector2(r * 0.22, 0.0), r * 0.22, 0.0, TAU, 20, ink, w, false)
			draw_arc(c + Vector2(r * 0.22, 0.0), r * 0.22, 0.0, TAU, 20, ink, w, false)
		MissionData.Type.FREE_ROAM:
			for i in 3:
				var bw: float = r * 0.24
				var bh: float = r * (0.5 + 0.25 * (i % 2))
				draw_rect(Rect2(Vector2(c.x - r * 0.42 + i * bw * 1.15, c.y + r * 0.4 - bh), Vector2(bw, bh)), ink)


func _skull(c: Vector2, r: float, ink: Color) -> void:
	draw_circle(c - Vector2(0.0, r * 0.15), r * 0.8, ink)
	draw_rect(Rect2(c + Vector2(-r * 0.45, r * 0.35), Vector2(r * 0.9, r * 0.45)), ink)
	var hole: Color = Color(0.1, 0.1, 0.1)
	draw_circle(c + Vector2(-r * 0.32, -r * 0.1), r * 0.22, hole)
	draw_circle(c + Vector2(r * 0.32, -r * 0.1), r * 0.22, hole)
	for i in 3:
		draw_line(c + Vector2(-r * 0.25 + i * r * 0.25, r * 0.45), c + Vector2(-r * 0.25 + i * r * 0.25, r * 0.8), hole, 2.0)
