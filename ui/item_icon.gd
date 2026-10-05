class_name ItemIcon
extends Control
## Объёмный значок предмета: аптечка — крест, патроны — три патрона.

var item: ItemData


static func create(item_data: ItemData, icon_size: float) -> ItemIcon:
	var icon := ItemIcon.new()
	icon.item = item_data
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	return icon


func _draw() -> void:
	if item == null:
		return
	var r: float = minf(size.x, size.y) * 0.5
	var center: Vector2 = size * 0.5
	draw_circle(center + Vector2(0.0, 3.0), r, Color(0.0, 0.0, 0.0, 0.4))
	draw_circle(center, r, item.icon_color.darkened(0.4))
	draw_circle(center - Vector2(0.0, 2.0), r * 0.86, item.icon_color)
	draw_set_transform(center - Vector2(0.0, r * 0.4), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, r * 0.55, Color(1.0, 1.0, 1.0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	match item.effect:
		ItemData.Effect.HEAL:
			var arm: float = r * 0.5
			var thick: float = r * 0.32
			draw_rect(Rect2(center - Vector2(arm, thick * 0.5), Vector2(arm * 2.0, thick)), Color.WHITE)
			draw_rect(Rect2(center - Vector2(thick * 0.5, arm), Vector2(thick, arm * 2.0)), Color.WHITE)
		ItemData.Effect.GRENADE:
			draw_circle(center + Vector2(0.0, r * 0.1), r * 0.42, Color(0.2, 0.28, 0.15))
			draw_rect(Rect2(center + Vector2(-r * 0.12, -r * 0.5), Vector2(r * 0.24, r * 0.2)), Color(0.75, 0.75, 0.7))
			draw_arc(center + Vector2(r * 0.22, -r * 0.45), r * 0.14, 0.0, TAU, 12, Color(0.85, 0.85, 0.8), 2.0, false)
		ItemData.Effect.MOLOTOV:
			draw_rect(Rect2(center + Vector2(-r * 0.2, -r * 0.1), Vector2(r * 0.4, r * 0.6)), Color(0.35, 0.55, 0.25, 0.9))
			draw_rect(Rect2(center + Vector2(-r * 0.08, -r * 0.4), Vector2(r * 0.16, r * 0.32)), Color(0.35, 0.55, 0.25, 0.9))
			draw_circle(center + Vector2(0.0, -r * 0.52), r * 0.16, Color(1.0, 0.75, 0.2))
		ItemData.Effect.MATERIAL:
			draw_arc(center, r * 0.35, 0.0, TAU, 16, Color(0.85, 0.85, 0.9), r * 0.16, false)
			for i in 6:
				var dir := Vector2.from_angle(i * TAU / 6.0)
				draw_line(center + dir * r * 0.4, center + dir * r * 0.58, Color(0.85, 0.85, 0.9), r * 0.14)
		ItemData.Effect.AMMO:
			var width: float = r * 0.22
			for i in 3:
				var x: float = center.x + (i - 1) * width * 1.5 - width * 0.5
				draw_rect(Rect2(Vector2(x, center.y - r * 0.2), Vector2(width, r * 0.65)), Color(0.85, 0.65, 0.2))
				draw_circle(Vector2(x + width * 0.5, center.y - r * 0.2), width * 0.5, Color(0.75, 0.45, 0.2))
