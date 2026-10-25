extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.set_meta("testing",true)
	root.size=Vector2i(1280,720)
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in 90: await process_frame
	for night in [false,true]:
		game.set_night(night)
		for i in 60: await process_frame
		var start: int=Time.get_ticks_msec()
		for i in 120: await process_frame
		print("STEADY %s: %.1f FPS, process %.2f ms, physics %.2f ms" % ["night" if night else "day",120000.0/(Time.get_ticks_msec()-start),Performance.get_monitor(Performance.TIME_PROCESS)*1000,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000])
	print("Visual runtime completed with day/night lighting and scenery batching.")
	quit()
