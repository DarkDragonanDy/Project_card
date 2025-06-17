extends Control

func _ready():
	 #Create TextureRect dynamically since it doesn't exist in scene
	#var texture_rect = TextureRect.new()
	#texture_rect.position = Vector2(50, 50)
	#texture_rect.size = Vector2(200, 280)
	#add_child(texture_rect)
	
	# Wait a moment
	
	pass
	 #Now test with actual card
	#test_card_capture()

func test_card_capture():
	await get_tree().create_timer(0.1).timeout
	print("Testing card capture...")
	
	# Method 1: Try the static method
	var texture = await Card.generate_card_texture(
		"Fire Bolt",
		"Deal 3 damage to any target",
		2,
		load("res://Sprites/Tiles/cropped-image-14jv-2.png")  # No art for now
	)
	
	#if texture:
		#texture_rect.texture = texture
		#
		#
		#
		#print("Card texture generated successfully!")
	#else:
		#print("Failed to generate card texture")
		## Try fallback method
		#test_card_capture_fallback(texture_rect)

#func test_card_capture_fallback(texture_rect: TextureRect):
	#print("Trying fallback method...")
	#
	## Create viewport
	#var viewport = SubViewport.new()
	#viewport.size = Vector2(200, 280)
	#viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	#add_child(viewport)
	#
	## Load and instance card
	#var card_scene = load("res://Scenes/card_template.tscn")
	#var card = card_scene.instantiate()
	#viewport.add_child(card)
	#
	## Wait for ready
	#await get_tree().process_frame
	#
	## Set values directly
	#if card.has_node("Card_box_name/Card_text_name"):
		#card.get_node("Card_box_name/Card_text_name").text = "Test Card"
	#
	#if card.has_node("Card_box_text/Card_text_box"):
		#card.get_node("Card_box_text/Card_text_box").text = "Test Description"
	#
	#if card.has_node("Card_box_cost/Card_text_cost"):
		#card.get_node("Card_box_cost/Card_text_cost").text = "5"
	#
	## Wait for render
	#await get_tree().process_frame
	#await get_tree().process_frame
	#
	## Get texture
	#var image = viewport.get_texture().get_image()
	#var texture = ImageTexture.create_from_image(image)
	#
	#texture_rect.texture = texture
	#
	## Save for debugging
	#image.save_png("res://Sprites/")
	#print("Saved test image to user://test_card.png")
	#
	#viewport.queue_free()
