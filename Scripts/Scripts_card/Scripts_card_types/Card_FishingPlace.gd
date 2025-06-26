class_name FishingPlace_Card
extends Card
static var scene = preload("res://Scenes/card_template.tscn")

static func create() -> FishingPlace_Card:
	var instance = scene.instantiate()
	instance.set_script(preload("res://Scripts/Scripts_card/Scripts_card_types/Card_FishingPlace.gd"))
	return instance
func _init():
	super("Fishing Place", "At the end of the turn get 1 'fish' (50%) or 2 'garbage' (50%) ", 3, "FishingPlace_001", preload("res://Sprites/Sprites_card_art/photo_2025-06-09_19-39-59.jpg"))
