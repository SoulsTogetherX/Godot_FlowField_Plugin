@tool
extends Node2D

const ARROW_IMAGE_TEXTURE : CompressedTexture2D = preload("res://addons/FlowField/assets/arrow_big.svg");

var angle : float = 0;

func _process(delta: float) -> void:
	queue_redraw();
	angle += 0.01;

func _draw() -> void:
	var draw_rect : Rect2 = Rect2(-Vector2.ONE * 16, Vector2.ONE * 32);
	
	draw_set_transform(Vector2.ZERO, angle, Vector2.ONE);
	draw_texture_rect(ARROW_IMAGE_TEXTURE, draw_rect, false);
