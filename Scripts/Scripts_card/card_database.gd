extends Node
var card_database = {
	"fireball": FireballCard,
	
}
var card_scene = preload("res://Scenes/card_template.tscn")  # Your card scene file
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
