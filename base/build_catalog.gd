class_name BuildCatalog
extends Resource
## Все блоки стройки убежища (base/build_catalog.tres)

@export var pieces: Array[BuildPiece] = []


func find(piece_id: String) -> BuildPiece:
	for piece: BuildPiece in pieces:
		if piece != null and piece.id == piece_id:
			return piece
	return null
