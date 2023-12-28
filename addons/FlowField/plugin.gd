@tool
extends EditorPlugin

var _selected : FlowField = null;
var _bottom_panel : Control;

func _enter_tree():
	add_custom_type("FlowField", "Node2D", preload("res://addons/FlowField/src/flow_field.gd"), preload("res://addons/FlowField/assets/flow_field.svg"));
	
	_bottom_panel = preload("res://addons/FlowField/src/bottom_panel/bottom_panel.tscn").instantiate();
	_bottom_panel.tool_type_changed.connect(_change_tool);
	_bottom_panel.picker_changed.connect(_change_picker);
	_bottom_panel.eraser_changed.connect(_change_eraser);
	_bottom_panel.grid_changed.connect(_change_grid);

func _exit_tree():
	remove_custom_type("FlowField");
	remove_control_from_bottom_panel(_bottom_panel);
	_bottom_panel.queue_free();

func _handles(object):
	return object is FlowField;

func _edit(object: Object) -> void:
	if object == null:
		if _selected != null:
			remove_control_from_bottom_panel(_bottom_panel);
			_selected._display = false;
			_selected = null;
	elif _selected == null:
		add_control_to_bottom_panel(_bottom_panel, "FlowField");
		make_bottom_panel_item_visible(_bottom_panel);
		
		_set_selected(object);
	elif not _selected in EditorInterface.get_selection().get_selected_nodes():
		_selected._display = false;
		
		_set_selected(object);

func _forward_canvas_gui_input(event):
	if _selected && event is InputEventMouse:
		if event is InputEventMouseMotion:
			_selected._update_mouse_pos();
		elif event is InputEventMouseButton:
			
			
			
			pass;
		
		_selected.queue_redraw();
		return true;
	return false;

func _set_selected(object : FlowField) -> void:
	_selected = object;
	_selected._display = true;
	_selected.force_draw_update();
	_change_tool(_bottom_panel._tool_type);
	_change_picker(_bottom_panel._picker);
	_change_eraser(_bottom_panel._eraser);
	_change_grid(_bottom_panel._grid);

func _change_tool(tool_type : int) -> void:
	prints("tool", tool_type);

func _change_picker(picker : bool) -> void:
	prints("picker", picker);

func _change_eraser(eraser : bool) -> void:
	prints("eraser", eraser);

func _change_grid(grid : bool) -> void:
	prints("grid", grid);
