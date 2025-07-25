extends Node
var card_database = {
	"Meadow Card": Meadow_Card,
	"Rocket": IceballCard,
	"Fishing Place": FishingPlace_Card,
	"Wheat Field": WheatFieldCard,
}

func create_card_instance(template_name: String) -> Card:
	if template_name in card_database:
		# Create visual instance from template
		
		
		var card_instance=card_database[template_name].create()
	
		
		card_instance.name = card_instance.card_name + str(randi())
		return card_instance
	return null
	
func art_capture(template_name: String):
	
	await get_tree().create_timer(0.1).timeout
	#print("Testing card capture...")
	var data_instance = card_database[template_name].new()
	var texture = await Card.generate_card_texture(
		data_instance.card_name,
		data_instance.card_description,
		data_instance.card_cost,
		data_instance.card_art  
	)
	data_instance.queue_free()
	return texture
