@tool
extends Control

signal tool_type_changed(tool : int);
signal picker_changed(toggle : bool);
signal eraser_changed(toggle : bool);
signal grid_changed(toggle : bool);
signal bias_changed(bias : int);

@onready var _separator : VSeparator = $tools_buttons/VSeparator;
@onready var _spinbox : SpinBox = $tools_buttons/SpinBox;

func _input(event: InputEvent) -> void:
	if _spinbox.visible:
		if event.is_action_pressed("ui_page_up"):
			if Input.is_key_pressed(KEY_CTRL):
				if Input.is_key_pressed(KEY_ALT):
					_spinbox.value += 100;
					return;
				_spinbox.value += 10;
				return;
			if Input.is_key_pressed(KEY_ALT):
				_spinbox.value += 5;
				return;
			_spinbox.value += 1;
		elif event.is_action_pressed("ui_page_down"):
			if Input.is_key_pressed(KEY_CTRL):
				if Input.is_key_pressed(KEY_ALT):
					_spinbox.value -= 100;
					return;
				_spinbox.value -= 10;
				return;
			if Input.is_key_pressed(KEY_ALT):
				_spinbox.value -= 5;
				return;
			_spinbox.value -= 1;

func _change_tool_type(tool_type : int):
	tool_type_changed.emit(tool_type);
	
	_separator.visible = (tool_type > 1);
	_spinbox.visible = (tool_type > 1);

func _toggle_picker(toggle: bool) -> void:
	picker_changed.emit(toggle);

func _toggle_eraser(toggle: bool) -> void:
	eraser_changed.emit(toggle);

func _toggle_grid(toggle: bool) -> void:
	grid_changed.emit(toggle);

func _change_bias(bias: float) -> void:
	bias_changed.emit(bias as int);
