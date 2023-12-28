class_name Chunk extends RefCounted

var _tiles : Array[Array]; # Array[Array[Tiles]]

func fill(size : Vector2i) -> void:
	for r in size.y:
		var row : Array[Tile];
		row.resize(size.x)
		_tiles.append(row);

func resize_tiles(size : Vector2i) -> void:
	pass;

func getTileAt(pos : Vector2i) -> Tile:
	if pos.y < 0 || _tiles.size() <= pos.y || pos.x < 0 || _tiles[0].size() <= pos.y:
		return null;
	return _tiles[pos.y][pos.x];
