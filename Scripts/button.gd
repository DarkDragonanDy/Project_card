extends Button
func _on_button_pressed():
	print("click")
	# Reference your CardDatabase script directly
	var new_card = CardDatabase.create_card_instance("fireball")
	#CardDB.create_card_instance("fireball")  # Your existing function
	
	if new_card:
		get_tree().current_scene.add_child(new_card)
		new_card.position = Vector2(randf() * 400, randf() * 300)
