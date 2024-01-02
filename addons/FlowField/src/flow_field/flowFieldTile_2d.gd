@tool
class_name FlowFieldTile2D extends Resource

@export var bias : float:
	set(val):
		if is_equal_approx(bias, val):
			return;
		bias = val;
		changed.emit();
var _value : float;
var best_direction : Vector2;

func set_bias(val : float) -> FlowFieldTile2D:
	bias = val;
	return self;

func _set_value(val : float) -> bool:
	if bias + val < _value:
		_value = bias + val;
		return true;
	return false;
