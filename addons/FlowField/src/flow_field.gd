@tool
class_name FlowField extends Node2D

enum FLOWFIELD_TYPE {Square};

const FALL_BACK_COLOR : Color = Color(0, 0.50980395078659, 1);

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
@export_group("Display")
@export var show_in_color : bool = true:
	set(val):
		if !is_inside_tree():
			await ready;
		
		show_in_color = val;
		queue_redraw();
		notify_property_list_changed();
var heatmap : bool = true:
	set(val):
		if !is_inside_tree():
			await ready;
		
		heatmap = val;
		queue_redraw();
		notify_property_list_changed();
var exact_coloring : bool = false:
	set(val):
		exact_coloring = val;
		if !is_inside_tree():
			await ready;
			
		_get_highlight_colors();
		queue_redraw();
		notify_property_list_changed();
var gradient : Gradient:
	set(val):
		if gradient:
			gradient.changed.disconnect(_changed);
		
		if val == null:
			gradient = _get_default_gradient();
		else:
			gradient = val;
		
		gradient.changed.connect(_changed);
		_changed();

var _highlight_colors : Dictionary;
var highlight_colors : Dictionary:
	get:
		return _highlight_colors;
	set(val):
		if !is_inside_tree():
			await ready;
		
		_fix_highlight_colors(val);
		queue_redraw();
var display_numbers : bool = false:
	set(val):
		display_numbers = val;
		queue_redraw();

func _get_property_list():
	var properties = []
	properties.append({
		"name": "heatmap",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_STORAGE | (int(show_in_color) * PROPERTY_USAGE_EDITOR)
	})
	properties.append({
		"name": "exact_coloring",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_STORAGE | (int(heatmap) * PROPERTY_USAGE_EDITOR)
	})
	properties.append({
		"name": "highlight_colors",
		"type": TYPE_DICTIONARY,
		"usage": (int(heatmap && show_in_color && exact_coloring) * PROPERTY_USAGE_DEFAULT)
	});
	properties.append({
		"name": "gradient",
		"type": TYPE_OBJECT,
		"usage": (int(heatmap && show_in_color && !exact_coloring) * PROPERTY_USAGE_DEFAULT),
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "Gradient",
	});
	properties.append({
		"name": "display_numbers",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT,
	});
	
	return properties

func _property_can_revert(property: StringName) -> bool:
	match property:
		"gradient":
			return true;
	return false;

func _property_get_revert(property: StringName) -> Variant:
	match property:
		"gradient":
			return _get_default_gradient();
	return null;

static var _default_font : Font;

signal changed();

func _ready() -> void:
	if !_default_font:
		_default_font = SystemFont.new();
	
	if !is_instance_valid(gradient):
		gradient = null;
	_get_highlight_colors();

func _changed() -> void:
	if heatmap:
		if exact_coloring:
			_fix_highlight_colors(_highlight_colors.duplicate());
		else:
			_get_highlight_colors();
	queue_redraw();
	changed.emit();

func _get_default_gradient() -> Gradient:
	var grd = Gradient.new();
	grd.colors = PackedColorArray([
		Color(0, 0, 0),
		Color(1, 0.20784313976765, 0.20784313976765),
		Color(1, 0.45882353186607, 0),
		Color(1, 1, 0),
		Color(0, 1, 0),
		Color(0, 0, 1),
		Color(0.56078433990479, 0, 0.56078433990479),
		Color(1, 1, 1),
	]);
	grd.offsets = PackedFloat32Array([
		0.0,
		0.143,
		0.286,
		0.429,
		0.571,
		0.714,
		0.857,
		1.0,
	])
	return grd;

func _get_highlight_colors() -> void:
	var nums : Array[int] = field_set.get_all_different_baises();
	nums.sort();
	_highlight_colors.clear();
	
	if nums.is_empty():
		queue_redraw();
		return;
	
	var low : float = nums.front();
	var high : float = nums.back() - low;
	
	if high == 0:
		high = 0.001;
	for num in nums:
		_highlight_colors[num] = gradient.sample((num - low) / high);

func _fix_highlight_colors(apply : Dictionary = Dictionary()) -> void:
	if apply.is_empty():
		_get_highlight_colors();
	
	var nums : Array[int] = field_set.get_all_different_baises();
	nums.sort();
	_highlight_colors.clear();
	
	if nums.is_empty():
		return;
	
	var low : float = nums.front();
	var high : float = nums.back() - low;
	
	for num in nums:
		if apply.has(num):
			var c = apply[num];
			if c is Color:
				_highlight_colors[num] = c;
				continue;
		
		_highlight_colors[num] = gradient.sample((num - low) / high);

func _draw() -> void:
	print("redraw")
	
	var tiles = field_set._flowFieldPattern
	var tileSize : Vector2 = field_set.tileSize
	var tile_rect : Rect2 = Rect2(Vector2.ZERO, tileSize);
	
	if show_in_color:
		if heatmap:
			for pos : Vector2i in tiles:
				tile_rect.position = Vector2(pos) * tileSize;
				
				draw_rect(tile_rect, _highlight_colors[tiles[pos].bias], true);
		else:
			for pos : Vector2i in tiles:
				tile_rect.position = Vector2(pos) * tileSize;
				
				draw_rect(tile_rect, FALL_BACK_COLOR, true);
	elif !display_numbers:
		for pos : Vector2i in tiles:
			tile_rect.position = Vector2(pos) * tileSize;
			
			draw_rect(tile_rect, Color.YELLOW_GREEN, false);
	
	if display_numbers:
		for pos : Vector2i in tiles:
			var tileInfo = tiles[pos];
			
			var draw_str : String = str(tileInfo.bias);
			var draw_size : Vector2 = _default_font.get_string_size(draw_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 32);
			var scale_size : Vector2 = tileSize / (draw_size * 1.5);
			var scale : float = min(scale_size.x, scale_size.y);
			
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale, scale));
			var str_pos = (((Vector2(pos) * tileSize) + (tileSize * 0.5)) / scale) + Vector2(-draw_size.x * 0.5, draw_size.y * 0.25);
			draw_string(_default_font, str_pos, draw_str, HORIZONTAL_ALIGNMENT_RIGHT, -1, 32);
			draw_string_outline(_default_font, str_pos, draw_str, HORIZONTAL_ALIGNMENT_RIGHT, -1, 32, 2, Color.BLACK);
