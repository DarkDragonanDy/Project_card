# hex_interaction_handler.gd - Handles mouse interaction with hexes
extends Node2D
class_name HexInteractionHandler

@onready var hex_grid: TileMapLayer = $"../../Control_lair/Game_UI/GridContainer/Game_board/TileMapLayer"
@onready var play_manager: CardPlayManager =$"../../card_play_manager"

var current_hover_hex: Vector2i = Vector2i(-999, -999)
var hover_preview: Control = null


signal hex_hovered(hex_position: Vector2i, card: Card)
signal hex_hover_ended(hex_position: Vector2i)

func _ready():
	set_process_unhandled_input(true)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		_handle_hex_hover()
	
   
		

func _handle_hex_hover():
	var mouse_pos = get_global_mouse_position()
	var local_pos = hex_grid.to_local(mouse_pos)
	var hex_pos = hex_grid.local_to_map(local_pos)
	
	# Check if we're over a new hex
	if hex_pos != current_hover_hex:
		# End previous hover
		if current_hover_hex != Vector2i(-999, -999):
			_end_hex_hover()
		
		# Start new hover
		current_hover_hex = hex_pos
		if (play_manager.get_card_at_hex(hex_pos)):
			var card = play_manager.get_card_at_hex(hex_pos)
			if card:
				_start_hex_hover(hex_pos, card)

func _start_hex_hover(hex_pos: Vector2i, card: Card):
	hex_hovered.emit(hex_pos, card)
	
	# Show card preview
	if card.has_method("show_hover_preview"):
		card.show_hover_preview()
	else:
		_show_generic_preview(card)

func _end_hex_hover():
	if hover_preview:
		hover_preview.queue_free()
		hover_preview = null
	
	hex_hover_ended.emit(current_hover_hex)
	current_hover_hex = Vector2i(-999, -999)

func _show_generic_preview(card: Card):
	# Create hover preview
	hover_preview = preload("res://Scripts/Scripts_card/Card_defenition/card_preview.gd").new()
	get_tree().current_scene.add_child(hover_preview)
	hover_preview.setup_preview_for_card(card)
	hover_preview._show_preview()
