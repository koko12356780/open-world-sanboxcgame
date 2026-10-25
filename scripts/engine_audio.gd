extends Node
## Original synthesized loops, crossfaded by throttle and pitched from shared RPM.
var car: CharacterBody3D
var idle: AudioStreamPlayer
var loaded: AudioStreamPlayer
var road: AudioStreamPlayer
var turbo: AudioStreamPlayer
var effects: AudioStreamPlayer
var exhaust_pop: AudioStreamPlayer
var tires: AudioStreamPlayer
var previous_load: float = 0.0
var previous_speed: float = 0.0
var effect_timer: float = 0.0
var exhaust_gain: float = 0.68
var exhaust_id: String = "stock"
var induction_id: String = "stock"
var sound_key: String = ""

func player() -> AudioStreamPlayer:
	var node := AudioStreamPlayer.new()
	node.volume_db = -40
	add_child(node)
	return node

func loop(path: String) -> AudioStreamWAV:
	var stream: AudioStreamWAV = load("res://audio/"+path)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size()/2
	return stream

func _ready() -> void:
	idle = player()
	loaded = player()
	road = player()
	turbo = player()
	effects = player()
	exhaust_pop = player()
	tires = player()
	tires.stream = loop("tire_squeal.wav")
	tires.play()
	road.stream = loop("road.wav")
	turbo.stream = loop("turbo.wav")
	road.play()
	turbo.play()

func configure(tune: Dictionary) -> void:
	exhaust_id = tune.exhaust.id
	induction_id = tune.induction.id
	exhaust_gain = tune.exhaust.volume
	sound_key = "electric" if tune.get("electric",false) else "%d_%s" % [tune.engine.cyl,exhaust_id]
	idle.stream = loop(sound_key+"_idle.wav")
	loaded.stream = loop(sound_key+"_load.wav")
	idle.play()
	loaded.play()
	previous_load = 0

func _process(delta: float) -> void:
	if idle.stream == null: return
	effect_timer = maxf(0,effect_timer-delta)
	var power: float = car.throttle_amount
	var pitch: float = clampf(car.rpm/1800.0,0.4,5.1)
	idle.pitch_scale = pitch
	loaded.pitch_scale = pitch
	var interior: bool = car.interior_view
	var cabin_gain := 0.75 if interior else 1.0
	idle.volume_linear = (0.36-0.20*power)*exhaust_gain*cabin_gain
	loaded.volume_linear = (0.06+0.72*power)*exhaust_gain*cabin_gain
	road.pitch_scale = 0.6+car.speed_kmh/160.0
	road.volume_linear = minf(car.speed_kmh/180.0,1)*0.20
	turbo.pitch_scale = 0.7+car.rpm/8000.0
	turbo.volume_linear = (0.30 if induction_id == "twin_turbo" else 0.17)*power*clampf(car.rpm/5000.0,0,1) if induction_id in ["turbo","twin_turbo"] else 0.0
	if previous_load > 0.5 and power < 0.1 and car.rpm > 2400 and effect_timer <= 0:
		if induction_id in ["turbo","twin_turbo"]: effect("blowoff.wav",0.55)
		if exhaust_id in ["straight_pipe","race"]:
			exhaust_pop.stream = load("res://audio/pop.wav")
			exhaust_pop.volume_linear = 0.42
			exhaust_pop.play()
			effect_timer = 0.35
	if previous_speed-car.speed_kmh > 20 and car.is_on_wall() and effect_timer <= 0: effect("impact.wav",0.6)
	tires.volume_linear = (0.38 if car.burnout_active else 0.2 if car.is_on_floor() and absf(car.velocity.dot(car.global_basis.x)) > 6 else 0.0)*cabin_gain
	previous_load = power
	previous_speed = car.speed_kmh

func effect(path: String, gain: float) -> void:
	effects.stream = load("res://audio/"+path)
	effects.volume_linear = gain
	effects.play()
	effect_timer = 0.35

func _exit_tree() -> void:
	for node in [idle,loaded,road,turbo,effects,exhaust_pop,tires]:
		if is_instance_valid(node):
			node.stop()
			node.stream = null
