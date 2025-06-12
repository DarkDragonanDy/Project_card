extends Node
var card_database = {
	"Meadow": Meadow_Card,
	"iceball": IceballCard,
	"Fishing Place": FishingPlace_Card,
}
var card_scene = Card.new().card_scene
func create_card_instance(template_name: String) -> Card:
	if template_name in card_database:
		# Create visual instance from template
		var card_instance = card_scene.instantiate()
		
		# Create data instance from class
		var data_instance = card_database[template_name].new()
		
		# Copy data to visual instance
		card_instance.apply_card_data(data_instance)
		
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
	return texture
