@tool
extends Node2D

var _chunk_pos : Vector2 = Vector2(0,0);

func move_to(chunk_pos : Vector2, cal_size : Vector2) -> bool:
	if _chunk_pos != chunk_pos:
		position = chunk_pos * cal_size;
		_chunk_pos = chunk_pos;
		return true;
	return false;
