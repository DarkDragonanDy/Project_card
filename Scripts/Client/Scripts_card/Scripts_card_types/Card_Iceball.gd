class_name IceballCard
extends Card
static var scene = preload("res://Scenes/card_template.tscn")
static func create() -> IceballCard:
	var instance = scene.instantiate()
	instance.set_script(preload("res://Scripts/Client/Scripts_card/Scripts_card_types/Card_Iceball.gd"))
	return instance
	
func _init():
	super("Iceball", "Deal 3 damage", 3, "fireball_001", preload("res://Sprites/Tiles/cropped-image-99wl-4.png"))
