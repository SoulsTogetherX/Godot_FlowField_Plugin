@tool
class_name FlowFieldTile2D extends Resource

@export var bias : int:
	set(val):
		if bias == val:
			return;
		bias = val;
		changed.emit();
var _value : int;
var best_direction : Vector2;

func set_bias(val : int) -> FlowFieldTile2D:
	bias = val;
	return self;

func _set_value(val : int) -> bool:
	if bias + val < _value:
		_value = bias + val;
		return true;
	return false;
