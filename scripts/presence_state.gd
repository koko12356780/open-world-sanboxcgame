extends RefCounted
static func describe(game: Node3D) -> Dictionary:
	var car_name: String = game.progress.CARS[game.progress.selected].name
	var time := "at night" if game.night else "by day"
	var action := "Flying" if game.car.flight_active else "Burning rubber" if game.car.burnout_active else "Driving"
	if game.walker!=null and game.walker.active:action="Walking"
	if game.get_tree().paused: action = "Parked"
	var details := "%s %s in the %s" % [action,time,car_name]
	if game.title_open: details = "In the main menu"
	var p: Vector3 = game.car.global_position
	var district := "North Test Highway" if p.z < -602 else "South Test Highway" if p.z > 602 else "Riverside" if p.x > 300 else "West District" if p.x < -300 else "City Centre"
	if game.regions!=null and game.regions.in_ice:district="Ice City / Frozen District"
	return {"pid":OS.get_process_id(),"updated":Time.get_unix_time_from_system(),"details":details,"state":district,"version":"0.11 Street Explorer"}
