class_name Tile extends RefCounted

var chuck_pos : Vector2i;
var tile_pos : Vector2i;
var bais : float = 0;
var value : float;

const CardinalDirections : Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN
]

func getAdjacentTiles(flow : FlowField) -> Array[Tile]:
	var ret : Array[Tile] = [];
	
	for direction : Vector2i in CardinalDirections:
		var c_pos : Vector2i = chuck_pos;
		var t_pos : Vector2i = tile_pos;
		
		if direction.x < 0:
			if t_pos.x - 1 < 0:
				t_pos.x = flow.chuckSize.x - 1;
				c_pos.x -= 1;
			else:
				t_pos.x -= 1;
		else:
			if t_pos.x + 1 > flow.chuckSize.x:
				t_pos.x = 0;
				c_pos.x += 1;
			else:
				t_pos.x += 1;
		
		if direction.y < 0:
			if t_pos.y - 1 < 0:
				t_pos.y = flow.chuckSize.y - 1;
				c_pos.y -= 1;
			else:
				t_pos.y -= 1;
		else:
			if t_pos.y + 1 > flow.chuckSize.x:
				t_pos.y = 0;
				c_pos.y += 1;
			else:
				t_pos.y += 1;
		
		if flow._chucks.has(c_pos):
			var tile : Tile = flow._chucks[c_pos].getTileAt(t_pos);
			if tile != null:
				ret.append(tile);
	
	return ret;
