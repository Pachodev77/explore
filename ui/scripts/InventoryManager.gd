extends Node

# --- GESTOR DE INVENTARIO PRO ---
# Gestiona los objetos reales del jugador y emite señales cuando cambian

signal inventory_updated
signal item_added(id, amount)

var items = {
	"wood": {"name": "Madera", "qty": 0, "icon": "res://ui/icons/item_wood.jpg"},
	"stone": {"name": "Piedra", "qty": 0, "icon": "res://ui/icons/item_stone.jpg"},
	"milk": {"name": "Leche", "qty": 0, "icon": "res://ui/icons/item_milk.jpg"},
	"berries": {"name": "Bayas", "qty": 0, "icon": "res://ui/icons/item_berries.jpg"}
}

func _ready():
	ServiceLocator.register_service("inventory", self)

func add_item(id, amount):
	if items.has(id):
		items[id].qty += amount
		emit_signal("inventory_updated")
		emit_signal("item_added", id, amount)
		return true
	return false

func get_items_list():
	var list = []
	# Orden específico para mantener consistencia en la UI
	var order = ["wood", "stone", "milk", "berries"]
	for id in order:
		if items.has(id):
			var item = items[id].duplicate()
			item["id"] = id
			list.append(item)
	return list

func get_item_qty(id):
	if items.has(id):
		return items[id].qty
	return 0

func get_save_data():
	var save = {}
	for id in items.keys():
		save[id] = items[id].qty
	return save

func load_save_data(data):
	if typeof(data) != TYPE_DICTIONARY: return
	for id in data.keys():
		if items.has(id):
			items[id].qty = int(data[id])
	emit_signal("inventory_updated")
