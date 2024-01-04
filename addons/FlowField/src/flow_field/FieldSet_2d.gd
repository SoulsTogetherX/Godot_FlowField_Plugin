@tool
class_name FieldSet2D extends Resource

@export var tileSize  : Vector2  = Vector2(16, 16):
	set(val):
		tileSize.x = max(0.01, val.x);
		tileSize.y = max(0.01, val.y);
		changed.emit();

# Vector2i -> FlowFieldCeil
var _flowFieldPattern : Dictionary;
var _used_rect : Rect2i = Rect2i(Vector2i.ZERO, Vector2i.ZERO);

func _get_property_list():
	var properties = [];
	properties.append({
		"name": "_flowFieldPattern",
		"type": TYPE_DICTIONARY,
		"usage": PROPERTY_USAGE_STORAGE,
	});
	properties.append({
		"name": "_used_rect",
		"type": TYPE_RECT2I,
		"usage": PROPERTY_USAGE_STORAGE,
	});
	
	return properties;

func has_tile(pos : Vector2i) -> bool:
	return _flowFieldPattern.has(pos);

func get_bias(pos : Vector2i) -> float:
	return _flowFieldPattern[pos].bias;

func set_tiles(tiles : Array[Vector2i], bias : int) -> void:
	var local_rect : Rect2i = _used_rect;
	
	for pos in tiles:
		_flowFieldPattern[pos] = FlowFieldTile2D.new().set_bias(bias)
		local_rect = local_rect.expand(pos);
	
	_used_rect = local_rect
	changed.emit();

func set_tile(pos : Vector2i, bias : int) -> void:
	_flowFieldPattern[pos] = FlowFieldTile2D.new().set_bias(bias)
	_used_rect = _used_rect.expand(pos);
	changed.emit();

func remove_tiles(tiles : Array[Vector2i]) -> void:
	for pos in tiles:
		_flowFieldPattern.erase(pos);
	
	update_size();
	changed.emit();

func remove_tile(pos : Vector2i, update_size : bool) -> void:
	_flowFieldPattern.erase(pos);
	
	if update_size:
		update_size();
	changed.emit();

func update_size() -> void:
	var local_rect : Rect2i;
	var first : bool = true;
	for pos : Vector2i in _flowFieldPattern.keys():
		if first:
			local_rect = Rect2i(pos, Vector2i.ONE);
			first = false;
			continue;
		local_rect = local_rect.expand(pos);
	
	_used_rect = local_rect;
	changed.emit();

func get_used_rect() -> Rect2i:
	return _used_rect;

func get_all_different_baises() -> Array[float]:
	var ret : Array[float] = [];
	var checker : Dictionary = {};
	
	for tile in _flowFieldPattern.values():
		if checker.has(tile.bias):
			continue;
		checker[tile.bias] = null;
		ret.append(tile.bias);
	
	return ret;
