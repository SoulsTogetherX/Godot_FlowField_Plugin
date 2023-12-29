class_name FlowFieldTile extends RefCounted

var bias : float = 0;
var value : float;

func _init(bias_val = 0) -> void:
	bias = bias_val;
