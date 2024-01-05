extends Node2D

const TROOP_SCENE : PackedScene = preload("res://addons/test_scene/Troop.tscn");

var spawn_size: Vector2;
var troops : Array[Troop] = [];

@export var spawn_rate : int = 10;
@export var flow_field : FlowField;

func _ready() -> void:
	spawn_size = Vector2(32, 20) * 32;

func _draw() -> void:
	draw_circle(to_local(flow_field.get_destination_global()), 2.5, Color.BLUE);

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("spawn_troops"):
		for idx in spawn_rate:
			var troop : Troop = TROOP_SCENE.instantiate();
			add_child(troop);
			troops.append(troop);
			while true:
				var spawn_pos = Vector2(spawn_size.x * randf(), spawn_size.y * randf());
				if flow_field.is_in_field_from_global_pos(spawn_pos):
					troop.global_position = spawn_pos;
					break;
		
	elif Input.is_action_just_pressed("delete_troops"):
		for troop in troops:
			troop.queue_free();
		troops.clear();
	
	elif Input.is_action_just_pressed("click"):
		flow_field.set_destination(flow_field.get_tile_pos_from_global_pos(get_global_mouse_position()));
		queue_redraw();

func _physics_process(delta: float) -> void:
	for troop in troops:
		var info : Array = flow_field.get_info_from_global_pos(troop.global_position);
		if info.size() == 0:
			info = flow_field.get_info_from_tile_pos(flow_field.get_nearest_tile_pos_from_global_pos(troop.global_position));
		
		troop.velocity = info[0] * (100 / info[1]);
		troop.move_and_slide();
