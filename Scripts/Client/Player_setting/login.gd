extends Control

@onready var login_input: LineEdit = $VBoxContainer/ColorRect_Start_game/Name_space
@onready var password_input: LineEdit = $VBoxContainer/ColorRect_Start_game2/Password_space
@onready var login_button: Button = $VBoxContainer/ColorRect_Collection/Login_button


# В login.gd добавляем новую логику:

func _ready():
	pass
	# Проверяем режим запуска
	if NetworkMode.is_server():
		_transform_to_server_terminal()
	
	

func _transform_to_server_terminal():
	# ПОЛНОСТЬЮ скрываем элементы логина
	$VBoxContainer/ColorRect_Start_game.visible = false
	$VBoxContainer/ColorRect_Start_game2.visible = false
	$VBoxContainer/ColorRect_Collection.visible = false
	
	# Создаем серверный терминал
	_create_server_terminal()

func _create_server_terminal():
	# Создаем новый контейнер для терминала
	var terminal_container = VBoxContainer.new()
	terminal_container.name = "ServerTerminal"
	add_child(terminal_container)
	
	# Заголовок сервера
	var title_label = Label.new()
	title_label.text = "GAME SERVER TERMINAL"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	terminal_container.add_child(title_label)
	
	# Поле для логов сервера
	var log_display = TextEdit.new()
	log_display.name = "ServerLog"
	log_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_display.editable = false
	log_display.placeholder_text = "Server starting up...\n"
	log_display.custom_minimum_size = Vector2(600, 400)
	terminal_container.add_child(log_display)
	
	# Статистика сервера
	var stats_container = HBoxContainer.new()
	terminal_container.add_child(stats_container)
	
	var players_label = Label.new()
	players_label.name = "PlayersCount"
	players_label.text = "Connected Players: 0"
	stats_container.add_child(players_label)
	
	var games_label = Label.new()
	games_label.name = "GamesCount" 
	games_label.text = "Active Games: 0"
	stats_container.add_child(games_label)
	
	# Кнопка остановки сервера
	
	
	# Подключаемся к серверным событиям
	_connect_server_events()
	
	# Запускаем сервер автоматически
	_auto_start_server()

func _connect_server_events():
	# Подключаемся к событиям NetworkManager для отображения логов
	NetworkManager.server_started.connect(_on_server_started)
	NetworkManager.player_connected.connect(_on_player_connected_terminal)
	NetworkManager.player_disconnected.connect(_on_player_disconnected_terminal)
	NetworkManager.game_action_received.connect(_on_game_action_terminal)

func _auto_start_server():
	print("Auto-starting server...")
	_log_to_terminal("Initializing server...")
	
	# Запускаем сервер через NetworkManager
	var success = await NetworkManager.start_server()
	if success:
		_log_to_terminal("✓ Server started on port " + str(NetworkMode.server_port))
		_log_to_terminal("Waiting for players...")
	else:
		_log_to_terminal("✗ Failed to start server!")

func _log_to_terminal(message: String):
	var log_display = get_node_or_null("ServerTerminal/ServerLog")
	if log_display:
		var timestamp = Time.get_datetime_string_from_system()
		var full_message = "[" + timestamp + "] " + message + "\n"
		log_display.text += full_message
		
		# Автоскролл вниз
		await get_tree().process_frame
		log_display.scroll_vertical = log_display.get_line_count()



func _on_server_started():
	_log_to_terminal("✓ Server is now listening for connections")
	_update_server_stats()

func _on_player_connected_terminal(player_name: String):
	_log_to_terminal("→ Player connected: " + player_name)
	_update_server_stats()

func _on_player_disconnected_terminal(player_name: String):
	_log_to_terminal("← Player disconnected: " + player_name)
	_update_server_stats()

func _on_game_action_terminal(action_data: Dictionary):
	var player = action_data.get("player_id", "Unknown")
	var action = action_data.get("type", "unknown_action")
	
	match action:
		"play_card":
			var card_name = action_data.data.get("card_name", "Unknown Card")
			_log_to_terminal("🎮 " + player + " played card: " + card_name)
		"end_turn":
			_log_to_terminal("⏭ " + player + " ended their turn")
		"surrender":
			_log_to_terminal("🏳 " + player + " surrendered")
		_:
			_log_to_terminal("📡 " + player + " performed: " + action)

func _update_server_stats():
	var players_count = NetworkManager.get_connected_players().size()
	var active_games = 1 if players_count >= 2 else 0
	
	var players_label = get_node_or_null("ServerTerminal/HBoxContainer/PlayersCount")
	var games_label = get_node_or_null("ServerTerminal/HBoxContainer/GamesCount")
	
	if players_label:
		players_label.text = "Connected Players: " + str(players_count)
	if games_label:
		games_label.text = "Active Games: " + str(active_games)

func _stop_server():
	_log_to_terminal("Stopping server...")
	NetworkManager.disconnect_from_network()
	_log_to_terminal("Server stopped. You can close this window.")
	
	# Можно добавить кнопку для закрытия приложения
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()
#
func _on_login_pressed() -> void:
	var login = login_input.text
	var password = password_input.text
	
		
	if PlayerDatabase.verify_login(login, password):
		await NetworkManager.connect_to_server()
		PlayerDatabase.current_user = login
		
		
		# Загружаем колоду пользователя
		DeckData.load_user_deck()
		
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://Scenes/node_scene.tscn")

		
	
	
