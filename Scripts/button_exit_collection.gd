extends Button
signal play_requested


	
func _on_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/node_scene.tscn")
	play_requested.emit()
