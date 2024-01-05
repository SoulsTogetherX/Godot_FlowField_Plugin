class_name Troop extends CharacterBody2D

const CHANGE : float = 0.1;

var move_towards : Vector2;

func _draw() -> void:
	draw_circle(Vector2.ZERO, 5, Color.RED);

func set_vec(vec : Vector2) -> void:
	velocity = velocity.lerp(vec, CHANGE * randf());
