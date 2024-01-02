@tool
class_name FlowField2D extends Node2D

enum FLOWFIELD_TYPE {Square};
enum COST_CHECK {Best, Worst};
enum COLOR_PRESET {GRAY_SCALE = 0, BLUE_SCALE, HEAT_MAP, RAINBOW_SEVEN, RAINBOW_TEN, FLAT = 6, CUSTOM, EXACT};

const INT_MAX : int = 9223372036854775807;
const FALL_BACK_COLOR : Color = Color.CORNFLOWER_BLUE;
const ARROW_IMAGE_TEXTURE : CompressedTexture2D = preload("res://addons/FlowField/assets/arrow_big.svg");

@export var flow_type : FLOWFIELD_TYPE;
@export var cost_check : COST_CHECK;

@export var field_set : FieldSet2D:
	set(val):
		if field_set == val:
			return;
		
		if field_set:
			field_set.changed.disconnect(_changed);
		if val:
			val.changed.connect(_changed);
		
		field_set = val;

@export_group("Display")
var _flat_color : Color = FALL_BACK_COLOR:
	set(val):
		_flat_color = val;
		queue_redraw();
var _gradient : Gradient:
	set(val):
		if _gradient:
			_gradient.changed.disconnect(queue_redraw);
		
		_gradient = val;
		if val != null:
			_gradient.changed.connect(queue_redraw);
		
		_changed();

var _highlight : Dictionary;
var _highlight_colors : Dictionary:
	get:
		return _highlight;
	set(val):
		if !is_inside_tree():
			await ready;
		
		_fix_highlight_colors(val);
		queue_redraw();

var _show_in_color : bool = false:
	set(val):
		_show_in_color = val;
		if val == true:
			if _color_type < COLOR_PRESET.CUSTOM:
				_gradient = _get_default_gradient();
			_get_highlight_colors();
		queue_redraw();
var _color_type : COLOR_PRESET = COLOR_PRESET.GRAY_SCALE:
	set(val):
		_color_type = val;
		if _show_in_color:
			if _color_type < COLOR_PRESET.CUSTOM:
				_gradient = _get_default_gradient();
			notify_property_list_changed();
			queue_redraw();

var display_arrows : bool = false;
var display_numbers : bool = false;

var _destination : Vector2i = Vector2i.ONE;
var destination : Vector2i:
	get:
		return _destination;
	set(val):
		set_destination(val);

func _get_property_list():
	var properties = [];
	
	properties.append({
		"name": "_show_in_color",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_STORAGE
	});
	properties.append({
		"name": "_color_type",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_STORAGE,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "GRAY_SCALE, RED_SCALE, BLUE_SCALE, RAINBOW, FLAT, CUSTOM, EXACT",
	});
	
	if _color_type >= COLOR_PRESET.FLAT:
		match _color_type:
			COLOR_PRESET.FLAT:
				properties.append({
					"name": "_flat_color",
					"type": TYPE_COLOR,
					"usage": PROPERTY_USAGE_DEFAULT
				});
			COLOR_PRESET.CUSTOM:
				properties.append({
					"name": "_gradient",
					"type": TYPE_OBJECT,
					"usage": PROPERTY_USAGE_DEFAULT,
					"hint": PROPERTY_HINT_RESOURCE_TYPE,
					"hint_string": "Gradient"
				});
			COLOR_PRESET.EXACT:
				properties.append({
					"name": "_highlight_colors",
					"type": TYPE_DICTIONARY,
					"usage": PROPERTY_USAGE_DEFAULT
				});
	 
	return properties

func _property_can_revert(property: StringName) -> bool:
	match property:
		"_gradient":
			return true;
	return false;

func _property_get_revert(property: StringName) -> Variant:
	match property:
		"_gradient":
			return _get_default_gradient();
	return null;

static var _default_font : Font;

signal changed();

func _ready() -> void:
	if !_default_font:
		_default_font = SystemFont.new();
	
	set_destination(Vector2i.ZERO);

func _changed() -> void:
	if _color_type != COLOR_PRESET.FLAT:
		if _color_type == COLOR_PRESET.EXACT:
			_fix_highlight_colors(_highlight.duplicate());
		else:
			_get_highlight_colors();
	queue_redraw();
	changed.emit();

func _get_default_gradient() -> Gradient:
	var grd = Gradient.new();
	
	match _color_type:
		COLOR_PRESET.GRAY_SCALE:
			grd.colors = PackedColorArray([
				Color(0, 0, 0),
				Color(1, 1, 1),
			]);
			grd.offsets = PackedFloat32Array([
				0.0,
				1.0,
			])
		COLOR_PRESET.BLUE_SCALE:
			grd.colors = PackedColorArray([
				Color(0, 0, 1),
				Color(0, 1, 1),
			]);
			grd.offsets = PackedFloat32Array([
				0.0,
				1.0,
			])
		COLOR_PRESET.HEAT_MAP:
			grd.colors = PackedColorArray([
				Color(0, 1, 0),
				Color(1, 1, 0),
				Color(1, 0, 0),
			]);
			grd.offsets = PackedFloat32Array([
				0.0,
				0.5,
				1.0,
			])
		COLOR_PRESET.RAINBOW_SEVEN:
			grd.colors = PackedColorArray([
				Color(1, 0, 0),
				Color(1, 0.5, 0),
				Color(1, 1, 0),
				Color(0, 1, 0),
				Color(0, 0, 1),
				Color(0.5, 0, 0.5),
			]);
			grd.offsets = PackedFloat32Array([
				0.0,
				0.2,
				0.4,
				0.6,
				0.8,
				1.0,
			])
		_:
		# RAINBOW_TEN, CUSTOM, EXACT
			grd.colors = PackedColorArray([
				Color(0, 0, 0),
				Color(1, 0, 0),
				Color(1, 0.5, 0),
				Color(1, 1, 0),
				Color(0, 1, 0),
				Color(0, 0, 1),
				Color(0.5, 0, 0.5),
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
	_highlight.clear();
	
	if nums.is_empty():
		queue_redraw();
		return;
	
	var low : float = nums.front();
	var high : float = nums.back() - low;
	
	if high == 0:
		high = 0.001;
	for num in nums:
		_highlight[num] = _gradient.sample((num - low) / high);

func _fix_highlight_colors(apply : Dictionary = Dictionary()) -> void:
	if apply.is_empty():
		_get_highlight_colors();
	
	var nums : Array[int] = field_set.get_all_different_baises();
	nums.sort();
	_highlight.clear();
	
	for num in nums:
		if apply.has(num):
			var c = apply[num];
			if c is Color:
				_highlight[num] = c;
				continue;
		
		_highlight[num] = Color(randf(), randf(), randf());

func _assign_all_max() -> void:
	var tiles = field_set._flowFieldPattern;
	for tile in tiles.values():
		tile._value = INT_MAX;

func set_destination(dest : Vector2i) -> void:
	var tiles = field_set._flowFieldPattern;
	if tiles.is_empty():
		return;
	if !tiles.has(dest):
		dest = tiles.keys()[0];
	if _destination == dest:
		return;
	
	_destination = dest;
	_assign_all_max();
	
	var queue : Array[Vector2i] = [destination];
	
	tiles[destination]._value = tiles[destination].bias;
	while queue.size() > 0:
		var consider : Vector2i = queue.pop_front();
		var value : int = tiles[consider]._value;
		
		for offset : Vector2i in [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN]:
			if tiles.has(consider + offset) && tiles[consider + offset]._set_value(value):
				queue.push_back(consider + offset);
	
	for tile_pos in tiles.keys():
		var best_value : int = INT_MAX;
		var best_offset : Vector2 = Vector2.ZERO;
		for offset : Vector2i in [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN]:
			if tiles.has(offset + tile_pos):
				if best_value > tiles[offset + tile_pos]._value:
					best_value = tiles[offset + tile_pos]._value;
					best_offset = Vector2(offset).normalized();
			
		tiles[tile_pos].best_direction = best_offset;
	tiles[destination].best_direction = Vector2.ZERO;

func _draw() -> void:
	var tiles = field_set._flowFieldPattern
	var tileSize : Vector2 = field_set.tileSize
	var tile_rect : Rect2 = Rect2(Vector2.ZERO, tileSize);
	
	if _show_in_color:
		if _color_type == COLOR_PRESET.FLAT:
			for pos : Vector2i in tiles:
				tile_rect.position = Vector2(pos) * tileSize;
				
				draw_rect(tile_rect, _flat_color, true);
		else:
			for pos : Vector2i in tiles:
				tile_rect.position = Vector2(pos) * tileSize;
				
				draw_rect(tile_rect, _highlight[tiles[pos].bias], true);
	
	elif !display_numbers:
		for pos : Vector2i in tiles:
			tile_rect.position = Vector2(pos) * tileSize;
			
			draw_rect(tile_rect, Color.YELLOW_GREEN, false);
	
	if display_arrows:
		var draw_rect : Rect2;
		if tileSize.min_axis_index() == Vector2.AXIS_X:
			var arrow_size := Vector2(tileSize.x, tileSize.x);
			draw_rect = Rect2(-arrow_size * 0.5, arrow_size);
		else:
			var arrow_size := Vector2(tileSize.y, tileSize.y);
			draw_rect = Rect2(-arrow_size * 0.5, arrow_size);
		
		var temp_tile : FlowFieldTile2D = tiles[destination];
		tiles.erase(destination)
		for pos : Vector2i in tiles.keys():
			var angle : float = tiles[pos].best_direction.angle()
			
			draw_set_transform((Vector2(pos) + Vector2(0.5, 0.5)) * tileSize, angle, Vector2.ONE);
			draw_texture_rect(ARROW_IMAGE_TEXTURE, draw_rect, false);
		tiles[destination] = temp_tile;
		
		draw_set_transform((Vector2(destination) + Vector2(0.5, 0.5)) * tileSize, 0, Vector2.ONE);
		draw_circle(Vector2.ZERO, draw_rect.position.x * 0.85, Color.BLACK);
		draw_circle(Vector2.ZERO, draw_rect.position.x * 0.8, Color.WHITE);
	
	if display_numbers:
		for pos : Vector2i in tiles:
			var tileInfo : FlowFieldTile2D = tiles[pos];
			
			var draw_str : String = str(tileInfo.bias);
			var draw_size : Vector2 = _default_font.get_string_size(draw_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 32);
			var scale_size : Vector2 = tileSize / (draw_size * 1.5);
			var scale : float = min(scale_size.x, scale_size.y);
			
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale, scale));
			var str_pos : Vector2 = (((Vector2(pos) * tileSize) + (tileSize * 0.5)) / scale) + Vector2(-draw_size.x * 0.5, draw_size.y * 0.25);
			draw_string(_default_font, str_pos, draw_str, HORIZONTAL_ALIGNMENT_RIGHT, -1, 32);
			draw_string_outline(_default_font, str_pos, draw_str, HORIZONTAL_ALIGNMENT_RIGHT, -1, 32, 2, Color.BLACK);
