extends Control

signal resume_requested
signal save_requested
signal load_requested
signal main_menu_requested

func _ready():
	$CenterContainer/VBoxContainer/ResumeBtn.connect("pressed", self, "_on_resume_pressed")
	$CenterContainer/VBoxContainer/SaveBtn.connect("pressed", self, "_on_save_pressed")
	$CenterContainer/VBoxContainer/LoadBtn.connect("pressed", self, "_on_load_pressed")
	$CenterContainer/VBoxContainer/MenuBtn.connect("pressed", self, "_on_menu_pressed")

func _on_resume_pressed():
	emit_signal("resume_requested")

func _on_save_pressed():
	emit_signal("save_requested")

func _on_load_pressed():
	emit_signal("load_requested")

func _on_menu_pressed():
	emit_signal("main_menu_requested")
