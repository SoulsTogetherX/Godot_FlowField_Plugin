@tool
class_name FlowFieldTile extends Resource

@export var bias : int:
	set(val):
		if bias == val:
			return;
		bias = val;
		changed.emit();
var value : float:
	set(val):
		if value == val:
			return;
		value = val;
		changed.emit();

func set_bias(val : int) -> FlowFieldTile:
	bias = val;
	return self;
