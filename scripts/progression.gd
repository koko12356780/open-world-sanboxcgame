extends RefCounted
## Local, single-player garage. Only actual driving distance earns coins.
const CARS = [
	{"name": "Sunset Coupe", "price": 0, "paint": Color("ff603d"), "acceleration": 14.0, "speed": 38.0, "grip": 9.0},
	{"name": "Midnight GT", "price": 120, "paint": Color("236db8"), "acceleration": 19.0, "speed": 48.0, "grip": 10.5},
	{"name": "Forest Rally", "price": 350, "paint": Color("428361"), "acceleration": 23.0, "speed": 44.0, "grip": 13.0},
	{"name":"Aurora RS","price":6000,"paint":Color("cbd1d7"),"acceleration":48.0,"speed":134.112,"grip":15.0,"description":"Nordic hypercar / 300 MPH factory cap"},
	{"name":"Volt Aero Roadster","price":12000,"paint":Color("b91e39"),"acceleration":47.897142857,"speed":111.76,"grip":17.0,"electric":true,"description":"Electric / 0–60 MPH in 0.56s / flight"}
]
var coins: int = 0
var owned: Array[int] = [0]
var selected: int = 0
var remainder: float = 0.0
var total_distance: float = 0.0
var save_path: String = "user://garage.cfg"
var last_save_ok: bool = true
const Mods = preload("res://scripts/mods.gd")
var builds: Dictionary = {}
var parts_owned: Dictionary = {}
var hints_used: Dictionary = {}
var volume: float = 0.65
var muted: bool = false
var crash_enabled: bool = true
var mouse_lock: bool = true
var snapshot: Dictionary = {}
var has_save: bool = false

func build_for(index: int = -1) -> Dictionary:
	return builds.get(str(selected if index < 0 else index),Mods.stock_build()).duplicate()

func owns_part(category: String, id: String) -> bool:
	return id == "stock" or id in parts_owned.get(str(selected),{}).get(category,[])

func choose_mod(category: String, index: int) -> String:
	var items := Mods.catalog(category)
	if index < 0 or index >= items.size(): return "Choose a valid part."
	var item: Dictionary = items[index]
	if not Mods.compatible(item,selected): return "Gas Thrusters fit the Aurora RS only."
	if CARS[selected].get("electric",false) and item.id != "stock": return "This EV uses a factory electric/flight drive; ICE parts do not fit."
	if not owns_part(category,item.id):
		if coins < item.price: return "You need %d more coins." % (item.price-coins)
		coins -= item.price
		var car_parts: Dictionary = parts_owned.get(str(selected),{})
		var unlocked: Array = car_parts.get(category,[])
		unlocked.append(item.id)
		car_parts[category] = unlocked
		parts_owned[str(selected)] = car_parts
	var build := build_for()
	build[category] = item.id
	builds[str(selected)] = build
	save_game()
	return "%s installed." % item.name

func mark_hint(action: String) -> void:
	if hints_used.get(action,false): return
	hints_used[action] = true
	save_game()

func restore_hints() -> void:
	hints_used.clear()
	save_game()

func apply_audio() -> void:
	AudioServer.set_bus_mute(0,muted or volume <= 0.001)
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.001,volume)))

func add_distance(metres: float) -> void:
	if not is_finite(metres) or metres <= 0: return
	total_distance += metres
	remainder += metres
	var earned := int(remainder / 10.0)
	coins += earned
	remainder -= earned * 10.0

func choose(index: int) -> String:
	if index < 0 or index >= CARS.size(): return "Choose a car."
	if index not in owned:
		var price: int = CARS[index].price
		if coins < price: return "You need %d more coins." % (price - coins)
		coins -= price
		owned.append(index)
	selected = index
	save_game()
	return "%s equipped!" % CARS[index].name

func save_game() -> bool:
	var config := ConfigFile.new()
	config.set_value("garage", "coins", coins)
	config.set_value("garage", "owned", owned)
	config.set_value("garage", "selected", selected)
	config.set_value("garage", "remainder", remainder)
	config.set_value("garage", "distance", total_distance)
	config.set_value("workshop","builds",builds)
	config.set_value("workshop","parts",parts_owned)
	config.set_value("preferences","hints",hints_used)
	config.set_value("preferences","volume",volume)
	config.set_value("preferences","muted",muted)
	config.set_value("preferences","crashes",crash_enabled)
	config.set_value("preferences","mouse_lock",mouse_lock)
	config.set_value("world","snapshot",snapshot)
	last_save_ok = config.save(save_path) == OK
	if last_save_ok: has_save = true
	return last_save_ok

func load_game() -> void:
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		if save_path != "user://garage.cfg": return
		# Migrate one matching previous edition without changing its original file.
		var parent := OS.get_user_data_dir().get_base_dir()
		var candidates: Array[String] = []
		for directory in DirAccess.get_directories_at(parent):
			var previous := parent.path_join(directory).path_join("garage.cfg")
			if directory.ends_with(" - OPEN STREETS") and FileAccess.file_exists(previous): candidates.append(previous)
		if candidates.size() != 1 or config.load(candidates[0]) != OK: return
	has_save = true
	coins = clampi(int(config.get_value("garage", "coins", 0)), 0, 100000000)
	owned = [0]
	var stored = config.get_value("garage", "owned", [0])
	if stored is Array:
		for index in stored:
			if index is int and index >= 0 and index < CARS.size() and index not in owned:
				owned.append(index)
	selected = int(config.get_value("garage", "selected", 0))
	if selected not in owned: selected = 0
	remainder = float(config.get_value("garage", "remainder", 0.0))
	if not is_finite(remainder): remainder = 0.0
	remainder = clampf(remainder, 0, 9.999)
	total_distance = float(config.get_value("garage", "distance", 0.0))
	if not is_finite(total_distance): total_distance = 0.0
	total_distance = maxf(0, total_distance)
	builds.clear()
	parts_owned.clear()
	var stored_parts = config.get_value("workshop","parts",{})
	var stored_builds = config.get_value("workshop","builds",{})
	for index in owned:
		var key := str(index)
		var valid_parts: Dictionary = {}
		var valid_build := Mods.stock_build()
		for category in Mods.CATEGORIES:
			var ids: Array = ["stock"]
			if stored_parts is Dictionary and stored_parts.get(key,{}) is Dictionary:
				var values = stored_parts.get(key,{}).get(category,[])
				if values is Array:
					for item in Mods.catalog(category):
						if item.id in values and item.id not in ids and Mods.compatible(item,index): ids.append(item.id)
			valid_parts[category] = ids
			if stored_builds is Dictionary and stored_builds.get(key,{}) is Dictionary:
				var id = stored_builds.get(key,{}).get(category,"stock")
				if id in ids: valid_build[category] = id
		parts_owned[key] = valid_parts
		builds[key] = valid_build
	var hints = config.get_value("preferences","hints",{})
	if hints is Dictionary:
		for action in ["night","view","garage"]: hints_used[action] = bool(hints.get(action,false))
	volume = float(config.get_value("preferences","volume",0.65))
	if not is_finite(volume): volume = 0.65
	volume = clampf(volume,0,1)
	muted = bool(config.get_value("preferences","muted",false))
	crash_enabled = bool(config.get_value("preferences","crashes",true))
	mouse_lock = bool(config.get_value("preferences","mouse_lock",true))
	var world = config.get_value("world","snapshot",{})
	snapshot = world if world is Dictionary else {}
	apply_audio()
