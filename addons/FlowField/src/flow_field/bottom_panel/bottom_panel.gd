@tool
extends Control

@onready var _spinbox : SpinBox = $tools_buttons/SpinBox;
@onready var _separator : VSeparator = $tools_buttons/VSeparator;

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

func _update_tool_type(tool_type : int) -> void:
	_spinbox.visible = (tool_type > 1);
	_separator.visible = (tool_type > 1);
