extends RefCounted
## Arcade tuning values, not claims about real-world vehicle modifications.
const ENGINES = [
	{"id":"stock","name":"Factory engine","price":0,"accel":1.0,"speed":1.0,"grip":1.0,"cyl":4,"rpm":6800.0,"note":"Balanced factory tune"},
	{"id":"i6","name":"Inline-six swap","price":180,"accel":1.12,"speed":1.06,"grip":1.0,"cyl":6,"rpm":7200.0,"note":"Smooth six-cylinder growl"},
	{"id":"v8","name":"V8 swap","price":400,"accel":1.28,"speed":1.12,"grip":0.98,"cyl":8,"rpm":6800.0,"note":"Deep, uneven exhaust rumble"},
	{"id":"v10","name":"V10 swap","price":650,"accel":1.38,"speed":1.19,"grip":0.96,"cyl":10,"rpm":8000.0,"note":"Sharper, high-revving howl"},
	{"id":"v12","name":"V12 swap","price":950,"accel":1.50,"speed":1.25,"grip":0.94,"cyl":12,"rpm":8500.0,"note":"Dense, smooth exhaust note"},
	{"id":"v16","name":"V16 swap","price":1500,"accel":1.65,"speed":1.32,"grip":0.90,"cyl":16,"rpm":9000.0,"note":"Big power, heavier handling"}
]
const EXHAUSTS = [
	{"id":"stock","name":"Factory muffler","price":0,"accel":1.0,"speed":1.0,"volume":0.68,"note":"Quiet and mellow"},
	{"id":"muffler_delete","name":"Muffler delete","price":60,"accel":1.025,"speed":1.005,"volume":0.9,"note":"Louder bass and rasp"},
	{"id":"straight_pipe","name":"Straight pipe","price":140,"accel":1.06,"speed":1.025,"volume":1.05,"note":"Raw, raspy note + lift-off pops"},
	{"id":"sport","name":"Sport cat-back","price":100,"accel":1.04,"speed":1.02,"volume":0.82,"note":"Deeper, controlled sport tone"},
	{"id":"race","name":"Titanium race exhaust","price":260,"accel":1.09,"speed":1.04,"volume":1.0,"note":"Bright race tone + lift-off pops"}
]
const INDUCTION = [
	{"id":"stock","name":"Naturally aspirated","price":0,"accel":1.0,"speed":1.0,"note":"No boost; clean engine sound"},
	{"id":"turbo","name":"Street turbo","price":220,"accel":1.12,"speed":1.06,"note":"Boost whistle + blow-off valve"},
	{"id":"twin_turbo","name":"Twin-turbo kit","price":550,"accel":1.24,"speed":1.12,"note":"Stronger boost and louder whistle"},
	{"id":"gas_thrusters","name":"Gas Thrusters","price":2500,"accel":1.40,"speed":1.10,"model":3,"note":"Rear gas thrusters for the Aurora RS only. Automatic thrust when you accelerate."}
]
const CATEGORIES = ["engine","exhaust","induction"]

static func catalog(category: String) -> Array:
	match category:
		"engine": return ENGINES
		"exhaust": return EXHAUSTS
		"induction": return INDUCTION
	return []

static func part(category: String, id: String) -> Dictionary:
	for item in catalog(category):
		if item.id == id: return item
	return catalog(category)[0] if category in CATEGORIES else {}

static func stock_build() -> Dictionary:
	return {"engine":"stock","exhaust":"stock","induction":"stock"}

static func compatible(item: Dictionary, model: int) -> bool:
	return not item.has("model") or int(item.model) == model

static func tune(base: Dictionary, build: Dictionary, model: int) -> Dictionary:
	var engine := part("engine",str(build.get("engine","stock"))).duplicate()
	if engine.id == "stock" and model == 1: engine.cyl = 6
	if engine.id == "stock" and model == 3:
		engine.cyl = 8
		engine.rpm = 8500.0
		engine.name = "Factory hyper V8"
	var exhaust := part("exhaust",str(build.get("exhaust","stock")))
	var induction := part("induction",str(build.get("induction","stock")))
	if not compatible(induction,model): induction = INDUCTION[0]
	if base.get("electric",false):
		engine = {"id":"electric","name":"Electric flight drive","cyl":0,"rpm":10000.0,"accel":1.0,"speed":1.0,"grip":1.0}
		exhaust = EXHAUSTS[0]
		induction = INDUCTION[0]
	return {"engine":engine,"exhaust":exhaust,"induction":induction,
		"thrusters":model == 3 and induction.id == "gas_thrusters",
		"electric":bool(base.get("electric",false)),
		"acceleration":float(base.acceleration)*engine.accel*exhaust.accel*induction.accel,
		"speed":float(base.speed)*engine.speed*exhaust.speed*induction.speed,
		"grip":float(base.grip)*engine.grip}
