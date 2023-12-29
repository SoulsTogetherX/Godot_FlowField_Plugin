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
var _flowFieldPattern : Dictionary = {};
var flowFieldPattern : Dictionary = {}:
	get:
		return _flowFieldPattern; 
	set(val):
		_flowFieldPattern = val;
		changed.emit();

func set_tile(tile : FlowFieldTile) -> void:
	_flowFieldPattern[tile.position] = tile;
	changed.emit();

func set_tiles(tiles : Array[FlowFieldTile]) -> void:
	for tile in tiles:
		_flowFieldPattern[tile.position] = tile;
	changed.emit();

func remove_tile(pos : Vector2i) -> void:
	if _flowFieldPattern.has(pos):
		_flowFieldPattern.erase(pos);
		changed.emit();

func remove_tiles(tiles : Array[Vector2i]) -> void:
	for tile in tiles:
		if _flowFieldPattern.has(tiles):
			_flowFieldPattern.erase(tiles);
	changed.emit();
