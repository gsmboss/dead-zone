class_name DecorData
extends Resource
## Обустройство убежища (окно БАЗА, вкладка ОБУСТРОЙСТВО): покупается один раз, появляется во дворе
## в своей точке. Модель собирает HubDecor по имени builder. Уют (comfort) поднимает потолок
## настроения жильцов; места spots — где стоят или сидят жильцы.

enum Zone { LOUNGE, CAMP, YARD }

const ZONE_NAMES: PackedStringArray = ["ЗОНА ОТДЫХА", "У КОСТРА", "ДВОР"]

@export var id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var price: int = 300
## Уют: +потолок настроения
@export var comfort: int = 4
## Нужен уровень убежища
@export var required_level: int = 1
@export var zone: Zone = Zone.YARD
## Сборщик модели (HubDecor._build_<builder>)
@export var builder: StringName = &""
## Где стоит во дворе и куда повёрнут
@export var position: Vector3 = Vector3.ZERO
@export var yaw_degrees: float = 0.0
@export var icon_color: Color = Color(0.7, 0.7, 0.75)


func get_zone_name() -> String:
	return ZONE_NAMES[clampi(zone, 0, ZONE_NAMES.size() - 1)]
