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
