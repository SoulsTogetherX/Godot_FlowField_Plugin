@tool
extends Control

enum TOOL {SELECTION = 1, PAINT = 2, LINE = 4, RECT = 8, BUCKET = 16};
var _tool_type : int = 0b00001;
var _picker : bool = false;
var _eraser : bool = false;
var _grid : bool = true;

signal tool_type_changed(tool : TOOL);
signal picker_changed(toggle : bool);
signal eraser_changed(toggle : bool);
signal grid_changed(toggle : bool);

func _change_tool_type(tool_type : TOOL):
	_tool_type = tool_type;
	tool_type_changed.emit(tool_type);

func _toggle_picker(toggle: bool) -> void:
	_picker = toggle;
	picker_changed.emit(toggle);

func _toggle_eraser(toggle: bool) -> void:
	_eraser = toggle;
	eraser_changed.emit(toggle);

func _toggle_grid(toggle: bool) -> void:
	_grid = toggle;
	grid_changed.emit(toggle);
