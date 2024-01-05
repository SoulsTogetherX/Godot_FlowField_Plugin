@tool
## Tile library for FlowFields.
## @experimental
class_name FieldSet extends Resource

## Size of the tiles repersented in the field
@export var tileSize  : Vector2  = Vector2(16, 16):
	set(val):
		tileSize.x = max(0.01, val.x);
		tileSize.y = max(0.01, val.y);
		changed.emit();

var _flowFieldPattern : Dictionary; # Vector2i -> FlowFieldCeil
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

## Checks if there is a tile at this position
func has_tile(pos : Vector2i) -> bool:
	return _flowFieldPattern.has(pos);

## Gets the bias, at the given tile position, in the current field.
## [br][br]
## [b]NOTE[/b]: Error if there is no tile at this position.
func get_bias(pos : Vector2i) -> float:
	return _flowFieldPattern[pos].bias;

## Gets the best direction to move, at the given tile position, in the current field.
## [br][br]
## [b]NOTE[/b]: Error if there is no tile at this position.
func get_direction(pos : Vector2i) -> Vector2:
	return _flowFieldPattern[pos].best_direction;

## Sets the bias at the given position in the field. Automatically creates the tile.
## [br][br]
## [b]NOTE[/b]: The field will not update immediately after function called. Use [method emit_changed] for that.
func set_tile(pos : Vector2i, bias : int) -> void:
	_flowFieldPattern[pos] = FlowFieldTile.new().set_bias(bias)
	_used_rect = _used_rect.expand(pos);

## Removes the tile, at the given position, in this field. Nothing will happen if there is no tile at that position.
## [br][br]
## [b]NOTE[/b]: The field will not update immediately after function called. Use [method emit_changed] for that.
func remove_tile(pos : Vector2i, update_size : bool) -> void:
	if !_flowFieldPattern.has(pos):
		return;
	
	_flowFieldPattern.erase(pos);
	if update_size:
		update_size();

## Force updates the registered used area of the field to fit all tiles. Will shrink or grow the rect as needed.
## [br][br]
## [b]NOTE[/b]: Thsi value automatically updates when [method set_tile] is used and when [method remove_tile] is
## used with the [param update_size] set to [code]true[/code].
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

## Returns the used last registered used area of the field.
func get_used_rect() -> Rect2i:
	return _used_rect;

## Returns an array of every unique bias the tiles, in this field, have.
func get_all_different_baises() -> Array[float]:
	var ret : Array[float] = [];
	var checker : Dictionary = {};
	
	for tile in _flowFieldPattern.values():
		if checker.has(tile.bias):
			continue;
		checker[tile.bias] = null;
		ret.append(tile.bias);
	
	return ret;
