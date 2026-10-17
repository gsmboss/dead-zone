class_name DecorList
extends Resource
## Каталог обустройства убежища (base/decor_list.tres)

@export var decor: Array[DecorData] = []


func find(decor_id: String) -> DecorData:
	for item: DecorData in decor:
		if item != null and item.id == decor_id:
			return item
	return null
