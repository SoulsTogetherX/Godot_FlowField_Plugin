@tool
extends Node2D

var _chuckSize : Vector2;
var _tileSize : Vector2;
var _chunk : Chunk;
var _default_font : Font;

func _ready() -> void:
	var control : Control = Control.new();
	_default_font = control.get_theme_default_font().duplicate();
	control.queue_free();

func draw_values(chuckSize : Vector2, tileSize : Vector2, chunk : Chunk) -> void:
	_chuckSize = chuckSize;
	_tileSize = tileSize;
	_chunk = chunk;
	queue_redraw();

func _draw() -> void:
	for r in _chuckSize.y:
		for c in _chuckSize.x:
			_draw_tile_at(Vector2i(c, r));

func _draw_tile_at(draw_at : Vector2i) -> void:
	var draw_pos_base : Vector2 = (Vector2(draw_at) + Vector2.DOWN) * _tileSize;
	var tile : Tile = _chunk.getTileAt(draw_at);
	
	var draw_str : String = str(tile.bais) if tile else "N/A";
	var draw_size : Vector2 = _default_font.get_string_size(draw_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 32);
	var scale_size : Vector2 = _tileSize / (draw_size * 2);
	if scale_size.x > scale_size.y:
		scale_size.x = scale_size.y;
	else:
		scale_size.y = scale_size.x;
	draw_set_transform(position, 0, scale_size);
	draw_string(_default_font, draw_pos_base / scale_size + Vector2(0, -2), draw_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 32);

	draw_str = str(tile.value) if tile else "N/A";
	draw_size = _default_font.get_string_size(draw_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 32);
	scale_size = _tileSize / (draw_size * 2);
	if scale_size.x > scale_size.y:
		scale_size.x = scale_size.y;
	else:
		scale_size.y = scale_size.x;
	draw_set_transform(position, 0, scale_size);
	draw_string(_default_font, ((draw_pos_base + Vector2(_tileSize.x, -_tileSize.y)) / scale_size) + Vector2(-draw_size.x, draw_size.y - 20), draw_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 32);
