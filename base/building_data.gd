class_name BuildingData
extends Resource
## Постройка базы в убежище. Покупается в окне «БАЗА», появляется во дворе убежища.

@export var id: String = ""
@export var title: String = "МАСТЕРСКАЯ"
@export_multiline var description: String = ""
@export var price: int = 500
## Модель, которая появляется в убежище после постройки
@export var hub_model: PackedScene
@export var hub_model_scale: float = 1.0
@export var icon_color: Color = Color(0.6, 0.6, 0.65)
## Нужен уровень убежища (расширение двора)
@export var required_level: int = 1
## Уют: +потолок настроения жильцов
@export var comfort: int = 0
## Сборщик модели из частей (HubDecor._build_<builder>) — тогда постройка стоит в hub_position,
## а не в местах BaseBuildings (Marker3D) и hub_model не нужен
@export var builder: StringName = &""
@export var hub_position: Vector3 = Vector3.ZERO
@export var hub_yaw_degrees: float = 0.0
