@tool
extends Control

signal tool_type_changed(tool : int);
signal picker_changed(toggle : bool);
signal eraser_changed(toggle : bool);
signal grid_changed(toggle : bool);
signal color_changed(toggle : bool);
signal color_type_changed(color_type : int);
signal arrow_changed(toggle : bool);
signal number_changed(toggle : bool);
signal bias_changed(bias : int);
signal path_type_changed(path_type : int);

@onready var _spinbox : SpinBox = $tools_buttons/SpinBox;
@onready var _separator : VSeparator = $tools_buttons/VSeparator;
@onready var _options: OptionButton = $tools_buttons/OptionButton;

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

func _change_tool_type(tool_type : int) -> void:
	tool_type_changed.emit(tool_type);
	
	_spinbox.visible = (tool_type > 1);
	_separator.visible = (tool_type > 1);

func _toggle_picker(toggle: bool) -> void:
	picker_changed.emit(toggle);

func _toggle_eraser(toggle: bool) -> void:
	eraser_changed.emit(toggle);

func _color_type_changed(color : int) -> void:
	color_type_changed.emit(color);

func _color_changed(toggle: bool) -> void:
	color_changed.emit(toggle);

func _toggle_arrow(toggle: bool) -> void:
	arrow_changed.emit(toggle);

func _toggle_number(toggle: bool) -> void:
	number_changed.emit(toggle);

func _toggle_grid(toggle: bool) -> void:
	grid_changed.emit(toggle);

func _change_bias(bias: float) -> void:
	bias_changed.emit(bias as int);
