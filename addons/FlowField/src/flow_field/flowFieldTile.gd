@tool
## Settings for a single tile in a FlowField2D.
## @experimental
class_name FlowFieldTile extends Resource

## The bias of this tile. Higher the bias, the less favorable this tile will be to move on.
## [br][br]
## [b]NOTE[/b]: This value must be greater than [code]0[/code] or else things break.
## It is only a [code]float[/code] to avoid type casting.
var bias : float = 1.0;

## The stored best normalized direction vector. This will store the current tiles best movement path towards the destination.
## [br][br]
## [b]NOTE[/b]: This value will be [code]Vector2.ZERO[/code] if there is no possible path to the desired destination.
var best_direction : Vector2;

var _value : float;

func _get_property_list():
	var properties = [];
	properties.append({
		"name": "bias",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_STORAGE,
	});
	
	return properties;

## Sets the bias of this tile.
func set_bias(bias_num : float) -> FlowFieldTile:
	bias = bias_num;
	return self;

func _set_value(val : float) -> bool:
	if bias + val < _value:
		_value = bias + val;
		return true;
	return false;
