class_name Meadow_Card
extends Card
static var scene = preload("res://Scenes/card_template.tscn")

static func create() -> Meadow_Card:
	var instance = scene.instantiate()
	instance.set_script(preload("res://Scripts/Client/Scripts_card/Scripts_card_types/Card_Meadow.gd"))
	return instance
func _init():
	super("Meadow", "In the end of the turn get 1 'millet' ", 2, "Meadow_001", preload("res://Sprites/Sprites_card_art/photo_2025-06-09_19-39-55.jpg"))
