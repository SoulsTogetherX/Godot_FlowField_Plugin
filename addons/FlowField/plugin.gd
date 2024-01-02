@tool
extends EditorPlugin

const PLUGIN_PATH := "res://addons/FlowField";
const HIGHLIGHT_COLOR := Color(0.20784313976765, 0.55686277151108, 1, 0.50196081399918);
const FADING_LENGTH : int = 5;

var _selected : FlowField2D = null;
var _bottom_panel : Control;

enum TOOL {SELECTION = 1, PAINT = 2, LINE = 4, RECT = 8, BUCKET = 16};
var _tool_type : TOOL = 0;
var _picker : bool = false;
var _eraser : bool = false;
var _color_type : FlowField2D.COLOR_PRESET = FlowField2D.COLOR_PRESET.GRAY_SCALE;
var _color_display : bool = true;
var _arrow : bool = false;
var _number : bool = false;
var _grid : bool = true;
var _set_bias : int = 1;
var _path_type : int = 0;

var _highlighted_tiles : Dictionary = {};
var _dragging : bool;
var _last_m_pos : Vector2i;
var _mid_rect_pos : Vector2i

var _visible : bool = false;
var _erase : bool = false;

func _enter_tree():
	add_custom_type("FlowField2D", "Node2D", preload(PLUGIN_PATH + "/src/flow_field/flow_field_2d.gd"), preload(PLUGIN_PATH + "/assets/flow_field.svg"));
	add_custom_type("FlowFieldNavigator", "Node2D", preload(PLUGIN_PATH + "/src/flow_field_navigator/flow_field_navigator.gd"), preload(PLUGIN_PATH + "/assets/flow_field_navigator.svg"));
	
	_bottom_panel = preload(PLUGIN_PATH + "/src/flow_field/bottom_panel/bottom_panel.tscn").instantiate();
	_bottom_panel.tool_type_changed.connect(_change_tool);
	_bottom_panel.picker_changed.connect(_change_picker);
	_bottom_panel.eraser_changed.connect(_change_eraser);
	_bottom_panel.color_type_changed.connect(_color_type_changed);
	_bottom_panel.color_changed.connect(_color_changed);
	_bottom_panel.arrow_changed.connect(_change_arrow);
	_bottom_panel.number_changed.connect(_change_number);
	_bottom_panel.grid_changed.connect(_change_grid);
	_bottom_panel.bias_changed.connect(_change_bias);

func _exit_tree():
	remove_custom_type("FlowField2D");
	remove_custom_type("FlowFieldNavigator");
	remove_control_from_bottom_panel(_bottom_panel);
	_bottom_panel.queue_free();

func _handles(object):
	return object is FlowField2D;

func _edit(object: Object) -> void:
	if object == null:
		if _selected != null:
			remove_control_from_bottom_panel(_bottom_panel);
			
			_selected.self_modulate.a = 0.2;
			_selected = null;
	elif _selected == null:
		add_control_to_bottom_panel(_bottom_panel, "FlowField").toggled.connect(_change_visible);
		make_bottom_panel_item_visible(_bottom_panel);
		
		_set_selected(object);
	elif not _selected in EditorInterface.get_selection().get_selected_nodes():
		_selected.self_modulate.a = 0.2;
		_set_selected(object);
	update_overlays();

func _set_selected(object : FlowField2D) -> void:
	if _dragging:
		_end_drag();
	_selected = object;
	_selected.self_modulate.a = 0.8;
	_selected._show_in_color = _color_display;
	_selected._color_type = _color_type;
	if _selected.display_numbers != _number || _selected.display_arrows != _arrow:
		_selected.display_numbers = _number;
		_selected.display_arrows = _arrow;
		_selected.queue_redraw();

func _change_visible(toggle : bool) -> void:
	_visible = toggle;
	if _selected:
		_selected.queue_redraw();
	update_overlays();

func _change_tool(tool_type : int) -> void:
	_tool_type = tool_type;

func _change_picker(picker : bool) -> void:
	_picker = picker;

func _change_eraser(eraser : bool) -> void:
	_eraser = eraser;

func _change_number(number : bool) -> void:
	_number = number;
	if _selected:
		_selected.display_numbers = number;
		_selected.queue_redraw();

func _change_arrow(arrow : bool) -> void:
	_arrow = arrow;
	if _selected:
		_selected.display_arrows = arrow;
		_selected.queue_redraw();

func _color_type_changed(color_type : FlowField2D.COLOR_PRESET) -> void:
	_color_type = color_type;
	if _selected:
		_selected._color_type = color_type;

func _color_changed(color : bool) -> void:
	_color_display = color;
	if _selected:
		_selected._show_in_color = color;

func _change_grid(grid : bool) -> void:
	_grid = grid;
	update_overlays();

func _change_bias(bias : int) -> void:
	_set_bias = bias;

func _forward_canvas_gui_input(event):
	if _visible && _selected && event is InputEventMouse:
		if _selected.field_set:
			if event is InputEventMouseMotion:
				if _dragging && _tool_type > TOOL.SELECTION:
					_update_drag();
			
			if event is InputEventMouseButton && (event.button_index == MOUSE_BUTTON_LEFT || event.button_index == MOUSE_BUTTON_RIGHT):
				if _tool_type == TOOL.SELECTION:
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
	
	if field_set:
		var xform : Transform2D = _selected.get_viewport_transform() * _selected.get_canvas_transform();
		viewport.draw_set_transform_matrix(xform);
		
		var tileSize : Vector2 = field_set.tileSize;
		var mousePos : Vector2 = (_selected.get_local_mouse_position() / tileSize).floor() * tileSize;
		
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
			_draw_highlight(viewport, tileSize);
		
		# Draw cursor
		viewport.draw_rect(Rect2(mousePos, tileSize), Color.RED, false);
		
		viewport.draw_set_transform_matrix(Transform2D());

func _draw_highlight(viewport: Control, tileSize : Vector2) -> void:
	var tile_rect : Rect2 = Rect2(Vector2.ZERO, tileSize);
	
	for tile_pos : Vector2i in _highlighted_tiles.keys():
		tile_rect.position = Vector2(tile_pos.x, tile_pos.y) * tileSize;
		viewport.draw_rect(tile_rect, HIGHLIGHT_COLOR);

#func _draw_tile_at(draw_at : Vector2i) -> void:
	#var draw_pos_base : Vector2 = (Vector2(draw_at) + Vector2.DOWN) * _tileSize;
	#var tile : Tile = _chunk.getTileAt(draw_at);
#
	#var draw_str : String = str(tile.bais) if tile else "N/A";
	#var draw_size : Vector2 = _default_font.get_string_size(draw_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 32);
	#var scale_size : Vector2 = _tileSize / (draw_size * 2);
	#if scale_size.x > scale_size.y:
		#scale_size.x = scale_size.y;
	#else:
		#scale_size.y = scale_size.x;
	#draw_set_transform(position, 0, scale_size);
	#draw_string(_default_font, draw_pos_base / scale_size + Vector2(0, -2), draw_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 32);
#
	#draw_str = str(tile.value) if tile else "N/A";
	#draw_size = _default_font.get_string_size(draw_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 32);
	#scale_size = _tileSize / (draw_size * 2);
	#if scale_size.x > scale_size.y:
		#scale_size.x = scale_size.y;
	#else:
		#scale_size.y = scale_size.x;
	#draw_set_transform(position, 0, scale_size);
	#draw_string(_default_font, ((draw_pos_base + Vector2(_tileSize.x, -_tileSize.y)) / scale_size) + Vector2(-draw_size.x, draw_size.y - 20), draw_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 32);

func _begin_drag() -> void:
	_dragging = true;
	_last_m_pos = (_selected.get_local_mouse_position() / _selected.field_set.tileSize).floor();
	_mid_rect_pos = _last_m_pos;

func _update_drag() -> void:
	var current_tile_pos : Vector2i = (_selected.get_local_mouse_position() / _selected.field_set.tileSize).floor();
	
	match _tool_type:
		TOOL.PAINT:
			_bresenham_line_highlight(_last_m_pos, current_tile_pos);
			_last_m_pos = current_tile_pos;
		TOOL.LINE:
			_highlighted_tiles.clear();
			_bresenham_line_highlight(_last_m_pos, current_tile_pos);
		TOOL.RECT:
			# Make this better
			_highlighted_tiles.clear();
			
			var offset : Vector2i = Vector2i(min(_last_m_pos.x, current_tile_pos.x), min(_last_m_pos.y, current_tile_pos.y));
			var rect_size : Vector2i = (_last_m_pos - current_tile_pos).abs() + Vector2i.ONE;
			
			for y in rect_size.y:
				for x in rect_size.x:
					var look_up_pos : Vector2i = Vector2i(x, y) + offset;
					if !_highlighted_tiles.has(look_up_pos):
						_highlighted_tiles[look_up_pos] = FlowFieldTile2D.new().set_bias(_set_bias);
			
			_mid_rect_pos = current_tile_pos;
		TOOL.BUCKET:
			if !_highlighted_tiles.has(current_tile_pos):
				if _selected.field_set.has_tile(current_tile_pos):
					return;
				
				_highlighted_tiles.clear();
				var bound_rect : Rect2i = _selected.field_set.get_used_rect();

func _end_drag() -> void:
	_dragging = false;
	
	if _erase  || _eraser:
		_selected.field_set.remove_tiles(_highlighted_tiles);
	else:
		_selected.field_set.set_tiles(_highlighted_tiles);
	_highlighted_tiles.clear();

func _bresenham_line_highlight(p_start : Vector2i, p_end : Vector2i) -> void:
	var delta : Vector2i = (p_end - p_start).abs() * 2;
	var step : Vector2i = (p_end - p_start).sign();
	var current : Vector2i = p_start;
	
	if delta.x > delta.y:
		var err : int = delta.x / 2;
		
		while current.x != p_end.x:
			if !_highlighted_tiles.has(current):
				_highlighted_tiles[current] = FlowFieldTile2D.new().set_bias(_set_bias);
		
			err -= delta.y;
			if err < 0:
				current.y += step.y;
				err += delta.x;
			current.x += step.x
	else:
		var err : int = delta.y / 2;
		
		while current.y != p_end.y:
			if !_highlighted_tiles.has(current):
				_highlighted_tiles[current] = FlowFieldTile2D.new().set_bias(_set_bias);
			
			err -= delta.x;
			if err < 0:
				current.x += step.x;
				err += delta.y;
			current.y += step.y
	
	if !_highlighted_tiles.has(current):
		_highlighted_tiles[current] = FlowFieldTile2D.new().set_bias(_set_bias);
