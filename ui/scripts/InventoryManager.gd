extends Node

# =============================================================================
# InventoryManager.gd - GESTOR DE INVENTARIO (Mejorado)
# =============================================================================
# Gestiona los objetos del jugador con señales para notificar cambios.
# Uso: InventoryManager.add_item("wood", 3)
# =============================================================================

signal inventory_updated
signal item_added(id, amount)
signal item_removed(id, amount)

# --- DEFINICIÓN DE ITEMS ---
# Cada item tiene: nombre visible, cantidad, ruta del icono
var items: Dictionary = {
	"wood": {"name": "Madera", "qty": 0, "icon": "res://ui/icons/item_wood.jpg"},
	"stone": {"name": "Piedra", "qty": 0, "icon": "res://ui/icons/item_stone.jpg"},
	"milk": {"name": "Leche", "qty": 0, "icon": "res://ui/icons/item_milk.jpg"},
	"berries": {"name": "Bayas", "qty": 0, "icon": "res://ui/icons/item_berries.jpg"}
}

# Orden de display para UI consistente
const ITEM_ORDER: Array = ["wood", "stone", "milk", "berries"]

func _ready() -> void:
	ServiceLocator.register_service("inventory", self)

# =============================================================================
# API PÚBLICA
# =============================================================================

func add_item(item_id: String, amount: int = 1) -> bool:
	"""Añade cantidad de un item. Retorna true si el item existe."""
	if not items.has(item_id):
		push_warning("InventoryManager: Item desconocido: " + item_id)
		return false
	
	items[item_id].qty += amount
	emit_signal("inventory_updated")
	emit_signal("item_added", item_id, amount)
	GameEvents.emit_signal("item_collected", item_id, amount)
	return true

func remove_item(item_id: String, amount: int = 1) -> bool:
	"""Quita cantidad de un item. Retorna false si no hay suficiente."""
	if not items.has(item_id):
		return false
	
	if items[item_id].qty < amount:
		return false
	
	items[item_id].qty -= amount
	emit_signal("inventory_updated")
	emit_signal("item_removed", item_id, amount)
	return true

func has_item(item_id: String, amount: int = 1) -> bool:
	"""Verifica si hay al menos 'amount' unidades del item."""
	if not items.has(item_id):
		return false
	return items[item_id].qty >= amount

func get_item_qty(item_id: String) -> int:
	"""Obtiene la cantidad actual de un item."""
	if items.has(item_id):
		return items[item_id].qty
	return 0

func get_item_data(item_id: String) -> Dictionary:
	"""Obtiene los datos completos de un item."""
	if items.has(item_id):
		var data = items[item_id].duplicate()
		data["id"] = item_id
		return data
	return {}

func get_items_list() -> Array:
	"""Obtiene lista ordenada de todos los items para UI."""
	var list: Array = []
	for id in ITEM_ORDER:
		if items.has(id):
			var item = items[id].duplicate()
			item["id"] = id
			list.append(item)
	return list

# =============================================================================
# PERSISTENCIA
# =============================================================================

func get_save_data() -> Dictionary:
	"""Retorna datos para guardar."""
	var save: Dictionary = {}
	for id in items.keys():
		save[id] = items[id].qty
	return save

func load_save_data(data) -> void:
	"""Carga datos desde guardado."""
	if typeof(data) != TYPE_DICTIONARY:
		return
	for id in data.keys():
		if items.has(id):
			items[id].qty = int(data[id])
	emit_signal("inventory_updated")

func reset() -> void:
	"""Resetea el inventario a cero."""
	for id in items.keys():
		items[id].qty = 0
	emit_signal("inventory_updated")
