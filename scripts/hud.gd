extends Control
const Mods = preload("res://scripts/mods.gd")
var car: CharacterBody3D
var game: Node3D
var checkpoint: Vector3
var collected: int = 0
var paused: bool = false
var garage_message: String = "Parts belong to this car. Owned parts can be refitted free."
var control_row: HBoxContainer
var night_button: Button
var view_button: Button
var garage_button: Button
var menu_button: Button
var backdrop: ColorRect
var garage_panel: PanelContainer
var garage_status: Label
var garage_buttons: Array[Button] = []
var garage_tabs: TabContainer
var mod_choices: Dictionary = {}
var mod_buttons: Dictionary = {}
var mod_details: Dictionary = {}
var mod_stats: Label
var pause_panel: PanelContainer
var pause_tabs: TabContainer
var controls_night: Button
var controls_view: Button
var controls_garage: Button
var volume_slider: HSlider
var mute_button: CheckButton
var volume_label: Label
var pause_stats: Label
var pause_nav: Control
var main_panel: Control
var credits_panel: PanelContainer
var new_game_dialog: ConfirmationDialog
var mouse_toggle: CheckButton
var crash_toggle: CheckButton
var continue_button: Button
var load_button: Button
var options_title: Label
var main_buttons: Array[Button] = []
var pause_buttons: Array[Button] = []
var was_main_visible: bool = false
var was_pause_visible: bool = false

func panel(color: Color = Color(0.025,0.045,0.065,0.97)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.border_color = Color(0.25,0.39,0.48,0.4)
	return style

func label(parent: Node, caption: String, font_size: int = 18) -> Label:
	var node := Label.new()
	node.text = caption
	node.add_theme_font_size_override("font_size",font_size)
	parent.add_child(node)
	return node

func button(parent: Node, caption: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = caption
	node.focus_mode = Control.FOCUS_NONE
	node.custom_minimum_size.y = 42
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_stylebox_override("normal",panel(Color("20342f")))
	node.add_theme_stylebox_override("hover",panel(Color("315b4c")))
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func column(parent: Node) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation",14)
	parent.add_child(node)
	return node

func framed(pos: Vector2, dimensions: Vector2) -> PanelContainer:
	var node := PanelContainer.new()
	node.position = pos
	node.size = dimensions
	node.add_theme_stylebox_override("panel",panel())
	add_child(node)
	return node

func padded(parent: Node, amount: int = 24) -> MarginContainer:
	var node := MarginContainer.new()
	for edge in ["left","right","top","bottom"]: node.add_theme_constant_override("margin_"+edge,amount)
	parent.add_child(node)
	return node

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	control_row = HBoxContainer.new()
	control_row.size = Vector2(420,44)
	control_row.add_theme_constant_override("separation",8)
	add_child(control_row)
	night_button = button(control_row,"Night [N]",game.toggle_night)
	view_button = button(control_row,"First person [V]",game.toggle_first_person)
	garage_button = button(control_row,"Garage [G]",game.toggle_garage)
	menu_button = button(self,"MENU / ESC",game.set_paused.bind(true))
	menu_button.size = Vector2(154,38)
	backdrop = ColorRect.new()
	backdrop.color = Color(0.008,0.016,0.025,0.72)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	build_garage()
	build_pause()
	build_navigation()
	refresh_garage()
	refresh_menus()

func build_garage() -> void:
	garage_panel = framed(Vector2(100,75),Vector2(1080,570))
	var col := column(padded(garage_panel))
	label(col,"GARAGE + WORKSHOP",28)
	garage_status = label(col,"",16)
	garage_tabs = TabContainer.new()
	garage_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(garage_tabs)
	var cars := ScrollContainer.new()
	cars.name = "Cars"
	garage_tabs.add_child(cars)
	var cars_col := column(cars)
	cars_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := GridContainer.new()
	row.columns = 3
	row.add_theme_constant_override("h_separation",22)
	row.add_theme_constant_override("v_separation",22)
	cars_col.add_child(row)
	for i in game.progress.CARS.size():
		var spec: Dictionary = game.progress.CARS[i]
		var card := column(row)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.x = 315
		var swatch := ColorRect.new()
		swatch.color = spec.paint
		swatch.custom_minimum_size.y = 14
		card.add_child(swatch)
		label(card,spec.name,22)
		var description: String = spec.get("description",["Balanced starter coupe","Fast road car / wing + splitter","Extra grip / rally equipment"][mini(i,2)])
		var details := label(card,"%d MPH factory cap\n%.1f m/s^2 factory acceleration\n%s" % [roundi(spec.speed*2.2369362921),spec.acceleration,description],16)
		details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.custom_minimum_size = Vector2(315,90)
		garage_buttons.append(button(card,"",game.choose_car.bind(i)))
	label(cars_col,"Your engine, exhaust and boost choices are saved separately for each car.",16)
	var workshop := column(garage_tabs)
	workshop.name = "Workshop"
	mod_stats = label(workshop,"",19)
	label(workshop,"Choose a part, then buy/install it. Switching an owned part is free.",16)
	var mods_row := HBoxContainer.new()
	mods_row.add_theme_constant_override("separation",18)
	workshop.add_child(mods_row)
	for category in Mods.CATEGORIES:
		var card := column(mods_row)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label(card,"BOOST / THRUSTERS" if category == "induction" else category.to_upper(),18)
		var options := OptionButton.new()
		options.custom_minimum_size = Vector2(300,42)
		options.focus_mode = Control.FOCUS_NONE
		card.add_child(options)
		mod_choices[category] = options
		mod_details[category] = label(card,"",16)
		mod_details[category].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mod_details[category].custom_minimum_size = Vector2(295,96)
		options.item_selected.connect(part_selected.bind(category))
		mod_buttons[category] = button(card,"",install_selected.bind(category))
	button(col,"BACK TO THE STREETS   [G / ESC]",game.set_garage.bind(false))

func build_pause() -> void:
	pause_panel = framed(Vector2(140,55),Vector2(1000,610))
	var col := column(padded(pause_panel))
	options_title = label(col,"OPTIONS",28)
	pause_tabs = TabContainer.new()
	pause_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(pause_tabs)
	var controls := HBoxContainer.new()
	controls.name = "Controls"
	controls.add_theme_constant_override("separation",32)
	pause_tabs.add_child(controls)
	label(controls,"W / Up                 Accelerate\nS / Down              Brake / reverse\nA D / Left Right     Steer\nSpace                   Handbrake\nR                         Reset car\nC                         Cycle cameras\nV                         First person / chase\nN                         Day / night\nG                         Garage + workshop\n1Ã¢â‚¬â€œ5                      Choose car in garage\nESC                      Pause / resume\nQ (while paused)   Save + quit\nM                        Lock / release mouse\nW + Space            Burnout at low speed\nF                         Toggle EV flight\nSpace / Ctrl           Flight climb / descend",17)
	var actions := column(controls)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_night = button(actions,"TOGGLE DAY / NIGHT   [N]",game.toggle_night)
	controls_view = button(actions,"FIRST PERSON / CHASE   [V]",game.toggle_first_person)
	controls_garage = button(actions,"GARAGE + WORKSHOP   [G]",game.set_garage.bind(true))
	button(actions,"SHOW FIRST-USE HINTS AGAIN",restore_hints)
	label(actions,"Used shortcut buttons disappear from the road.\nYou can always find them here.",16)
	label(actions,"E: leave / enter car. Shift: run on foot.\nSpace: jump. R: return to car.\n\nICE CITY\nFly the Roadster through the blue roof gate\non the northwest tower, 68 m above the city.\nFollow the blue ring on the radar.\nThe ice district has a return gate.\nR resets you in your current district.",16)
	var audio := column(pause_tabs)
	audio.name = "Audio"
	volume_label = label(audio,"Master volume",22)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.step = 1
	volume_slider.value = game.progress.volume*100
	volume_slider.custom_minimum_size.y = 40
	audio.add_child(volume_slider)
	volume_slider.value_changed.connect(set_volume)
	mute_button = CheckButton.new()
	mute_button.text = "Mute all sounds"
	mute_button.button_pressed = game.progress.muted
	audio.add_child(mute_button)
	mute_button.toggled.connect(set_mute)
	label(audio,"Engine note follows RPM and throttle.\nExhaust and engine swaps change the tone.\nTurbo kits add boost whistle and blow-off sounds.\n\nDriving audio pauses in menus. Resume to hear your installed build.",18)
	var gameplay := column(pause_tabs)
	gameplay.name = "Gameplay"
	label(gameplay,"CRASH PHYSICS",24)
	crash_toggle = CheckButton.new()
	crash_toggle.text = "Impact damage, rebound and breakaway debris"
	crash_toggle.button_pressed = game.progress.crash_enabled
	gameplay.add_child(crash_toggle)
	crash_toggle.toggled.connect(game.set_crashes)
	label(gameplay,"Crashes deform the body, throw physical debris and shake the camera.\nDamage reduces power and top speed; press R to repair/reset.\nSwitch this off for normal collisions without damage or rebound.\n\nVolt Aero Roadster: F flight, Space climb, Ctrl descend.\nThe 0.56-second launch and flight are fictional arcade abilities.",18)
	mouse_toggle = CheckButton.new()
	mouse_toggle.text = "Lock mouse while driving / M to release"
	gameplay.add_child(mouse_toggle)
	mouse_toggle.toggled.connect(game.set_mouse_lock)
	button(col,"BACK   [ESC]",close_options)

func open_options() -> void:
	game.options_open = true
	if not game.title_open:
		paused = true
		game.get_tree().paused = true
	refresh_menus()

func close_options() -> void:
	game.options_open = false
	refresh_menus()

func set_volume(value: float) -> void:
	game.progress.volume = value/100
	game.progress.apply_audio()
	game.progress.save_game()
	volume_label.text = "Master volume / %d%%" % int(value)

func set_mute(value: bool) -> void:
	game.progress.muted = value
	game.progress.apply_audio()
	game.progress.save_game()

func reset_and_resume() -> void:
	if game.walker!=null:game.walker.enter()
	car.reset_car()
	game.set_paused(false)

func refresh_menus() -> void:
	if pause_panel == null or main_panel == null: return
	pause_panel.visible = game.options_open
	pause_nav.visible = paused and not game.options_open and not game.garage_open and not game.title_open
	garage_panel.visible = game.garage_open
	main_panel.visible = game.title_open and not game.options_open and not credits_panel.visible
	backdrop.visible = paused or game.garage_open or game.title_open or game.options_open
	backdrop.color = Color(0.005,0.01,0.025,0.36 if game.title_open or pause_nav.visible else 0.78)
	continue_button.disabled = not game.session_started and not game.progress.has_save
	load_button.disabled = not game.progress.has_save
	options_title.text = "OPTIONS  /  OPEN STREETS"
	mouse_toggle.set_pressed_no_signal(game.progress.mouse_lock)
	if crash_toggle.button_pressed != game.progress.crash_enabled:
		crash_toggle.set_pressed_no_signal(game.progress.crash_enabled)
	if main_panel.visible and not was_main_visible:
		(main_buttons[0] if not continue_button.disabled else main_buttons[1]).grab_focus()
	if pause_nav.visible and not was_pause_visible: pause_buttons[0].grab_focus()
	was_main_visible = main_panel.visible
	was_pause_visible = pause_nav.visible

func restore_hints() -> void:
	game.progress.restore_hints()

func refresh_part(category: String) -> void:
	var option: OptionButton = mod_choices[category]
	var part: Dictionary = Mods.catalog(category)[option.selected]
	var installed: bool = game.progress.build_for()[category] == part.id
	var owned: bool = game.progress.owns_part(category,part.id)
	var details: Label = mod_details[category]
	details.text = "%s\n\nAcceleration +%.1f%% / speed +%.1f%%" % [part.note,(part.accel-1)*100,(part.speed-1)*100]
	mod_buttons[category].text = "INSTALLED" if installed else ("EQUIP / OWNED" if owned else "BUY / %d COINS" % part.price)
	var electric: bool = car.tune.get("electric",false)
	var fits: bool = Mods.compatible(part,game.progress.selected)
	mod_choices[category].disabled = electric
	mod_buttons[category].disabled = installed or electric or not fits
	if not fits: mod_buttons[category].text = "AURORA RS ONLY"
	if electric:
		mod_buttons[category].text = "FACTORY EV DRIVE"
		details.text = "Electric drive: 0-60 MPH in 0.56s.\nF enables flight. Combustion parts do not fit."

func part_selected(_index: int, category: String) -> void:
	refresh_part(category)

func install_selected(category: String) -> void:
	game.install_mod(category,mod_choices[category].selected)

func refresh_garage() -> void:
	if garage_panel == null: return
	for i in garage_buttons.size():
		garage_buttons[i].text = "[%d] %s" % [i+1,"EQUIPPED" if game.progress.selected == i else ("EQUIP" if i in game.progress.owned else "BUY / %d COINS" % game.progress.CARS[i].price)]
		garage_buttons[i].disabled = game.progress.selected == i
	garage_status.text = "%d COINS  /  %s  /  %s" % [game.progress.coins,game.progress.CARS[game.progress.selected].name,garage_message]
	mod_stats.text = "INSTALLED BUILD:  %.1f m/s^2 acceleration   /   %d KM/H cap   /   %.1f grip" % [car.acceleration,int(car.max_speed*3.6),car.grip]
	for category in Mods.CATEGORIES:
		var option: OptionButton = mod_choices[category]
		option.clear()
		for i in Mods.catalog(category).size():
			var part: Dictionary = Mods.catalog(category)[i]
			option.add_item(part.name+(" / owned" if game.progress.owns_part(category,part.id) else " / %d" % part.price))
			option.set_item_disabled(i,not Mods.compatible(part,game.progress.selected))
			if part.id == game.progress.build_for()[category]: option.select(i)
		refresh_part(category)
	refresh_menus()

func _process(_delta: float) -> void:
	control_row.position = Vector2(650,24) if game.chase.mode == 2 else Vector2(394,24)
	night_button.text = "Day [N]" if game.night else "Night [N]"
	view_button.text = "Chase [V]" if game.chase.mode == 2 else "First person [V]"
	night_button.visible = not game.progress.hints_used.get("night",false)
	view_button.visible = not game.progress.hints_used.get("view",false)
	garage_button.visible = not game.progress.hints_used.get("garage",false)
	control_row.visible = not paused and not game.garage_open and not game.title_open
	menu_button.visible = not paused and not game.garage_open and not game.title_open
	menu_button.position = Vector2(24,size.y-58)
	refresh_menus()
	queue_redraw()

func text_at(pos: Vector2, caption: String, font_size: int, color: Color = Color.WHITE) -> void:
	draw_string(ThemeDB.fallback_font,pos,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _draw() -> void:
	var w := size.x
	var h := size.y
	var mint := Color("8ff0cb")
	var dim := Color("91a6b8")
	var car_name: String = game.progress.CARS[game.progress.selected].name
	if game.title_open: return
	if game.walker!=null and game.walker.active:
		draw_style_box(panel(),Rect2(24,24,336,96))
		text_at(Vector2(44,51),"OPEN STREETS / ON FOOT",18,mint)
		text_at(Vector2(44,77),"WASD walk / Shift run / Space jump",13,dim)
		var metres: int=int(game.walker.global_position.distance_to(car.global_position))
		text_at(Vector2(44,101),"E drive / Your car: %d m / R return" % metres,13,mint)
		draw_circle(Vector2(w*.5,h*.5),2,Color(1,1,1,.65))
		draw_walking_message()
		draw_portal_hint()
		return
	if game.chase.mode == 2:
		draw_style_box(panel(Color(0.025,0.045,0.065,0.85)),Rect2(24,20,380,62))
		text_at(Vector2(42,46),car_name,18)
		text_at(Vector2(42,69),"%d COINS  /  %s  /  M MOUSE" % [game.progress.coins,"NIGHT" if game.night else "DAY"],13,mint)
		if car.burnout_active: text_at(Vector2(w/2-53,h-80),"BURNOUT",20,mint)
		elif car.tune.get("thrusters",false) and car.thruster_effects.power > 0.2: text_at(Vector2(w/2-80,h-80),"GAS THRUSTERS",20,mint)
		draw_portal_hint()
		draw_walking_message()
		return
	draw_walking_message()
	# Small identity strip leaves the road and skyline unobstructed.
	draw_style_box(panel(),Rect2(24,24,336,102))
	text_at(Vector2(44,49),"OPEN STREETS / "+("ICE CITY" if game.regions.in_ice else "BLUE GATE"),12,mint)
	text_at(Vector2(44,80),car_name,23)
	text_at(Vector2(44,108),("NIGHT DRIVE" if game.night else "DAY DRIVE")+"   /   v0.11",12,dim)
	draw_style_box(panel(),Rect2(w-220,24,196,72))
	text_at(Vector2(w-201,48),"YOUR GARAGE FUND",11,dim)
	text_at(Vector2(w-201,80),"%s  C" % game.progress.coins,26,Color("ffda86"))
	# Speed, tachometer arc and gear share one instrument cluster.
	var center := Vector2(w-154,h-101)
	draw_style_box(panel(),Rect2(w-292,h-200,268,176))
	draw_arc(center,64,deg_to_rad(-210),deg_to_rad(30),48,Color("30404e"),5,true)
	var rpm_ratio := clampf(car.rpm/maxf(1,float(car.tune.engine.rpm)),0,1)
	draw_arc(center,64,deg_to_rad(-210),deg_to_rad(-210+240*rpm_ratio),48,mint if rpm_ratio < 0.85 else Color("ff7d69"),5,true)
	text_at(center+Vector2(-41,9),"%03d" % int(car.speed_kmh/1.609344 if car.model_index >= 3 else car.speed_kmh),43)
	text_at(center+Vector2(-19,30),"MPH" if car.model_index >= 3 else "KM/H",12,dim)
	text_at(Vector2(w-273,h-170),"FLIGHT" if car.flight_active else "BURNOUT" if car.burnout_active else "ROAD",11,mint)
	text_at(Vector2(w-273,h-44),"D%d" % car.gear,18)
	text_at(Vector2(w-208,h-44),"%04d RPM" % int(car.rpm),13,dim)
	# Compact north-up radar is separated from the top HUD.
	var map_rect := Rect2(24,h-286,196,208)
	draw_style_box(panel(),map_rect)
	text_at(map_rect.position+Vector2(16,25),"ICE RADAR   N ^" if game.regions.in_ice else "CITY RADAR   N ^",11,mint)
	var origin := map_rect.position+Vector2(98,110)
	var icy: bool=game.regions.in_ice
	var map_scale: Vector2 = Vector2(77./430,77./780) if icy else preload("res://scripts/world_layout.gd").MAP_FIT
	var roads: Array=preload("res://scripts/ice_city.gd").ROADS if icy else preload("res://scripts/world_layout.gd").ROADS
	var extent: float=324 if icy else 602
	for r in roads:
		draw_line(origin+Vector2(r,-extent)*map_scale,origin+Vector2(r,extent)*map_scale,Color("405463"),1)
		draw_line(origin+Vector2(-extent,r)*map_scale,origin+Vector2(extent,r)*map_scale,Color("405463"),1)
	var runway: float=720 if icy else 1674
	draw_line(origin+Vector2(0,-runway)*map_scale,origin+Vector2(0,runway)*map_scale,Color("567e7a"),2)
	if not icy:draw_circle(origin+Vector2(checkpoint.x,checkpoint.z)*map_scale,4,mint)
	var destination: Vector3=game.regions.RETURN_GATE if icy else game.regions.ROOF_GATE
	draw_arc(origin+Vector2(destination.x,destination.z)*map_scale,5,0,TAU,16,Color("55cfff"),2)
	var player_pos := origin+Vector2(car.position.x,car.position.z)*map_scale
	var forward := Vector2(-sin(car.rotation.y),-cos(car.rotation.y))
	draw_colored_polygon(PackedVector2Array([player_pos+forward*6,player_pos-forward*4+forward.orthogonal()*3,player_pos-forward*4-forward.orthogonal()*3]),Color("ffb077"))
	text_at(map_rect.position+Vector2(16,193),"BLUE GATE / RETURN" if icy else "%d m / CHECKPOINT %d" % [int(car.position.distance_to(checkpoint)),collected],11,dim)
	var health := clampf(1-car.damage/100,0,1)
	draw_rect(Rect2(242,h-44,148,4),Color("30404e"))
	draw_rect(Rect2(242,h-44,148*health,4),mint if health > 0.5 else Color("ff826b"))
	text_at(Vector2(242,h-53),"BODY %d%%   /   R REPAIR" % int(100-car.damage),11,dim)
	text_at(Vector2(420,h-40),"M UNLOCK MOUSE" if game.mouse_captured else "M LOCK MOUSE",11,dim)
	if car.model_index == 4: text_at(Vector2(420,h-63),"F FLIGHT   /   SPACE UP   CTRL DOWN" if car.flight_active else "F ENABLE FLIGHT",11,mint)
	elif car.burnout_active: text_at(Vector2(420,h-63),"BURNOUT  /  RELEASE SPACE TO LAUNCH",12,mint)
	elif car.tune.get("thrusters",false): text_at(Vector2(420,h-63),"GAS THRUSTERS / W TO FIRE",12,mint)
	elif car.speed_kmh < 8: text_at(Vector2(420,h-63),"W + SPACE  /  BURNOUT",11,dim)
	if not game.progress.last_save_ok: text_at(Vector2(420,h-86),"Progress could not be saved",13,Color("ff826b"))
	draw_portal_hint()

func draw_walking_message() -> void:
	var text: String="E  /  LEAVE CAR & EXPLORE"
	if game.walker!=null and game.walker.active:text="WASD WALK / SHIFT RUN / SPACE JUMP / E DRIVE / R RETURN"
	if game.walker!=null and game.walker.message_time>0:text=game.walker.message
	draw_style_box(panel(),Rect2(size.x*.5-270,size.y-124,540,28))
	text_at(Vector2(size.x*.5-250,size.y-105),text,12,Color("d4ece7"))

func draw_portal_hint() -> void:
	if game.regions==null:return
	var ice: bool=game.regions.in_ice
	var destination: Vector3=game.regions.RETURN_GATE if ice else game.regions.ROOF_GATE
	var actor: Node3D=game.walker if game.walker!=null and game.walker.active else car
	var metres: int=int(actor.global_position.distance_to(destination))
	var x: float=size.x*.5-210
	draw_style_box(panel(Color(.02,.06,.1,.88)),Rect2(x-12,80,422,54))
	text_at(Vector2(x,105),"RETURN BLUE GATE / %d m" % metres if ice else "ICE CITY / BLUE ROOF GATE / %d m" % metres,13,Color("8bdcff"))
	text_at(Vector2(x,124),"Drive or fly through the gate to return" if ice else "Roadster + F / northwest tower / 68 m high",11,Color("a5bdcf"))
	if game.regions.transition_time>0:
		draw_style_box(panel(Color(.02,.07,.13,.9)),Rect2(size.x*.5-190,150,380,55))
		text_at(Vector2(size.x*.5-160,185),"WELCOME TO ICE CITY" if ice else "BACK IN THE CITY",22,Color("bcefff"))

func nav_button(parent: Control, caption: String, pos: Vector2, dimensions: Vector2, callback: Callable, pause_style: bool = false, indent: float = 0) -> Button:
	var node := Button.new()
	node.text = caption
	node.position = pos
	node.size = dimensions
	node.focus_mode = Control.FOCUS_ALL
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT if pause_style else HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_size_override("font_size",32 if pause_style else 17)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0,0,0,0)
	normal.content_margin_left = indent
	var selected := normal.duplicate() as StyleBoxFlat
	selected.bg_color = Color(0.01,0.12,0.39,0.82) if pause_style else Color(0.15,0.19,0.23,0.25)
	if not pause_style:
		selected.set_border_width_all(1)
		selected.border_color = Color("d5e0e7")
	node.add_theme_stylebox_override("normal",normal)
	node.add_theme_stylebox_override("hover",selected)
	node.add_theme_stylebox_override("focus",selected)
	node.add_theme_stylebox_override("pressed",selected)
	node.add_theme_color_override("font_focus_color",Color("67e8ff") if pause_style else Color.WHITE)
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func build_navigation() -> void:
	pause_nav = preload("res://scripts/pause_backdrop.gd").new()
	pause_nav.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(pause_nav)
	var captions := ["Resume","Options","Reset","Load","Main Menu","Quit Game"]
	var callbacks := [game.set_paused.bind(false),open_options,reset_and_resume,game.load_saved_game,game.show_title,game.quit_game]
	for i in captions.size():
		pause_buttons.append(nav_button(pause_nav,captions[i],Vector2(0,135+i*70),Vector2(1280,60),callbacks[i],true,150+maxi(i-1,0)*32))
	main_panel = Control.new()
	main_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main_panel)
	var heading := label(main_panel,"OPEN\nSTREETS",58)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.position = Vector2(410,48)
	heading.size = Vector2(460,150)
	var names := ["CONTINUE","NEW GAME","LOAD GAME","OPTIONS","CREDITS","QUIT GAME"]
	var commands := [game.start_session,request_new_game,game.load_saved_game,open_options,show_credits,game.quit_game]
	for i in names.size():
		main_buttons.append(nav_button(main_panel,names[i],Vector2(460,240+i*50),Vector2(360,42),commands[i]))
	continue_button = main_buttons[0]
	load_button = main_buttons[2]
	var footer := label(main_panel,"A city. A highway. No limits.\nSelect a menu item to begin.",16)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.position = Vector2(380,615)
	footer.size = Vector2(520,60)
	label(main_panel,"v0.11 STREET EXPLORER",13).position = Vector2(1080,680)
	credits_panel = framed(Vector2(310,180),Vector2(660,340))
	var credits := column(padded(credits_panel))
	label(credits,"OPEN STREETS",32)
	label(credits,"An original arcade driving sandbox.\nProcedural art, synthesized sound and local saves.\nGodot 4.6.1 / MIT-licensed project.\nFictional cars inspired by modern hypercars and EVs.\nSee LICENSE and README for details.",18)
	button(credits,"BACK",close_credits)
	credits_panel.visible = false
	new_game_dialog = ConfirmationDialog.new()
	new_game_dialog.title = "Start a new game?"
	new_game_dialog.dialog_text = "Reset coins, owned cars and upgrades?\nAudio and crash settings will stay the same."
	new_game_dialog.confirmed.connect(game.new_game)
	add_child(new_game_dialog)

func request_new_game() -> void:
	if game.progress.has_save or game.session_started: new_game_dialog.popup_centered(Vector2i(540,180))
	else: game.new_game()

func show_credits() -> void:
	credits_panel.visible = true
	refresh_menus()

func close_credits() -> void:
	credits_panel.visible = false
	refresh_menus()
