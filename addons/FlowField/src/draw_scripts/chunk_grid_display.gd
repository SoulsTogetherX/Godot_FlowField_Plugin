@tool
extends Node2D

var _chuckSize : Vector2;
var _tileSize : Vector2;

func draw_grid(chuckSize : Vector2, tileSize : Vector2) -> void:
	_chuckSize = chuckSize;
	_tileSize = tileSize;

func _draw() -> void:
	var cal_size : Vector2 = Vector2(_chuckSize) * _tileSize;
	
	for r in range(1, _chuckSize.y):
		var line_base : Vector2 = Vector2(0, r * _tileSize.y);
		draw_line(line_base, line_base + Vector2(cal_size.x, 0) , Color.YELLOW)
	for c in _chuckSize.x:
		var line_base : Vector2 = Vector2(c * _tileSize.x, 0);
		draw_line(line_base, line_base + Vector2(0, cal_size.y) , Color.YELLOW)
	
	draw_rect(Rect2(Vector2.ZERO, cal_size), Color.RED, false);
