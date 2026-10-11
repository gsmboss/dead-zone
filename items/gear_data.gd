class_name GearData
extends Resource
## Снаряжение (покупается один раз в оружейной): факел и т.п.

@export var id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export_range(0, 100000, 10) var price: int = 0
