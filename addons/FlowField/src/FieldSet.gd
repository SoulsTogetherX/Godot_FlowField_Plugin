@tool
class_name FieldSet extends Resource

enum CellNeighbor {
	CELL_NEIGHBOR_RIGHT_SIDE = 0,
	CELL_NEIGHBOR_RIGHT_CORNER,
	CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE,
	CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
	CELL_NEIGHBOR_BOTTOM_SIDE,
	CELL_NEIGHBOR_BOTTOM_CORNER,
	CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,
	CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	CELL_NEIGHBOR_LEFT_SIDE,
	CELL_NEIGHBOR_LEFT_CORNER,
	CELL_NEIGHBOR_TOP_LEFT_SIDE,
	CELL_NEIGHBOR_TOP_LEFT_CORNER,
	CELL_NEIGHBOR_TOP_SIDE,
	CELL_NEIGHBOR_TOP_CORNER,
	CELL_NEIGHBOR_TOP_RIGHT_SIDE,
	CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	CELL_NEIGHBOR_MAX,
};

@export var tileSize  : Vector2  = Vector2(16, 16):
	set(val):
		tileSize.x = max(0.01, val.x);
		tileSize.y = max(0.01, val.y);
		changed.emit();

# Vector2i -> FlowFieldCeil
var _flowFieldPattern : Dictionary;

func _get_property_list():
	var properties = [];
	properties.append({
		"name": "_flowFieldPattern",
		"type": TYPE_DICTIONARY,
		"usage": PROPERTY_USAGE_NO_EDITOR,
	});

	return properties;

func has_tile(pos : Vector2i) -> bool:
	return _flowFieldPattern.has[pos];

func set_tiles(tiles : Dictionary) -> void:
	for pos in tiles.keys():
		_flowFieldPattern[pos] = tiles[pos];
	changed.emit();

func remove_tiles(tiles : Dictionary) -> void:
	for pos in tiles.keys():
		_flowFieldPattern.erase(pos);
	changed.emit();

func get_used_rect() -> Rect2i:
	var ret : Rect2i;
	var first : bool = true;
	for tile_pos : Vector2i in _flowFieldPattern.keys():
		if first:
			ret = Rect2i(tile_pos, Vector2i.ZERO);
			first = false;
		else:
			ret.expand(tile_pos);
	
	return ret;

func get_all_different_baises() -> Array[int]:
	var ret : Array[int] = [];
	var checker : Dictionary = {};
	
	for tile in _flowFieldPattern.values():
		if checker.has(tile.bias):
			continue;
		checker[tile.bias] = null;
		ret.append(tile.bias);
	
	return ret;
