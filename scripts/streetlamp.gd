extends SpotLight3D
## Independent schedules: a brief, occasional fault, never a synchronized strobe.
var fixture: StandardMaterial3D
var rng := RandomNumberGenerator.new()
var night_enabled: bool = false
var nearby: bool = false
var next_fault: float = 0.0
var remaining: float = 0.0
var pulse_time: float = 0.0
var fault_count: int = 0
var brightness: float = 1.0

func _ready() -> void:
	rng.randomize()
	next_fault = rng.randf_range(8, 55)

func configure(enabled: bool, in_range: bool) -> void:
	night_enabled = enabled
	nearby = in_range
	visible = enabled and in_range
	if not enabled or not in_range:
		remaining = 0
		brightness = 1
		light_energy = 5
	if not enabled and fixture != null:
		fixture.emission_energy_multiplier = 0.0
	elif fixture != null:
		fixture.emission_energy_multiplier = brightness

func start_fault() -> void:
	remaining = rng.randf_range(0.45, 1.1)
	pulse_time = 0
	fault_count += 1

func _process(delta: float) -> void:
	if not night_enabled or not nearby: return
	if remaining > 0:
		remaining -= delta
		pulse_time -= delta
		if pulse_time <= 0:
			brightness = rng.randf_range(0.04, 0.25) if brightness > 0.5 else 1.0
			pulse_time = rng.randf_range(0.12, 0.22)
		if remaining <= 0:
			brightness = 1
			next_fault = rng.randf_range(25, 80)
	else:
		next_fault -= delta
		if next_fault <= 0: start_fault()
	light_energy = 5.0 * brightness
	if fixture != null: fixture.emission_energy_multiplier = brightness
