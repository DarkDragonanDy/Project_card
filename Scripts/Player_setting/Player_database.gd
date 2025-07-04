# account_database.gd - Autoload
extends Node

const ACCOUNTS_FILE = "user://accounts.dat"

var accounts: Dictionary = {}  # login: {password, deck_file}
var current_user: String = ""

func _ready():
	load_accounts()

func load_accounts():
	if FileAccess.file_exists(ACCOUNTS_FILE):
		var file = FileAccess.open(ACCOUNTS_FILE, FileAccess.READ)
		accounts = file.get_var()
		file.close()
	else:
		# Создаем тестовые аккаунты
		create_account("player1", "pass1")
		create_account("player2", "pass2")

func create_account(login: String, password: String) -> bool:
	if login in accounts:
		return false
	
	accounts[login] = {
		"password": password,
		"deck_file": "user://deck_" + login + ".dat"
	}
	save_accounts()
	return true

func verify_login(login: String, password: String) -> bool:
	return login in accounts and accounts[login].password == password

func save_accounts():
	var file = FileAccess.open(ACCOUNTS_FILE, FileAccess.WRITE)
	file.store_var(accounts)
	file.close()

func get_user_deck_path() -> String:
	if current_user in accounts:
		return accounts[current_user].deck_file
	return ""
