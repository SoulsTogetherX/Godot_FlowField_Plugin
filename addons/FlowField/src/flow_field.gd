@tool
class_name FlowField extends Node2D

enum FLOWFIELD_TYPE {Orthogonal};

@export var flow_type : FLOWFIELD_TYPE;
@export var chuckSize : Vector2i = Vector2i(16, 16):
	set(val):
		chuckSize.x = max(2, val.x);
		chuckSize.y = max(2, val.y);
@export var tileSize  : Vector2  = Vector2(16, 16):
	set(val):
		tileSize.x = max(0.01, val.x);
		tileSize.y = max(0.01, val.y);

signal changed();
signal updated();

# Vector2i -> chunk;
var _chucks : Dictionary = {};
var _positions : Array[Vector2];
var _bound_top_left : Vector2i = Vector2i.ZERO;
var _bound_top_right : Vector2i = Vector2i.ZERO;
var _chunk_grid: Node2D;
var _chunk_move: Node2D;
var _chunk_values: Node2D;
var _display : bool = false:
	set(val):
		_display = val;
		
		queue_redraw();
var _force_update: bool = false;

const display_move_script : Script = preload("res://addons/FlowField/src/draw_scripts/chunk_move_display.gd");
const display_grid_script : Script = preload("res://addons/FlowField/src/draw_scripts/chunk_grid_display.gd");
const display_values_script : Script = preload("res://addons/FlowField/src/draw_scripts/chunk_values_display.gd");
func _ready() -> void:
	_chunk_move = Node2D.new();
	_chunk_move.show_behind_parent = true;
	_chunk_move.set_script(display_move_script);
	add_child(_chunk_move);
	
	_chunk_grid = Node2D.new();
	_chunk_grid.set_script(display_grid_script);
	_chunk_move.add_child(_chunk_grid);
	
	_chunk_values = Node2D.new();
	_chunk_values.set_script(display_values_script);
	_chunk_move.add_child(_chunk_values);
	
	_positions = _get_mouse_pos();

func _get_mouse_pos() -> Array[Vector2]:
	var mouse_pos : Vector2 = get_local_mouse_position();
	
	var chunk_pos : Vector2 = (Vector2(mouse_pos) / (Vector2(chuckSize) * tileSize)).floor();
	var tile_pos : Vector2 = Vector2(mouse_pos / tileSize).floor();
	
	return [chunk_pos, tile_pos];

func _update_mouse_pos() -> void:
	_positions = _get_mouse_pos();

func force_draw_update() -> void:
	_force_update = true;
	queue_redraw();
	_force_update = false;

func _draw() -> void:
	_chunk_move.visible = _display;
	if _display:
		var cal_size : Vector2 = Vector2(chuckSize) * tileSize;
		
		var positions : Array[Vector2] = _positions;
		if _chunk_move.move_to(positions[0], cal_size) || _force_update:
			_chunk_grid.draw_grid(chuckSize, tileSize);
			_chunk_values.draw_values(chuckSize, tileSize, _chucks[positions[0]] if _chucks.has(positions[0]) else Chunk.new());
		
		draw_rect(Rect2(positions[1] * tileSize, tileSize), Color.RED, false);
