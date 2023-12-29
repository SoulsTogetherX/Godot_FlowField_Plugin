@tool
extends EditorPlugin

const PLUGIN_PATH := "res://addons/FlowField";
const HIGHLIGHT_COLOR := Color(0.20784313976765, 0.55686277151108, 1, 0.50196081399918);

var _selected : FlowField = null;
var _bottom_panel : Control;

enum TOOL {SELECTION = 1, PAINT = 2, LINE = 4, RECT = 8, BUCKET = 16};
var _tool_type : TOOL = 0;
var _picker : bool = false;
var _eraser : bool = false;
var _grid : bool = false;
var _set_bias : int = 0;

var _highlighted_tiles : Dictionary = {};
var _dragging : bool;
var _last_m_pos : Vector2;

var _visible : bool = false;

func _enter_tree():
	add_custom_type("FlowField", "Node2D", preload(PLUGIN_PATH + "/src/flow_field.gd"), preload(PLUGIN_PATH + "/assets/flow_field.svg"));
	
	_bottom_panel = preload(PLUGIN_PATH + "/src/bottom_panel/bottom_panel.tscn").instantiate();
	_bottom_panel.tool_type_changed.connect(_change_tool);
	_bottom_panel.picker_changed.connect(_change_picker);
	_bottom_panel.eraser_changed.connect(_change_eraser);
	_bottom_panel.grid_changed.connect(_change_grid);
	_bottom_panel.bias_changed.connect(_change_bias);

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
			
			_selected = null;
	elif _selected == null:
		add_control_to_bottom_panel(_bottom_panel, "FlowField").toggled.connect(_change_visible);
		make_bottom_panel_item_visible(_bottom_panel);
		_visible = true;
		
		_set_selected(object);
	elif not _selected in EditorInterface.get_selection().get_selected_nodes():
		_set_selected(object);
	update_overlays();

func _set_selected(object : FlowField) -> void:
	_selected = object;
	_change_tool(_tool_type);
	_change_picker(_picker);
	_change_eraser(_eraser);
	_change_grid(_grid);

func _change_visible(toggle : bool) -> void:
	_visible = toggle;
	update_overlays();

func _change_tool(tool_type : int) -> void:
	_end_drag();
	_tool_type = tool_type;

func _change_picker(picker : bool) -> void:
	_picker = picker;

func _change_eraser(eraser : bool) -> void:
	_eraser = eraser;

func _change_grid(grid : bool) -> void:
	_grid = grid;

func _change_bias(bias : int) -> void:
	_set_bias = bias;

func _forward_canvas_gui_input(event):
	if _visible && _selected && event is InputEventMouse:
		if _selected.field_set:
			if event is InputEventMouseMotion:
				if _dragging && _tool_type > TOOL.SELECTION:
					_update_drag();
			
			if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT:
				if event.is_pressed():
					_begin_drag();
				elif event.is_released():
					_end_drag();
		
		update_overlays();
		return true;
	return false;

func _forward_canvas_draw_over_viewport(viewport: Control) -> void:
	if !_visible:
		return;
	
	var field_set : FieldSet = _selected.field_set;
	
	if field_set:
		var xform : Transform2D = _selected.get_viewport_transform() * _selected.get_canvas_transform();
		viewport.draw_set_transform_matrix(xform);
		
		var tileSize : Vector2 = field_set.tileSize;
		var mousePos : Vector2 = (_selected.get_local_mouse_position() / tileSize).floor() * tileSize;
		
		# Draw highlighted
		if _tool_type > TOOL.SELECTION:
			_draw_highlight(viewport, tileSize);
		
		# Draw cursor
		viewport.draw_rect(Rect2(mousePos, tileSize), Color.RED, false);
		
		viewport.draw_set_transform_matrix(Transform2D());

func _draw_highlight(viewport: Control, tileSize : Vector2) -> void:
	var tile_rect : Rect2 = Rect2(Vector2.ZERO, tileSize);
	
	for tile_pos : Vector2 in _highlighted_tiles.keys():
			tile_rect.position = tile_pos * tileSize;
			viewport.draw_rect(tile_rect, HIGHLIGHT_COLOR);

func _begin_drag() -> void:
	_dragging = true;
	_last_m_pos = _selected.get_local_mouse_position();
	_highlighted_tiles[Vector2i((_last_m_pos / _selected.field_set.tileSize).floor())] = FlowFieldTile.new(_set_bias);

func _update_drag() -> void:
	var end_m_pos = _selected.get_local_mouse_position();
	
	match _tool_type:
		TOOL.PAINT:
			_bresenham_line_highlight((_last_m_pos / _selected.field_set.tileSize).floor(), (end_m_pos / _selected.field_set.tileSize).floor())
			_last_m_pos = end_m_pos;
		TOOL.LINE:
			_highlighted_tiles.clear();
			_bresenham_line_highlight((_last_m_pos / _selected.field_set.tileSize).floor(), (end_m_pos / _selected.field_set.tileSize).floor())
		TOOL.RECT:
			_highlighted_tiles.clear();
			
			var begin_tile_pos : Vector2i = (_last_m_pos / _selected.field_set.tileSize).floor();
			var end_tile_pos : Vector2i = (end_m_pos / _selected.field_set.tileSize).floor();
			var offset : Vector2i = Vector2i(min(begin_tile_pos.x, end_tile_pos.x), min(begin_tile_pos.y, end_tile_pos.y));
			
			var rect_size : Vector2i = (begin_tile_pos - end_tile_pos).abs() + Vector2i.ONE;
			
			for y in rect_size.y:
				for x in rect_size.x:
					var look_up_pos : Vector2i = Vector2i(x, y) + offset;
					if !_highlighted_tiles.has(look_up_pos):
						_highlighted_tiles[look_up_pos] = FlowFieldTile.new(_set_bias);
		TOOL.BUCKET:
			pass;

func _end_drag() -> void:
	_dragging = false;
	
	var end_m_pos = _selected.get_local_mouse_position();
	
	_highlighted_tiles.clear();

func _bresenham_line_highlight(p_start : Vector2i, p_end : Vector2i) -> void:
	var delta : Vector2i = (p_end - p_start).abs() * 2;
	var step : Vector2i = (p_end - p_start).sign();
	var current : Vector2i= p_start;

	if delta.x > delta.y:
		var err : int = delta.x / 2;
		
		while current.x != p_end.x:
			if !_highlighted_tiles.has(current):
				_highlighted_tiles[current] = FlowFieldTile.new(_set_bias);
		
			err -= delta.y;
			if err < 0:
				current.y += step.y;
				err += delta.x;
			current.x += step.x
	else:
		var err : int = delta.y / 2;
		
		while current.y != p_end.y:
			if !_highlighted_tiles.has(current):
				_highlighted_tiles[current] = FlowFieldTile.new(_set_bias);
			
			err -= delta.x;
			if err < 0:
				current.x += step.x;
				err += delta.y;
			current.y += step.y
	
	if !_highlighted_tiles.has(current):
		_highlighted_tiles[current] = FlowFieldTile.new(_set_bias);
