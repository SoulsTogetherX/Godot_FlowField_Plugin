@tool
class_name FlowField extends Node2D

enum FLOWFIELD_TYPE {Orthogonal};

@export var flow_type : FLOWFIELD_TYPE;

@export var field_set : FieldSet:
	set(val):
		if field_set == val:
			return;
		
		if field_set:
			field_set.changed.disconnect(_changed);
		if val:
			val.changed.connect(_changed);
		
		field_set = val;
func _changed() -> void:
	changed.emit();

signal changed();

func _ready() -> void:
	changed.connect(queue_redraw);

func _draw() -> void:
	var tiles = field_set.flowFieldPattern
	var tileSize = field_set.tileSize
	
	for pos : Vector2i in tiles:
		var tileInfo = tiles[pos];
		
		draw_rect(Rect2(Vector2(pos) * tileSize, tileSize), Color.RED, false);
