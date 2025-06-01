extends Node
var card_database = {
	"fireball": Card.new("Fireball", "Deal 3 damage", 3, "fireball_001"),
	"heal": Card.new("Healing Potion", "Restore 5 health", 1, "heal_001"),
	"lightning": Card.new("Lightning Bolt", "Deal 2 damage", 2, "lightning_001")
}
var card_scene = preload("res://Scenes/card_template.tscn")  # Your card scene file
func create_card_instance(template_name: String) -> Card:
	if template_name in card_database:
		
		var card_instance = card_scene.instantiate()
		
		var template = card_database[template_name]
		card_instance.card_name = template.card_name
		card_instance.card_description = template.card_description
		card_instance.card_cost = template.card_cost
		return card_instance
	return null
