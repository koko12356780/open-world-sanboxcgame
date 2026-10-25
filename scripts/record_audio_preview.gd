extends SceneTree
## Records the actual game mixer; --audio-driver Dummy works without speakers.
func _initialize() -> void:
	call_deferred("record")
func record() -> void:
	root.set_meta("testing",true)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.car.set_physics_process(false)
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 0.5
	AudioServer.add_bus_effect(0,capture)
	var samples := PackedVector2Array()
	var profiles := [
		{"engine":"stock","exhaust":"stock","induction":"stock"},
		{"engine":"v8","exhaust":"muffler_delete","induction":"stock"},
		{"engine":"v8","exhaust":"straight_pipe","induction":"turbo"},
		{"engine":"v16","exhaust":"race","induction":"twin_turbo"}]
	for build in profiles:
		game.car.apply_mods(build)
		var started := Time.get_ticks_msec()
		while Time.get_ticks_msec()-started < 2500:
			var phase := (Time.get_ticks_msec()-started)/2500.0
			game.car.rpm = 850+pow(sin(PI*phase),2)*(float(game.car.tune.engine.rpm)-1800)
			game.car.throttle_amount = 1 if phase < 0.75 else 0
			game.car.speed_kmh = 60*sin(PI*phase)
			await process_frame
			var available := capture.get_frames_available()
			if available > 0: samples.append_array(capture.get_buffer(available))
	var bytes := PackedByteArray()
	bytes.resize(samples.size()*4)
	var peak: float = 0
	for i in samples.size():
		bytes.encode_s16(i*4,int(clampf(samples[i].x,-1,1)*32767))
		bytes.encode_s16(i*4+2,int(clampf(samples[i].y,-1,1)*32767))
		peak = maxf(peak,maxf(absf(samples[i].x),absf(samples[i].y)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = AudioServer.get_mix_rate()
	wav.stereo = true
	wav.data = bytes
	var error := wav.save_to_wav("res://audio-preview.wav")
	print("Recorded %d frames; peak %.3f; save status %d" % [samples.size(),peak,error])
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	DirAccess.remove_absolute(game.progress.save_path)
	quit(error)
