extends Control
class_name CardPreview

# Preview configuration
const PREVIEW_SCALE: float = 1.0  # Reduced from 1.8
const PREVIEW_OFFSET: Vector2 = Vector2(20, -50)
const MAX_PREVIEW_WIDTH: float = 215  # Add max width constraint
const MAX_PREVIEW_HEIGHT: float = 356 # Add max height constraint
const APPEAR_DELAY: float = 0.3  
const FADE_DURATION: float = 0.2


# Preview elements
var preview_card: Control
var extra_info_panel: Panel
var extra_info_label: RichTextLabel
var is_showing_preview: bool = false
var hover_timer: Timer


# Card reference
var source_card: Card

signal preview_shown(card: Card)
signal preview_hidden(card: Card)

func _ready():
	# Setup hover timer for delayed appearance
	hover_timer = Timer.new()
	hover_timer.wait_time = APPEAR_DELAY
	hover_timer.one_shot = true
	hover_timer.timeout.connect(_show_preview_delayed)
	add_child(hover_timer)
	
	# Make sure we're on top of everything
	z_index = 1000
	mouse_filter = Control.MOUSE_FILTER_IGNORE

# In card_preview.gd, update this function:
func setup_preview_for_card(card: Card):
	source_card = card
	
	# Try multiple ways to connect mouse events
	var area = card.get_node_or_null("Drag_handler")
	if area and area is Area2D:
		# Connect to Area2D signals (most reliable)
		if not area.mouse_entered.is_connected(_on_card_mouse_entered):
			area.mouse_entered.connect(_on_card_mouse_entered)
		if not area.mouse_exited.is_connected(_on_card_mouse_exited):
			area.mouse_exited.connect(_on_card_mouse_exited)
	else:
		print("Warning: No Area2D found for card preview")

# Also add a backup system - check mouse position every frame when preview is showing
func _process(_delta):
	if is_showing_preview and source_card:
		# Check if mouse is still over the card
		var mouse_pos = get_global_mouse_position()
		var card_rect = _get_card_bounds()
		
		if not card_rect.has_point(mouse_pos):
			_hide_preview()

func _get_card_bounds() -> Rect2:
	if source_card:
		var pos = source_card.global_position
		var size = Vector2(100, 140)  # Approximate card size, adjust as needed
		return Rect2(pos - size/2, size)
	return Rect2()


func _on_card_mouse_entered():
	if (not is_showing_preview and source_card) and (not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		hover_timer.start()

func _on_card_mouse_exited():
	hover_timer.stop()
	if is_showing_preview:
		_hide_preview()

func _show_preview_delayed():
	if source_card and not is_showing_preview:
		_show_preview()

func _show_preview():
	if is_showing_preview:
		return
	
	is_showing_preview = true
	
	# Create preview container
	preview_card = Control.new()
	preview_card.name = "PreviewCard"
	add_child(preview_card)
	
	# Create enlarged card visual using existing Card texture generation
	await _create_preview_card_visual()
	
	# Create extra info panel
	_create_extra_info_panel()
	_create_extra_info_panel()
	# Position preview
	_position_preview()
	
	# Animate appearance
	_animate_preview_in()
	
	preview_shown.emit(source_card)

# Replace the entire _create_preview_card_visual function with this simpler version:
func _create_preview_card_visual():
	# Generate texture at normal card size
	var card_texture = await Card.generate_card_texture(
		source_card.card_name,
		source_card.card_description,
		source_card.card_cost,
		source_card.card_art
	)
	
	# Create TextureRect
	var card_display = TextureRect.new()
	card_display.texture = card_texture
	card_display.position = Vector2.ZERO
	
	# Get original texture size
	var texture_size = card_texture.get_size()

	
	# Calculate scale factor
	var screen_size = get_viewport().get_visible_rect().size
	var target_width = min(400, screen_size.x * 0.3)  # 30% of screen width, max 400px
	var scale_factor = target_width / texture_size.x
	
	
	
	# Apply scale using the scale property
	card_display.scale = Vector2(scale_factor, scale_factor)
	
	# Set the size to the original size (scaling will be applied visually)
	card_display.size = texture_size
	
	preview_card.add_child(card_display)
	
	# Update preview_card size to match the scaled content
	var scaled_size = texture_size * scale_factor
	preview_card.size = scaled_size
	
	print("Final preview size: ", scaled_size)


func _create_extra_info_panel():
	# Get the card display size
	var card_display = preview_card.get_child(0)
	var card_size = card_display.size * card_display.scale
	
	# Create info panel below the card - make it bigger
	extra_info_panel = Panel.new()
	extra_info_panel.position = Vector2(0, card_size.y + 10)
	extra_info_panel.size = Vector2(card_size.x, 200)  # Increased height
	
	# Style the panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.1, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color.CYAN
	extra_info_panel.add_theme_stylebox_override("panel", panel_style)
	
	preview_card.add_child(extra_info_panel)
	
	# Use regular Label instead of RichTextLabel to avoid formatting issues
	extra_info_label = RichTextLabel.new()
	extra_info_label.position = Vector2(5, 5)
	extra_info_label.size = Vector2(extra_info_panel.size.x - 10, extra_info_panel.size.y - 10)
	
	# Configure the label for proper text display
	extra_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	extra_info_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	extra_info_label.add_theme_font_size_override("font_size", 12)
	extra_info_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Set simple text without formatting codes
	var detailed_text = _generate_simple_card_info()
	extra_info_label.text = detailed_text
	
	extra_info_panel.add_child(extra_info_label)

# Replace the _generate_detailed_card_info function with this simpler version:
func _generate_simple_card_info() -> String:
	var info_text = "Description:\n"
	info_text += source_card.card_description + "\n\n"
	
	# Add game-specific information without formatting codes
	info_text += "Business Effects:\n"
	
	# Check for business effects
	if source_card.has_method("get_income_boost"):
		var income = source_card.call("get_income_boost")
		info_text += "• Income: +$" + str(income) + " per turn\n"
	
	if source_card.has_method("get_special_ability"):
		var ability = source_card.call("get_special_ability")
		info_text += "• Special: " + str(ability) + "\n"
	
	# Add strategic tips
	info_text += "\nStrategy Tips:\n"
	info_text += _get_strategy_tip()
	
	return info_text

func _get_strategy_tip() -> String:
	# Return contextual tips based on card cost and type
	if source_card.card_cost > 200:
		return "• High-cost investment - best played early for maximum returns"
	elif source_card.card_cost < 100:
		return "• Low-cost option - good for quick income or filling gaps"
	else:
		return "• Balanced investment - reliable mid-game choice"

func _position_preview():
	if not preview_card or preview_card.get_child_count() == 0:
		return
	
	# Get mouse position and screen bounds
	var mouse_pos = get_global_mouse_position()
	var screen_size = get_viewport().get_visible_rect().size
	
	# Calculate total preview size (card + info panel)
	var card_display = preview_card.get_child(0)
	var total_height = card_display.size.y
	if extra_info_panel:
		total_height += extra_info_panel.size.y + 10
	
	var preview_size = Vector2(card_display.size.x, total_height)
	
	# Calculate position with screen boundary checking
	var target_pos = mouse_pos + PREVIEW_OFFSET
	
	# Keep preview on screen
	if target_pos.x + preview_size.x > screen_size.x:
		target_pos.x = mouse_pos.x - preview_size.x - 20
	
	if target_pos.y + preview_size.y > screen_size.y:
		target_pos.y = screen_size.y - preview_size.y - 10
	
	if target_pos.x < 0:
		target_pos.x = 10
	
	if target_pos.y < 0:
		target_pos.y = 10
	
	preview_card.position = target_pos

func _animate_preview_in():
	if not preview_card:
		return
	
	# Start invisible and small
	preview_card.modulate.a = 0.0
	preview_card.scale = Vector2(0.5, 0.5)
	
	# Animate to full visibility and size
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(preview_card, "modulate:a", 1.0, FADE_DURATION)
	tween.tween_property(preview_card, "scale", Vector2(1.0, 1.0), FADE_DURATION)

func _hide_preview():
	if not is_showing_preview:
		return
	
	is_showing_preview = false
	
	if preview_card:
		# Animate out
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(preview_card, "modulate:a", 0.0, FADE_DURATION * 0.5)
		tween.tween_property(preview_card, "scale", Vector2(0.8, 0.8), FADE_DURATION * 0.5)
		
		# Remove after animation
		await tween.finished
		preview_card.queue_free()
		preview_card = null
	
	preview_hidden.emit(source_card)

# Update preview position as mouse moves
func _input(event):
	if is_showing_preview and event is InputEventMouseMotion:
		_position_preview()

# Cleanup
func _exit_tree():
	if hover_timer:
		hover_timer.queue_free()
	if preview_card:
		preview_card.queue_free()
