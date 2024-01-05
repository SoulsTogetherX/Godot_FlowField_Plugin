@tool
## A Node for 2D-based flow fields.
## @experimental
class_name FlowField extends Node2D

## The method of convolution used to find the optimum path.
enum FLOWFIELD_TYPE {
	## All cardinal directions are considered equally
	Square,
	## All cardinal directions are considered 1, while all diagonals are 2
	Manhattan,
	## All 8 directions are considered equally
	Tchebychev,
	## All cardinal directions are considered 1, while all diagonal are sqrt(2)
	Euclidean
	};
## The method of determining the optimum cost after convolution
enum COST_CHECK {
	## Lower numbers are better (moves towards destination)
	Best = 1,
	## Higher numbers are better (moves away from destination)
	Worst = -1
};
## The color presents the tilemap will be shown in
## [br][br]
## [b]NOTE[/b]: Editor only.
enum COLOR_PRESET {
	## From Black to White
	GRAY_SCALE = 0,
	## From Blue to Cyan
	BLUE_SCALE,
	## From Green to Yellow to Red
	HEAT_MAP,
	## All colors of the rainbow
	RAINBOW_SEVEN,
	## All colors of the rainbow, sandwiched between white and black.
	RAINBOW_TEN,
	## Displays all tiles in the same color, designed by the user
	FLAT = 6,
	## A custom gradient decided by the user
	CUSTOM,
	## The user may color code any tile with a certain bias independently
	EXACT
	};

const _ARROW_IMAGE_TEXTURE : CompressedTexture2D = preload("res://addons/FlowField/assets/arrow_big.svg");

const _SQRT_TWO : float = sqrt(2);

## LEFT
const DIR_LEFT : Vector2i = Vector2i.LEFT;
## RIGHT
const DIR_RIGHT : Vector2i = Vector2i.RIGHT;
## UP
const DIR_UP : Vector2i = Vector2i.UP;
## DOWN
const DIR_DOWN : Vector2i = Vector2i.DOWN;

## TOP LEFT
const DIR_TOP_LEFT : Vector2i = Vector2i.LEFT + Vector2i.UP;
## TOP RIGHT
const DIR_TOP_RIGHT : Vector2i = Vector2i.RIGHT + Vector2i.UP;
## BOTTOM LEFT
const DIR_BOTTOM_LEFT : Vector2i = Vector2i.LEFT + Vector2i.DOWN;
## BOTTOM RIGHT
const DIR_BOTTOM_RIGHT : Vector2i = Vector2i.RIGHT + Vector2i.DOWN;

## Defines how a path will be calculated. See [enum FLOWFIELD_TYPE].
@export var flow_type : FLOWFIELD_TYPE:
	set(val):
		flow_type = val;
		if !field_set:
			return;
		_adjust_destination();
		queue_redraw();
## Defines how the cost of each tile will be examined in calculations. See [enum COST_CHECK].
@export var cost_check : COST_CHECK = COST_CHECK.Best:
	set(val):
		cost_check = val;
		if !field_set:
			return;
		_adjust_destination();
		queue_redraw();
## Holds all tile information. See [FieldSet].
@export var field_set : FieldSet:
	set(val):
		if field_set == val:
			return;
		
		if field_set:
			field_set.changed.disconnect(_changed);
		if val:
			val.changed.connect(_changed);
		
		field_set = val;
		queue_redraw();

@export_group("Display")
## Holds the color, that all tiles will be displayed in, when the current color pallet is COLOR_PRESET.FLAT.
## [br][br]
## [b]NOTE[/b]: Editor only.
var flat_color : Color = Color.CORNFLOWER_BLUE:
	set(val):
		flat_color = val;
		queue_redraw();
## Holds the gradient of colors the program will use to color the tiles, based on their biases.
## [br][br]
## [b]NOTE[/b]: There is not much point to manually editing this, but if you do, your changes will only matter if the
## current color pallet is COLOR_PRESET.CUSTOM. Otherwise, it may randomly get reset.
## [br][br]
## [b]NOTE[/b]: Editor only.
var gradient : Gradient:
	set(val):
		if gradient:
			gradient.changed.disconnect(queue_redraw);
		
		gradient = val;
		if val != null:
			gradient.changed.connect(queue_redraw);
		
		if field_set:
			_changed();

var _highlight : Dictionary;
## Holds the exact colors any tile, of each bias, will be displayed as. Keys are tile-bias floats, while the values are colors.
## [br][br]
## [b]NOTE[/b]: There is not much point to manually editing this, but if you do, your changes will only matter if the
## current color pallet is COLOR_PRESET.EXACT. Otherwise, it may randomly get reset.
## [br][br]
## [b]NOTE[/b]: Editor only.
var highlight_colors : Dictionary:
	get:
		return _highlight;
	set(val):
		if !is_inside_tree():
			await ready;
		
		_fix_highlight_colors(val);
		queue_redraw();

## If [code]true[/code], each tile will be displayed in a corresponding color.
## [br][br]
## [b]NOTE[/b]: Editor only.
var show_in_color : bool = false:
	set(val):
		show_in_color = val;
		if val == true:
			if color_pallet < COLOR_PRESET.CUSTOM:
				gradient = _get_default_gradient();
			_get_highlight_colors();
		queue_redraw();
## The current assigned color pallet the program will attempt to color the tiles in. See [enum COLOR_PRESET].
## [br][br]
## [b]NOTE[/b]: Editor only.
var color_pallet : COLOR_PRESET = COLOR_PRESET.GRAY_SCALE:
	set(val):
		color_pallet = val;
		if show_in_color:
			if color_pallet < COLOR_PRESET.CUSTOM:
				gradient = _get_default_gradient();
			notify_property_list_changed();
			queue_redraw();

## If [code]true[/code], each tile will have an arrow on it showcasing the best direction to move toward
## to reach the desired destination.
## [br][br]
## [b]NOTE[/b]: Editor only.
var display_arrows : bool = false:
	set(val):
		display_arrows = val;
		set_destination(_destination);
		queue_redraw();
## If [code]true[/code], each tile will have a number of it, displaying the tile's corresponding bias.
## [br][br]
## [b]NOTE[/b]: Editor only.
var display_numbers : bool = false;

var _destination : Vector2i = Vector2i.ONE;
## The desired destination the flow field will attempt to move towards or away from.
var destination : Vector2i:
	get:
		return _destination;
	set(val):
		set_destination(val);

var _display_alpha : float = 0.2;
static var _default_font : Font;

## Emitted when the [FieldSet] of this FlowField changes.
signal changed();
## Emitted when the flowfield is recalculated at any time.
signal recalculated();

func _ready() -> void:
	if !_default_font:
		_default_font = SystemFont.new();
	
	set_destination(Vector2i.ZERO);

func _changed() -> void:
	# updates colors, destination, and display when tile set changes
	if color_pallet != COLOR_PRESET.FLAT:
		if color_pallet == COLOR_PRESET.EXACT:
			_fix_highlight_colors(_highlight.duplicate());
		else:
			_get_highlight_colors();
	
	var tiles = field_set._flowFieldPattern;
	if !tiles.is_empty():
		if !tiles.has(destination):
			destination = tiles.keys()[0];
		_adjust_destination();
	
	queue_redraw();
	changed.emit();

func _get_property_list():
	var properties = [];
	
	properties.append({
		"name": "show_in_color",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_STORAGE
	});
	properties.append({
		"name": "color_pallet",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_STORAGE,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "GRAY_SCALE, RED_SCALE, BLUE_SCALE, RAINBOW, FLAT, CUSTOM, EXACT",
	});
	
	if color_pallet >= COLOR_PRESET.FLAT:
		match color_pallet:
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
					"name": "highlight_colors",
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

func _get_default_gradient() -> Gradient:
	# Gets the default color pattet when requested
	var grd = Gradient.new();
	
	match color_pallet:
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
	# Gets colors from color pallet gradient
	if !field_set:
		return;
	
	var nums : Array[float] = field_set.get_all_different_baises();
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
		_highlight[num] = gradient.sample((num - low) / high);

func _wash_highlight_colors() -> Dictionary:
	# Applies alpha modulation over each highlight color
	var ret : Dictionary = Dictionary();
	
	var c : Color = Color(1, 1, 1, _display_alpha);
	for bias in _highlight.keys():
		ret[bias] = _highlight[bias] * c;
	
	return ret;

func _fix_highlight_colors(apply : Dictionary = Dictionary()) -> void:
	# Ensures all selected highlight colors remain in order and a 1-1
	# correlation to the biases in the tile set.
	#
	# Note : This is mainly used for the "exact" color pallet
	if apply.is_empty():
		_get_highlight_colors();
	
	var nums : Array[float] = field_set.get_all_different_baises();
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
	# Used for calculations
	var tiles = field_set._flowFieldPattern;
	for tile in tiles.values():
		tile._value = INF;

func _adjust_destination() -> void:
	# Calculates the whole flow field, based on the given flowfield-cost type
	_assign_all_max();
	
	var tiles = field_set._flowFieldPattern;
	var queue : Array[Vector2i] = [destination];
	
	var offsets : Array[Vector2i] = get_cardinal_directions();
	if flow_type != FLOWFIELD_TYPE.Square:
		offsets.append_array(get_diagonal_directions())
	
	# The convolution calculations
	tiles[destination]._value = tiles[destination].bias;
	
	if flow_type == FLOWFIELD_TYPE.Square || flow_type == FLOWFIELD_TYPE.Tchebychev:
		while queue.size() > 0:
			var consider : Vector2i = queue.pop_front();
			var value : float = tiles[consider]._value;
			
			for offset : Vector2i in offsets:
				if tiles.has(consider + offset) && tiles[consider + offset]._set_value(value):
					queue.push_back(consider + offset);
	else:
		var add : float;
		match flow_type:
			FLOWFIELD_TYPE.Euclidean:
				add = _SQRT_TWO;
			FLOWFIELD_TYPE.Manhattan:
				add = 2;
		while queue.size() > 0:
			var consider : Vector2i = queue.pop_front();
			var value : float = tiles[consider]._value;
			
			for offset : Vector2i in get_cardinal_directions():
				if tiles.has(consider + offset) && tiles[consider + offset]._set_value(value + 1):
					queue.push_back(consider + offset);
			for offset : Vector2i in get_diagonal_directions():
				if tiles.has(consider + offset) && tiles[consider + offset]._set_value(value + add):
					queue.push_back(consider + offset);
	
	# Best/Worst
	for tile_pos in tiles.keys():
		var best_offset : Vector2 = Vector2.ZERO;
		
		match cost_check:
			COST_CHECK.Best:
				var best_value : float = INF;
				for offset : Vector2i in offsets:
					if tiles.has(offset + tile_pos):
						if best_value > tiles[offset + tile_pos]._value:
							best_value = tiles[offset + tile_pos]._value;
							best_offset = Vector2(offset).normalized();
			COST_CHECK.Worst:
				var best_value : float = -INF;
				for offset : Vector2i in offsets:
					if tiles.has(offset + tile_pos):
						if best_value < tiles[offset + tile_pos]._value:
							best_value = tiles[offset + tile_pos]._value;
							best_offset = Vector2(offset).normalized();
			
		tiles[tile_pos].best_direction = best_offset;
	tiles[destination].best_direction = Vector2.ZERO;
	
	recalculated.emit();

func _draw() -> void:
	if !field_set || !Engine.is_editor_hint():
		return;
	
	var tiles = field_set._flowFieldPattern
	var tileSize : Vector2 = field_set.tileSize
	var tile_rect : Rect2 = Rect2(Vector2.ZERO, tileSize);
	
	# Colors tiles, if needed
	if show_in_color:
		if color_pallet == COLOR_PRESET.FLAT:
			var draw_color : Color = flat_color;
			draw_color.a *= _display_alpha;
			
			for pos : Vector2i in tiles:
				tile_rect.position = Vector2(pos) * tileSize;
				
				draw_rect(tile_rect, draw_color, true);
		else:
			var draw_color : Dictionary = _wash_highlight_colors();
			
			for pos : Vector2i in tiles:
				tile_rect.position = Vector2(pos) * tileSize;
				
				draw_rect(tile_rect, draw_color[tiles[pos].bias], true);
	
	elif !display_numbers:
		# If not coloring the tiles, and no numbers, display a outline on all tiles
		var draw_color : Color = Color.YELLOW_GREEN;
		draw_color.a *= _display_alpha;
		
		for pos : Vector2i in tiles:
			tile_rect.position = Vector2(pos) * tileSize;
			
			draw_rect(tile_rect, draw_color, false);
	
	var draw_white : Color = Color(1, 1, 1, _display_alpha);
	var draw_black : Color = Color(0, 0, 0, _display_alpha);
	
	# Displays all arrows
	if display_arrows && tiles.has(destination):
		var draw_rect : Rect2;
		if tileSize.min_axis_index() == Vector2.AXIS_X:
			var arrow_size := Vector2(tileSize.x, tileSize.x);
			draw_rect = Rect2(-arrow_size * 0.5, arrow_size);
		else:
			var arrow_size := Vector2(tileSize.y, tileSize.y);
			draw_rect = Rect2(-arrow_size * 0.5, arrow_size);
		
		for pos : Vector2i in tiles.keys():
			var dir : Vector2 = tiles[pos].best_direction;
			if dir == Vector2.ZERO:
				continue;
			
			draw_set_transform((Vector2(pos) + Vector2(0.5, 0.5)) * tileSize, dir.angle(), Vector2.ONE);
			draw_texture_rect(_ARROW_IMAGE_TEXTURE, draw_rect, false, draw_white);
		
		draw_set_transform((Vector2(destination) + Vector2(0.5, 0.5)) * tileSize, 0, Vector2.ONE);
		draw_circle(Vector2.ZERO, draw_rect.position.x * 0.85, draw_black);
		draw_circle(Vector2.ZERO, draw_rect.position.x * 0.8, draw_white);
	
	# Displays all numbers
	if display_numbers:
		for pos : Vector2i in tiles:
			var tileInfo : FlowFieldTile = tiles[pos];
			
			var draw_str : String = str(tileInfo.bias);
			var draw_size : Vector2 = _default_font.get_string_size(draw_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 32);
			var scale_size : Vector2 = tileSize / (draw_size * 1.5);
			var scale : float = min(scale_size.x, scale_size.y);
			
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale, scale));
			var str_pos : Vector2 = (((Vector2(pos) * tileSize) + (tileSize * 0.5)) / scale) + Vector2(-draw_size.x * 0.5, draw_size.y * 0.25);
			draw_string(_default_font, str_pos, draw_str, HORIZONTAL_ALIGNMENT_RIGHT, -1, 32, draw_white);
			draw_string_outline(_default_font, str_pos, draw_str, HORIZONTAL_ALIGNMENT_RIGHT, -1, 32, 2, draw_black);

## Sets the destination for the flow field to move towards.
## [br][br]
## [b]NOTE[/b]: If the destination is invaild, or if the set is empty, nothing will happen.
## If the destination is the same as the one already calculated, then nothing will happen.
func set_destination(dest : Vector2i) -> void:
	# Checks if calculations are needed to be done based on given destination
	if !field_set:
		return;
	
	var tiles = field_set._flowFieldPattern;
	if tiles.is_empty() || !tiles.has(dest) || _destination == dest:
		return;
	
	_destination = dest;
	_adjust_destination();

## Returns an array holding all cardinal directions in [Vector2i] format
func get_cardinal_directions() -> Array[Vector2i]:
	return [DIR_LEFT, DIR_UP, DIR_RIGHT, DIR_DOWN];
## Returns an array holding all diagonal directions in [Vector2i] format
func get_diagonal_directions() -> Array[Vector2i]:
	return [DIR_TOP_LEFT, DIR_TOP_RIGHT, DIR_BOTTOM_LEFT, DIR_BOTTOM_RIGHT];

## Returns if this global position is on a tile in the field or not
## [br][br]
## [b]NOTE[/b]: Error if there is no field_set in this flowfield.
func is_in_field_from_global_pos(global : Vector2) -> bool:
	return field_set.has_tile((global / field_set.tileSize).floor());

## Returns the relative tile position, in the field, a given global position is
## [br][br]
## [b]NOTE[/b]: Error if there is no field_set in this flowfield.
func get_tile_pos_from_global_pos(global : Vector2) -> Vector2i:
	return (global / field_set.tileSize).floor();

## Finds and returns the nearest relative tile position, in the field, to a given
## global position
## [br][br]
## [b]NOTE[/b]: Error if there is no field_set in this flowfield.
func get_nearest_tile_pos_from_global_pos(global : Vector2) -> Vector2i:
	var start : Vector2i = (global / field_set.tileSize).floor();
	
	var rect : Rect2i = field_set.get_used_rect();
	if !field_set.get_used_rect().has_point(start):
		if rect.position.x <= start.x && start.x <= rect.end.x:
			start.y = clamp(start.y, rect.position.y, rect.end.y);
		else:
			start.x = clamp(start.x, rect.position.x, rect.end.x);

	if field_set.has_tile(start):
		return start;
	
	var tiles = field_set._flowFieldPattern;
	if tiles.is_empty():
		return Vector2i.ZERO;
	
	var queue : Array[Vector2i] = [start];
	var offsets : Array[Vector2i] = get_cardinal_directions();
	if flow_type != FLOWFIELD_TYPE.Square:
		offsets.append_array(get_diagonal_directions())
	
	var checked : Dictionary = Dictionary();
	while queue.size() > 0:
		var consider : Vector2i = queue.pop_front();
		for offset : Vector2i in offsets:
			var check_pos : Vector2i = consider + offset;
			if tiles.has(check_pos):
				return check_pos;
			
			if rect.has_point(check_pos) && !checked.has(check_pos):
				checked[check_pos] = null;
				queue.push_back(check_pos);
	
	return Vector2i.ZERO;

## Returns the best direction to move to from a tile, in the field, a given global position is. If you want the
## bias too see [method get_info_from_global_pos].
## [br][br]
## [b]NOTE[/b]: Returns [code]Vector2.ZERO[/code] if given an invaild global position.
## [br][br]
## [b]NOTE[/b]: Error if there is no field_set in this flowfield.
func get_direction_from_global_pos(global : Vector2) -> Vector2:
	var tile_pos : Vector2i = (global / field_set.tileSize).floor();
	
	if field_set.has_tile(tile_pos):
		return field_set.get_direction(tile_pos);
	return Vector2.ZERO;

## Returns the bias of a tile, in the field, a given global position is. If you want the best direction too
## see [method get_info_from_global_pos].
## [br][br]
## [b]NOTE[/b]: Returns [code]0[/code] if given an invaild global position.
## [br][br]
## [b]NOTE[/b]: Error if there is no field_set in this flowfield.
func get_bias_from_global_pos(global : Vector2) -> float:
	var tile_pos : Vector2i = (global / field_set.tileSize).floor();
	
	if field_set.has_tile(tile_pos):
		return field_set.get_bias(tile_pos);
	return 0;

## Returns the bias and best direction of a tile, in the field, a given global position is.
## See [method get_direction_from_global_pos] and [method get_bias_from_global_pos].
## [br][br]
## [b]NOTE[/b]: Returns an empty array if given an invaild global position.
## [br][br]
## [b]NOTE[/b]: Error if there is no field_set in this flowfield.
func get_info_from_global_pos(global : Vector2) -> Array:
	return get_info_from_tile_pos((global / field_set.tileSize).floor());

## Returns the bias and best direction of a tile, in the field, a given tile position is.
## See [method get_info_from_global_pos].
## [br][br]
## [b]NOTE[/b]: Returns an empty array if given an invaild global position.
## [br][br]
## [b]NOTE[/b]: Error if there is no field_set in this flowfield.
func get_info_from_tile_pos(tile_pos : Vector2i) -> Array:
	if field_set.has_tile(tile_pos):
		return [field_set.get_direction(tile_pos), field_set.get_bias(tile_pos)];
	return [];

func get_destination_global() -> Vector2:
	return to_global((Vector2(destination) + Vector2(0.5, 0.5)) * field_set.tileSize);
