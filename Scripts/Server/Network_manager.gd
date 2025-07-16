# NetworkManager.gd - Autoload
extends Node

# Сигналы для связи с игровой логикой
signal game_action_received(action_data: Dictionary)
signal player_connected(player_id: String)
signal player_disconnected(player_id: String)
signal connection_established
signal connection_failed_signal
signal server_started
signal game_state_synchronized(state: Dictionary)

# Сетевые переменные
var multiplayer_peer: ENetMultiplayerPeer
var connected_clients: Dictionary = {}  # peer_id: {player_name, ready_status}
var game_state: Dictionary = {
	"current_turn": 1,
	"current_player": 1,
	"players": {},
	"board_state": {},
	"game_phase": "waiting"
}

# Состояние подключения
var is_connected: bool = false
var my_peer_id: int = 0

func _ready():
	# Определяем режим работы по аргументам командной строки
	var args = OS.get_cmdline_args()
	if "--server" in args:
		NetworkMode.set_mode(NetworkMode.Mode.SERVER)
	elif "--client" in args:
		NetworkMode.set_mode(NetworkMode.Mode.CLIENT)
		
		

func start_server() -> bool:
	print("Starting server on port ", NetworkMode.server_port)
	
	# Создаем сетевой интерфейс
	multiplayer_peer = ENetMultiplayerPeer.new()
	
	# Запускаем сервер
	var error = multiplayer_peer.create_server(NetworkMode.server_port, 4)
	if error != OK:
		print("Failed to start server: ", error)
		return false
	
	# Подключаем интерфейс к системе мультиплеера
	multiplayer.multiplayer_peer = multiplayer_peer
	
	# Подписываемся на события
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	# Инициализируем игровое состояние
	_initialize_server_game_state()
	
	print("Server started successfully")
	server_started.emit()
	return true

func connect_to_server() -> bool:
	print("Connecting to server at ", NetworkMode.server_address)
	
	multiplayer_peer = ENetMultiplayerPeer.new()
	
	# Подключаемся к серверу
	var error = multiplayer_peer.create_client(NetworkMode.server_address, NetworkMode.server_port)
	if error != OK:
		print("Failed to connect to server: ", error)
		return false
	
	multiplayer.multiplayer_peer = multiplayer_peer
	
	# Подписываемся на события клиента
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	return true

# ============= ОТПРАВКА ДЕЙСТВИЙ =============

func send_game_action(action_type: String, data: Dictionary):
	var message = {
		"type": action_type,
		"player_id": PlayerDatabase.current_user,
		"data": data,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	if NetworkMode.is_client():
		# Клиент отправляет запрос серверу
		_request_action_from_server.rpc_id(1, message)
	elif NetworkMode.is_server():
		# Сервер обрабатывает действие локально
		message["sender_peer_id"] = 1  # Сервер это peer 1
		_process_server_action(message)

# ============= RPC ФУНКЦИИ =============

@rpc("any_peer", "call_remote", "reliable")
func _request_action_from_server(message: Dictionary):
	# Только сервер обрабатывает запросы
	if not multiplayer.is_server():
		return
	
	# Добавляем информацию о отправителе
	message["sender_peer_id"] = multiplayer.get_remote_sender_id()
	
	print("Server received action request: ", message.type, " from peer ", message.sender_peer_id)
	_process_server_action(message)

@rpc("authority", "call_local", "reliable")
func _broadcast_action_result(message: Dictionary):
	# Выполняется на всех подключенных устройствах
	print("Received action result: ", message.type)
	game_action_received.emit(message)

@rpc("authority", "call_remote", "reliable")
func _send_game_state_to_peer(state: Dictionary):
	# Новый игрок получает полное состояние игры
	print("Received game state from server")
	game_state = state.duplicate()
	game_state_synchronized.emit(game_state)

@rpc("authority", "call_local", "reliable") 
func _notify_player_left(player_name: String):
	print("Player left the game: ", player_name)
	player_disconnected.emit(player_name)

@rpc("any_peer", "call_remote", "reliable")
func _register_player(player_name: String):
	# Только сервер обрабатывает регистрацию
	if not multiplayer.is_server():
		return
	
	var peer_id = multiplayer.get_remote_sender_id()
	print("Registering player: ", player_name, " with peer ID: ", peer_id)
	
	# Сохраняем информацию об игроке
	connected_clients[peer_id] = {
		"player_name": player_name,
		"ready": false,
		"connected_at": Time.get_unix_time_from_system()
	}
	
	# Добавляем игрока в игровое состояние
	game_state.players[player_name] = {
		"peer_id": peer_id,
		"wealth": 1000,
		"income": 100,
		"cards_in_hand": []
	}
	
	# Отправляем игроку текущее состояние
	_send_game_state_to_peer.rpc_id(peer_id, game_state)
	
	# Уведомляем всех о новом игроке
	player_connected.emit(player_name)

@rpc("authority", "call_remote", "reliable")
func _send_error_to_client(error_message: String):
	print("Error from server: ", error_message)

# ============= ОБРАБОТКА ДЕЙСТВИЙ НА СЕРВЕРЕ =============

func _process_server_action(message: Dictionary):
	print("Server processing action: ", message.type)
	
	# Валидация действия
	if not _validate_action(message):
		print("Action rejected: ", message.type)
		var peer_id = message.get("sender_peer_id", 1)
		if peer_id != 1:  # Не отправляем ошибку самому серверу
			_send_error_to_client.rpc_id(peer_id, "Invalid action: " + message.type)
		return
	
	# Обновляем состояние игры
	_update_game_state(message)
	
	# Рассылаем результат всем клиентам
	_broadcast_action_result.rpc(message)

func _validate_action(message: Dictionary) -> bool:
	match message.type:
		"play_card":
			return _validate_card_play(message)
		"end_turn":
			return _validate_turn_end(message)
		"surrender":
			return true
		_:
			print("Unknown action type: ", message.type)
			return false

func _validate_card_play(message: Dictionary) -> bool:
	var data = message.data
	var player_id = message.player_id
	
	# Проверяем базовые данные
	if not data.has("card_name") or not data.has("hex_position"):
		print("Card play missing required data")
		return false
	
	# Проверяем очередь игрока
	if not _is_player_turn(player_id):
		print("Not player's turn: ", player_id)
		return false
	
	# Проверяем, может ли игрок позволить себе карту
	if not _player_can_afford_card(player_id, data.card_name):
		print("Player cannot afford card: ", player_id, " -> ", data.card_name)
		return false
	
	# Проверяем позицию на доске
	if not _is_valid_hex_position(data.hex_position):
		print("Invalid hex position: ", data.hex_position)
		return false
	
	return true

func _validate_turn_end(message: Dictionary) -> bool:
	var player_id = message.player_id
	return _is_player_turn(player_id)

# ============= ИГРОВАЯ ЛОГИКА =============

func _is_player_turn(player_id: String) -> bool:
	# Простая проверка очереди (можно усложнить)
	var current_player_name = _get_current_player_name()
	return player_id == current_player_name

func _get_current_player_name() -> String:
	var player_number = game_state.get("current_player", 1)
	var player_names = game_state.players.keys()
	if player_names.size() >= player_number:
		return player_names[player_number - 1]
	return ""

func _player_can_afford_card(player_id: String, card_name: String) -> bool:
	if not game_state.players.has(player_id):
		return false
	
	var player_wealth = game_state.players[player_id].get("wealth", 0)
	var card_cost = _get_card_cost(card_name)
	
	return player_wealth >= card_cost

func _get_card_cost(card_name: String) -> int:
	# Здесь должна быть ссылка на базу данных карт
	# Пока что возвращаем фиксированные значения
	match card_name:
		"Meadow":
			return 150
		"iceball":
			return 100
		"Fishing Place":
			return 200
		_:
			return 100

func _is_valid_hex_position(hex_pos: Dictionary) -> bool:
	if not hex_pos.has("x") or not hex_pos.has("y"):
		return false
	
	var x = hex_pos.x
	var y = hex_pos.y
	
	# Проверяем, что позиция в разумных пределах
	if x < -10 or x > 10 or y < -10 or y > 10:
		return false
	
	# Проверяем, что позиция свободна
	var pos_key = str(x) + "," + str(y)
	return not game_state.board_state.has(pos_key)

func _update_game_state(message: Dictionary):
	match message.type:
		"play_card":
			_apply_card_play(message)
		"end_turn":
			_apply_turn_end(message)
	
	_save_current_game_state()

func _apply_card_play(message: Dictionary):
	var data = message.data
	var player_id = message.player_id
	
	# Списываем деньги у игрока
	var card_cost = _get_card_cost(data.card_name)
	game_state.players[player_id].wealth -= card_cost
	
	# Размещаем карту на доске
	var pos_key = str(data.hex_position.x) + "," + str(data.hex_position.y)
	game_state.board_state[pos_key] = {
		"card_name": data.card_name,
		"owner": player_id,
		"placed_turn": game_state.current_turn
	}
	
	print("Card placed: ", data.card_name, " at ", pos_key, " by ", player_id)

func _apply_turn_end(message: Dictionary):
	# Переключаем игрока
	var total_players = game_state.players.size()
	game_state.current_player += 1
	
	if game_state.current_player > total_players:
		game_state.current_player = 1
		game_state.current_turn += 1
		
		# Начисляем доход всем игрокам в начале нового хода
		for player_name in game_state.players.keys():
			var income = game_state.players[player_name].get("income", 100)
			game_state.players[player_name].wealth += income
	
	print("Turn ended. Current player: ", game_state.current_player, ", Turn: ", game_state.current_turn)

# ============= ОБРАБОТЧИКИ СОБЫТИЙ =============

func _on_peer_connected(peer_id: int):
	print("Peer connected: ", peer_id)
	# Ждем регистрации игрока через RPC

func _on_peer_disconnected(peer_id: int):
	print("Peer disconnected: ", peer_id)
	
	# Находим имя игрока по peer_id
	var player_name = ""
	for name in game_state.players.keys():
		if game_state.players[name].get("peer_id") == peer_id:
			player_name = name
			break
	
	if player_name != "":
		# Удаляем игрока из состояния
		game_state.players.erase(player_name)
		connected_clients.erase(peer_id)
		
		# Уведомляем остальных
		_notify_player_left.rpc(player_name)

func _on_connected_to_server():
	print("Connected to server successfully")
	is_connected = true
	my_peer_id = multiplayer.get_unique_id()
	connection_established.emit()
	
	# Регистрируем себя на сервере
	_register_player.rpc_id(1, PlayerDatabase.current_user)

func _on_connection_failed():
	print("Failed to connect to server")
	is_connected = false
	connection_failed_signal.emit()

func _on_server_disconnected():
	print("Disconnected from server")
	is_connected = false
	# Здесь можно показать сообщение пользователю

# ============= ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ =============

func _initialize_server_game_state():
	game_state = {
		"current_turn": 1,
		"current_player": 1,
		"players": {},
		"board_state": {},
		"game_phase": "waiting"
	}

func _save_current_game_state():
	# Здесь можно добавить сохранение состояния в файл
	# для восстановления после краха сервера
	pass

func get_game_state() -> Dictionary:
	return game_state.duplicate()

func is_connected_to_server() -> bool:
	return is_connected

func get_connected_players() -> Array:
	return game_state.players.keys()

func disconnect_from_network():
	if multiplayer_peer:
		multiplayer_peer.close()
		multiplayer_peer = null
	
	is_connected = false
	connected_clients.clear()
	my_peer_id = 0

# ============= DEBUG ФУНКЦИИ =============

func print_game_state():
	print("=== Game State ===")
	print("Current Turn: ", game_state.current_turn)
	print("Current Player: ", game_state.current_player)
	print("Players: ", game_state.players.keys())
	print("Board State: ", game_state.board_state.size(), " cards placed")
	print("Connected Clients: ", connected_clients.size())

func _input(event):
	# Debug controls
	if event.is_action_pressed("ui_home"):  # Home key
		print_game_state()
