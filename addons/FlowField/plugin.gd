@tool
extends EditorPlugin

enum TOOL {NONE = -1, SELECTION, PAINT, LINE, RECT, BUCKET};

const PLUGIN_PATH := "res://addons/FlowField";
const HIGHLIGHT_COLOR := Color(0.20784313976765, 0.55686277151108, 1, 0.50196081399918);
const FADING_LENGTH : int = 5;

var _selected : FlowField2D = null;
var _bottom_panel : Control;

var _tool_type : TOOL = TOOL.NONE:
	set(val):
		_tool_type = val;
		_dragging = (val == TOOL.BUCKET);
		_bottom_panel._update_tool_type(val);
var _picker : bool = false;
var _eraser : bool = false;
var _color_type : FlowField2D.COLOR_PRESET = FlowField2D.COLOR_PRESET.GRAY_SCALE:
	set(val):
		_color_type = val;
		if _selected:
			_selected._color_type = val;
var _color_display : bool = true:
	set(val):
		_color_display = val;
		if _selected:
			_selected._show_in_color = val;
var _number : bool = false:
	set(val):
		_number = val;
		if _selected:
			_selected.display_numbers = val;
			_selected.queue_redraw();
var _arrow : bool = false:
	set(val):
		_arrow = val;
		if _selected:
			_selected.display_arrows = val;
			_selected.queue_redraw();
var _grid : bool = true:
	set(val):
		_grid = val;
		update_overlays();
var _set_bias : int = 1;
var _path_type : int = 0;

var _highlighted_tiles : Array[Vector2i] = [];
var _dragging : bool;
var _last_m_pos : Vector2i;
var _mid_rect_pos : Vector2i

var _visible : bool = false;
var _erase : bool = false;

func _enter_tree():
	add_custom_type("FlowField2D", "Node2D", preload(PLUGIN_PATH + "/src/flow_field/flow_field_2d.gd"), preload(PLUGIN_PATH + "/assets/flow_field.svg"));
	
	_bottom_panel = preload(PLUGIN_PATH + "/src/flow_field/bottom_panel/bottom_panel.tscn").instantiate();
	var tool_children : Array[Node] = _bottom_panel.get_node("tools_buttons").get_children();
	
	tool_children[0].pressed.connect(_change_tool.bind(TOOL.SELECTION));
	tool_children[1].pressed.connect(_change_tool.bind(TOOL.PAINT));
	tool_children[2].pressed.connect(_change_tool.bind(TOOL.LINE));
	tool_children[3].pressed.connect(_change_tool.bind(TOOL.RECT));
	tool_children[4].pressed.connect(_change_tool.bind(TOOL.BUCKET));
	
	tool_children[6].value_changed.connect(_change_bias);
	
	tool_children[8].toggled.connect(_change_picker);
	tool_children[9].toggled.connect(_change_eraser);
	
	tool_children[11].item_selected.connect(_color_type_changed);
	tool_children[12].toggled.connect(_color_changed);
	
	tool_children[14].toggled.connect(_change_arrow);
	tool_children[15].toggled.connect(_change_number);
	tool_children[16].toggled.connect(_change_grid);

func _exit_tree():
	remove_custom_type("FlowField2D");
	remove_control_from_bottom_panel(_bottom_panel);
	_bottom_panel.queue_free();

func _handles(object):
	return object is FlowField2D;

func _edit(object: Object) -> void:
	if object == null:
		if _selected != null:
			# Deselect already selected flow field
			remove_control_from_bottom_panel(_bottom_panel);
			
			_selected._display_alpha = 0.2;
			_selected = null;
	elif _selected == null:
		# Selects a new flow field when non is already selected
		add_control_to_bottom_panel(_bottom_panel, "FlowField").toggled.connect(_change_visible);
		make_bottom_panel_item_visible(_bottom_panel);
		_update_buttons();
		
		_set_selected(object);
	elif not _selected in EditorInterface.get_selection().get_selected_nodes():
		# Changes selected flow field
		_selected._display_alpha = 0.2;
		_set_selected(object);
	update_overlays();

func _set_selected(object : FlowField2D) -> void:
	if _dragging:
		_end_drag();
	_selected = object;
	_selected._display_alpha = 0.8;
	_selected._show_in_color = _color_display;
	_selected._color_type = _color_type;
	if _selected.display_numbers != _number || _selected.display_arrows != _arrow:
		_selected.display_numbers = _number;
		_selected.display_arrows = _arrow;

func _update_buttons() -> void:
	# Called once when selecting a flow field. It ensures that, even when undo/redo is done,
	# all the buttons are correct
	var tool_children : Array[Node] = _bottom_panel.get_node("tools_buttons").get_children();
	
	if _tool_type == TOOL.NONE:
		var button : Button = tool_children[0].button_group.get_pressed_button();
		if button:
			button.set_pressed_no_signal(false);
	else:
		tool_children[_tool_type].set_pressed_no_signal(true);
	_bottom_panel._update_tool_type(_tool_type);
	
	tool_children[6].set_value_no_signal(_set_bias);
	
	tool_children[8].set_pressed_no_signal(_picker);
	tool_children[9].set_pressed_no_signal(_eraser);
	
	tool_children[11].selected = _color_type;
	tool_children[12].set_pressed_no_signal(_color_display);
	
	tool_children[14].set_pressed_no_signal(_arrow);
	tool_children[15].set_pressed_no_signal(_number);
	tool_children[16].set_pressed_no_signal(_grid);

func _change_visible(toggle : bool) -> void:
	# Disables display (grid) when not on the flowfield tab
	_visible = toggle;
	update_overlays();

func _change_tool(tool_type : int) -> void:
	_tool_type = tool_type;
func _change_picker(picker : bool) -> void:
	_picker = picker;
func _change_eraser(eraser : bool) -> void:
	_eraser = eraser;
func _color_type_changed(color_type : FlowField2D.COLOR_PRESET) -> void:
	_color_type = color_type;
func _color_changed(color : bool) -> void:
	_color_display = color;
func _change_number(number : bool) -> void:
	_number = number;
func _change_arrow(arrow : bool) -> void:
	_arrow = arrow;
func _change_grid(grid : bool) -> void:
	_grid = grid;
func _change_bias(bias : int) -> void:
	_set_bias = bias;

func _forward_canvas_gui_input(event):
	if _visible && _selected && event is InputEventMouse:
		if _selected.field_set:
			# If dragging, and mouse moved, update the drag
			if event is InputEventMouseMotion:
				if _dragging && _tool_type > TOOL.SELECTION:
					_update_drag();
			
			# Handles start/end drag and destination preview change
			if event is InputEventMouseButton && (event.button_index == MOUSE_BUTTON_LEFT || event.button_index == MOUSE_BUTTON_RIGHT):
				if _tool_type == TOOL.SELECTION && event.is_pressed():
					var tile_pos : Vector2 = (_selected.get_local_mouse_position() / _selected.field_set.tileSize).floor();
					if _selected.field_set.has_tile(tile_pos):
						if _change_arrow:
							_selected.destination = tile_pos;
							_selected.queue_redraw();
						else:
							_selected._destination = tile_pos;
				else:
					_erase = (event.button_index == MOUSE_BUTTON_RIGHT);
					
					if event.is_pressed():
						_begin_drag();
						_update_drag();
					elif event.is_released():
						_end_drag();
			
			update_overlays();
			return true;
	return false;

func _forward_canvas_draw_over_viewport(viewport: Control) -> void:
	if !_visible:
		return;
	var field_set : FieldSet2D = _selected.field_set;
	
	# Nothing if there is no field
	if field_set:
		# Gets transform
		var xform : Transform2D = _selected.get_viewport_transform() * _selected.get_canvas_transform() * _selected.get_global_transform();
		viewport.draw_set_transform_matrix(xform);
		
		var tileSize : Vector2 = field_set.tileSize;
		var mousePos : Vector2 = (_selected.get_local_mouse_position() / tileSize).floor() * tileSize;
		
		# Draws grid
		if _grid:
			var drawn_grid_rect : Rect2i = field_set.get_used_rect();
			
			if drawn_grid_rect.size.x > 0 && drawn_grid_rect.size.y > 0:
				var grid_color : Color = Color.CRIMSON;
				drawn_grid_rect = drawn_grid_rect.grow(FADING_LENGTH);
				
				for x in drawn_grid_rect.size.x:
					for y in drawn_grid_rect.size.y:
						var pos_in_rect : Vector2 = Vector2(x, y);
						
						var left_opacity : float = clampf(inverse_lerp(0, float(FADING_LENGTH), pos_in_rect.x), 0.0, 1.0);
						var right_opacity : float = clampf(inverse_lerp(float(drawn_grid_rect.size.x), float(drawn_grid_rect.size.x - FADING_LENGTH), (pos_in_rect.x + 1.0)), 0.0, 1.0);
						var top_opacity : float = clampf(inverse_lerp(0.0, float(FADING_LENGTH), pos_in_rect.y), 0.0, 1.0);
						var bottom_opacity : float = clampf(inverse_lerp(float(drawn_grid_rect.size.y), float(drawn_grid_rect.size.y - FADING_LENGTH), (pos_in_rect.y + 1.0)), 0.0, 1.0);
						var opacity : float = clampf(min(left_opacity, right_opacity, top_opacity, bottom_opacity) + 0.1, 0.0, 1.0);
						
						var color : Color = grid_color;
						color.a = color.a * opacity;
						
						viewport.draw_rect(Rect2((pos_in_rect + Vector2(drawn_grid_rect.position)) * tileSize, tileSize), color, false);
		
		# Draw highlighted
		if _tool_type > TOOL.SELECTION:
			var tile_rect : Rect2 = Rect2(Vector2.ZERO, tileSize);
			
			for tile_pos : Vector2i in _highlighted_tiles:
				tile_rect.position = Vector2(tile_pos.x, tile_pos.y) * tileSize;
				viewport.draw_rect(tile_rect, HIGHLIGHT_COLOR);
		
		# Draw cursor
		viewport.draw_rect(Rect2(mousePos, tileSize), Color.RED, false);
		
		# Resets transform
		viewport.draw_set_transform_matrix(Transform2D());

func _begin_drag() -> void:
	_dragging = true;
	_last_m_pos = (_selected.get_local_mouse_position() / _selected.field_set.tileSize).floor();
	_mid_rect_pos = _last_m_pos;

func _update_drag() -> void:
	var current_tile_pos : Vector2i = (_selected.get_local_mouse_position() / _selected.field_set.tileSize).floor();
	
	match _tool_type:
		TOOL.PAINT:
			for tile_pos in _bresenham_line_highlight(_last_m_pos, current_tile_pos):
				if not tile_pos in _highlighted_tiles:
					_highlighted_tiles.append(tile_pos);
			_last_m_pos = current_tile_pos;
		TOOL.LINE:
			_highlighted_tiles = _bresenham_line_highlight(_last_m_pos, current_tile_pos);
		TOOL.RECT:
			_highlighted_tiles.clear();
			_get_rect_highlight(_last_m_pos, current_tile_pos);
		TOOL.BUCKET:
			_get_bucket_highlight(current_tile_pos);

func _end_drag() -> void:
	_dragging = (_tool_type == TOOL.BUCKET);
	
	if _highlighted_tiles.size() > 0:
		var field_set : FieldSet2D = _selected.field_set;
		var undo_redo : EditorUndoRedoManager = get_undo_redo();
		
		undo_redo.create_action("Paint tiles");
		
		# Erases or creates tiles. Undo/redo is added appropriately
		if _erase || _eraser:
			for pos : Vector2i in _highlighted_tiles:
				undo_redo.add_do_method(field_set, "remove_tile", pos, false);
				if field_set.has_tile(pos):
					undo_redo.add_undo_method(field_set, "set_tile", pos, field_set.get_bias(pos));
			undo_redo.add_do_method(field_set, "update_size");
		else:
			for pos : Vector2i in _highlighted_tiles:
				undo_redo.add_do_method(field_set, "set_tile", pos, _set_bias);
				if field_set.has_tile(pos):
					undo_redo.add_undo_method(field_set, "set_tile", pos, field_set.get_bias(pos));
				else:
					undo_redo.add_undo_method(field_set, "remove_tile", pos, false);
			undo_redo.add_undo_method(field_set, "update_size");
		
		_highlighted_tiles.clear();
		undo_redo.commit_action();

func _bresenham_line_highlight(p_start : Vector2i, p_end : Vector2i) -> Array[Vector2i]:
	var ret : Array[Vector2i] = [];
	var delta : Vector2i = (p_end - p_start).abs() * 2;
	var step : Vector2i = (p_end - p_start).sign();
	var current : Vector2i = p_start;
	
	if delta.x > delta.y:
		var err : int = delta.x / 2;
		
		while current.x != p_end.x:
			ret.append(current);
		
			err -= delta.y;
			if err < 0:
				current.y += step.y;
				err += delta.x;
			current.x += step.x
	else:
		var err : int = delta.y / 2;
		
		while current.y != p_end.y:
			ret.append(current);
			
			err -= delta.x;
			if err < 0:
				current.x += step.x;
				err += delta.y;
			current.y += step.y
	
	ret.append(current);
	return ret;

func _get_rect_highlight(start : Vector2i, end : Vector2i) -> void:
	# Make this better
	
	var offset : Vector2i = Vector2i(min(start.x, end.x), min(start.y, end.y));
	var rect_size : Vector2i = (start - end).abs() + Vector2i.ONE;
	
	for y in rect_size.y:
		for x in rect_size.x:
			_highlighted_tiles.append(Vector2i(x, y) + offset);

func _get_bucket_highlight(check_pos : Vector2i) -> void:
	if _highlighted_tiles.has(check_pos):
		return;
	_highlighted_tiles.clear();
	
	var tiles : Dictionary = _selected.field_set._flowFieldPattern;
	
	var bound_rect : Rect2i = _selected.field_set.get_used_rect();
	bound_rect.size += Vector2i.ONE;
	
	var queue : Array[Vector2i] = [check_pos];
	
	if tiles.has(check_pos):
		var bias : float = tiles[check_pos].bias;
		while queue.size() > 0:
			var current : Vector2i = queue.pop_back();
			if !tiles.has(current) || tiles[current].bias != bias || _highlighted_tiles.has(current):
				continue;
			if !bound_rect.has_point(current):
				continue;
			
			_highlighted_tiles.append(current);
			for offset : Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				queue.append(current + offset);
	else:
		while queue.size() > 0:
			var current : Vector2i = queue.pop_back();
			if tiles.has(current) || _highlighted_tiles.has(current):
				continue;
			if !bound_rect.has_point(current):
				continue;
			
			_highlighted_tiles.append(current);
			for offset : Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				queue.append(current + offset);
