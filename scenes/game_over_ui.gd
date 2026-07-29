extends Node2D


func _ready() -> void:
	$CanvasLayer/VBoxContainer/RestartButton.pressed.connect(_on_restart_button_pressed)


func _on_restart_button_pressed() -> void:
	get_tree().reload_current_scene()
