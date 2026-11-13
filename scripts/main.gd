extends Control

const Model = preload("res://scripts/combat.gd")
const Fighter = preload("res://scripts/fighter.gd")
const Arena = preload("res://scripts/arena.gd")
const GOLD = Color("e6b96b")
const TEAL = Color("83c9ce")
const INK = Color("121c1d")
const PAPER = Color("eee8d8")
const MUTED = Color("9daaa1")

var model = Model.new()
var arena: Control
var fighters: Dictionary = {}
var lineups: Array = [["Goblin", "Troll", "Orc"], ["Orc", "Goblin", "Troll"]]
var pickers: Array = [[], []]
var scenario: OptionButton
var play_button: Button
var step_button: Button
var phase: Label
var turn_label: Label
var journal: RichTextLabel
var result_panel: Panel
var result_title: Label
var result_subtitle: Label
var speed: float = 1.0
var autoplay: bool = false
var busy: bool = false
var generation: int = 0
var sound_enabled: bool = false

func _ready() -> void:
	_build_theme()
	_build_interface()
	_sync_pickers()
	_prepare()

func _build_theme() -> void:
	var theme_res := Theme.new()
	theme_res.default_font_size = 15
	for type in ["Button", "OptionButton"]:
		theme_res.set_color("font_color", type, PAPER)
		theme_res.set_color("font_hover_color", type, Color.WHITE)
		theme_res.set_color("font_disabled_color", type, Color("65746e"))
		theme_res.set_stylebox("normal", type, _style(Color("2b3733"), Color("475249")))
		theme_res.set_stylebox("hover", type, _style(Color("3b4840"), GOLD))
		theme_res.set_stylebox("pressed", type, _style(Color("4c503a"), GOLD))
		theme_res.set_stylebox("disabled", type, _style(Color("202b28"), Color("344039")))
		theme_res.set_stylebox("focus", type, _style(Color(0, 0, 0, 0), GOLD))
	theme = theme_res

func _style(color: Color, border: Color = Color("3b4941"), radius: int = 6) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 12
	box.content_margin_right = 12
	return box

func _place(node: Control, rect: Rect2, parent: Node = self) -> void:
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size

func _label(text: String, rect: Rect2, font_size: int = 16, color: Color = PAPER, parent: Node = self) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_place(label, rect, parent)
	return label

func _button(text: String, rect: Rect2, callback: Callable, parent: Node = self) -> Button:
	var button := Button.new()
	button.text = text
	_place(button, rect, parent)
	button.pressed.connect(callback)
	return button

func _panel(rect: Rect2, color: Color = Color("1e2a27"), parent: Node = self) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _style(color))
	_place(panel, rect, parent)
	return panel

func _build_interface() -> void:
	# The stage is created before the HUD, so effects stay behind interface text.
	arena = Control.new()
	arena.set_script(Arena)
	arena.clip_contents = true
	_place(arena, Rect2(24, 176, 1036, 440))
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "DejaVu Serif"])
	var title := _label("MONSTERFRONT", Rect2(24, 18, 700, 65), 44)
	title.add_theme_font_override("font", serif)
	_label("A LITTLE WAR.  ONE TURN AT A TIME.", Rect2(27, 81, 680, 24), 12, GOLD)
	_label("VISUAL COMBAT  /  PROTOTYPE 01", Rect2(1080, 36, 340, 24), 12, MUTED)
	_label("Goblin > Troll > Orc > Goblin", Rect2(1080, 61, 340, 24), 14, PAPER)
	scenario = OptionButton.new()
	for item in Model.SCENARIOS:
		scenario.add_item(item.name)
	scenario.add_item("Custom formation")
	scenario.select(7)
	_place(scenario, Rect2(24, 122, 335, 38))
	scenario.item_selected.connect(_select_scenario)
	play_button = _button("Begin battle", Rect2(372, 122, 155, 38), _toggle_play)
	play_button.add_theme_stylebox_override("normal", _style(Color("b69250"), GOLD))
	play_button.add_theme_color_override("font_color", INK)
	step_button = _button("Next turn", Rect2(537, 122, 130, 38), _step_pressed)
	_button("Restart", Rect2(677, 122, 105, 38), _prepare)
	_button("Shuffle teams", Rect2(792, 122, 140, 38), _shuffle)
	var speed_picker := OptionButton.new()
	for text in ["1x speed", "2x speed", "4x speed"]:
		speed_picker.add_item(text)
	_place(speed_picker, Rect2(943, 122, 117, 38))
	speed_picker.item_selected.connect(func(index: int): speed = [1.0, 2.0, 4.0][index])
	var sound_button := _button("Sound: off", Rect2(1080, 122, 130, 38), func(): pass)
	sound_button.pressed.connect(func():
		sound_enabled = not sound_enabled
		sound_button.text = "Sound: on" if sound_enabled else "Sound: off")
	_button("Next battle", Rect2(1220, 122, 196, 38), _next_scenario)
	_label("ALPHA", Rect2(44, 191, 130, 26), 16, GOLD)
	var beta := _label("BETA", Rect2(927, 191, 110, 26), 16, TEAL)
	beta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	turn_label = _label("TURN 00", Rect2(458, 187, 170, 30), 18)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase = _label("Ready at the front", Rect2(370, 220, 345, 25), 13, Color("c6cfbc"))
	phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel(Rect2(1080, 176, 336, 440))
	_label("COMBAT JOURNAL", Rect2(1100, 193, 280, 26), 13, GOLD)
	_label("Every hit. Every comeback.", Rect2(1100, 222, 280, 24), 13, MUTED)
	journal = RichTextLabel.new()
	journal.bbcode_enabled = true
	journal.scroll_following = true
	journal.add_theme_font_size_override("normal_font_size", 14)
	journal.add_theme_color_override("default_color", PAPER)
	_place(journal, Rect2(1100, 260, 296, 330))
	_label("BUILD YOUR FORMATION", Rect2(24, 635, 400, 26), 15, GOLD)
	_label("Slot 1 leads. Edit a slot to start a new battle. Maximum four per side.", Rect2(24, 662, 1030, 24), 13, MUTED)
	for side in range(2):
		var origin: float = 24 if side == 0 else 555
		_label("ALPHA" if side == 0 else "BETA", Rect2(origin, 695, 70, 40), 12, GOLD if side == 0 else TEAL)
		for slot in range(4):
			var picker := OptionButton.new()
			picker.add_item("Empty")
			for type in Model.TYPES:
				picker.add_item(type)
			_place(picker, Rect2(origin + 70 + slot * 105, 695, 100, 38))
			picker.add_theme_font_size_override("font_size", 13)
			picker.item_selected.connect(_edit_formation)
			pickers[side].append(picker)
	_monster_card("Goblin", "THE SWIFT", "60 HP     20 ATK x 3", "Three quick strikes. Troll hunter.", Rect2(24, 754, 336, 118))
	_monster_card("Troll", "THE RELENTLESS", "100 HP     25 ATK", "+5 regeneration after both attacks.", Rect2(374, 754, 336, 118))
	_monster_card("Orc", "THE BULWARK", "75 HP     10 ATK", "Blocks 10. Reflects 10 on every hit.", Rect2(724, 754, 336, 118))
	_panel(Rect2(1080, 635, 336, 237))
	_label("THE RULES OF THE FRONT", Rect2(1100, 651, 280, 26), 13, GOLD)
	var help := _label("01   Only the two leads act.\n\n02   Both finish every attack.\n\n03   Regenerate, then check deaths.\n\n04   The next monster steps forward.", Rect2(1100, 690, 295, 155), 14, PAPER)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label("SPACE  Play / pause     N  Next turn     R  Restart", Rect2(24, 878, 1040, 20), 11, MUTED)
	result_panel = _panel(Rect2(280, 270, 520, 116), Color("1d2b27"))
	result_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_title = _label("ALPHA VICTORY", Rect2(20, 12, 480, 45), 30, GOLD, result_panel)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_subtitle = _label("", Rect2(20, 64, 480, 30), 14, PAPER, result_panel)
	result_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_panel.hide()

func _monster_card(type: String, subtitle: String, stats: String, ability: String, rect: Rect2) -> void:
	var panel := _panel(rect)
	var image := TextureRect.new()
	image.texture = Fighter.ART[type]
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_place(image, Rect2(8, 5, 90, 105), panel)
	_label(subtitle, Rect2(110, 9, 210, 18), 10, GOLD, panel)
	_label(type, Rect2(110, 26, 210, 30), 21, PAPER, panel)
	_label(stats, Rect2(110, 59, 210, 22), 13, PAPER, panel)
	var caption := _label(ability, Rect2(110, 85, 215, 28), 11, MUTED, panel)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1440, 900), INK)
	draw_line(Vector2(24, 108), Vector2(1416, 108), Color("3c4940"), 1)

func _sync_pickers() -> void:
	for side in range(2):
		for slot in range(4):
			pickers[side][slot].select(Model.TYPES.find(lineups[side][slot]) + 1 if slot < lineups[side].size() else 0)

func _edit_formation(_index: int) -> void:
	lineups = [[], []]
	for side in range(2):
		for picker in pickers[side]:
			if picker.selected > 0:
				lineups[side].append(Model.TYPES[picker.selected - 1])
	scenario.select(7)
	_prepare()

func _select_scenario(index: int) -> void:
	if index < 6:
		lineups = [Model.SCENARIOS[index].a.duplicate(), Model.SCENARIOS[index].b.duplicate()]
	elif index == 6:
		lineups = [_random_team(), _random_team()]
	_sync_pickers()
	_prepare()

func _next_scenario() -> void:
	var next: int = (scenario.selected + 1) % 7
	scenario.select(next)
	_select_scenario(next)

func _random_team() -> Array:
	var team: Array = []
	for i in range(4):
		team.append(Model.TYPES.pick_random())
	return team

func _shuffle() -> void:
	scenario.select(6)
	_select_scenario(6)

func _prepare() -> void:
	generation += 1 # Invalidates animation continuations when changing a battle.
	autoplay = false
	busy = false
	for child in arena.get_children():
		arena.remove_child(child)
		child.queue_free()
	fighters.clear()
	model.setup(lineups[0], lineups[1])
	for side in range(2):
		for slot in range(model.teams[side].size()):
			var id: int = model.teams[side][slot]
			var fighter = Node2D.new()
			fighter.set_script(Fighter)
			arena.add_child(fighter)
			fighter.setup(model.units[id], slot == 0)
			fighter.position = _slot_position(side, slot)
			if slot > 0:
				fighter.scale = Vector2.ONE * 0.76
				fighter.modulate = Color(0.8, 0.85, 0.8)
			fighters[id] = fighter
	journal.clear()
	_log("[color=#e6b96b]The armies assemble.[/color]")
	for side in range(2):
		_log("%s: %s" % [_team(side), ", ".join(lineups[side]) if not lineups[side].is_empty() else "Empty"])
	_log("\nChoose Begin battle or Next turn.")
	turn_label.text = "TURN 00"
	phase.text = "Ready at the front" if not model.finished else "Add a monster to each team"
	result_panel.hide()
	_refresh_buttons()

func _slot_position(side: int, slot: int) -> Vector2:
	return Vector2(422 - slot * 106 if side == 0 else 614 + slot * 106, 335 + (4 if slot > 0 else 0))

func _team(side: int) -> String:
	return "Alpha" if side == 0 else "Beta"

func _unit_name(id: int) -> String:
	return "%s %s" % [_team(model.units[id].side), model.units[id].type]

func _log(text: String) -> void:
	journal.append_text(text + "\n\n")

func _refresh_buttons() -> void:
	play_button.text = "Pause after turn" if autoplay and busy else ("Pause" if autoplay else ("Begin battle" if model.turn == 0 else "Resume"))
	if model.finished and model.turn > 0:
		play_button.text = "Battle over"
	play_button.disabled = model.finished
	step_button.disabled = busy or model.finished or autoplay

func _toggle_play() -> void:
	if not model.finished:
		autoplay = not autoplay
		_refresh_buttons()

func _step_pressed() -> void:
	if not busy and not model.finished and not autoplay:
		_run_turn()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_toggle_play()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_N:
			_step_pressed()
		elif event.keycode == KEY_R:
			_prepare()

func _process(_delta: float) -> void:
	if autoplay and not busy and not model.finished:
		_run_turn()

func _run_turn() -> void:
	busy = true
	var ticket: int = generation
	var events: Array = model.step()
	_refresh_buttons()
	turn_label.text = "TURN %02d" % model.turn
	_log("[color=#e6b96b]— TURN %02d —[/color]" % model.turn)
	for event in events:
		var duration: float = 0.62 / speed
		if event.kind == "attack":
			phase.text = "%s attacks  ·  %d/%d" % [_unit_name(event.actor), event.hit, event.hits]
			var actor = fighters[event.actor]
			var target = fighters[event.target]
			actor.attack(duration)
			await get_tree().create_timer(duration * 0.4).timeout
			if ticket != generation:
				return
			target.hit(duration * 0.45, event.blocked > 0)
			actor.set_hp(event.actor_hp)
			target.set_hp(event.target_hp)
			var point: Vector2 = target.position + Vector2(0, -target.height * 0.55)
			_impact(point, GOLD if event.blocked == 0 else TEAL, event.blocked > 0)
			_float_text("-%d" % event.damage, point + Vector2(0, -45), PAPER)
			var text: String = "%s → %s\n%d damage" % [_unit_name(event.actor), model.units[event.target].type, event.raw]
			if event.blocked > 0:
				text += " · %d blocked · %d dealt" % [event.blocked, event.damage]
				_float_text("BLOCK %d" % event.blocked, point + Vector2(0, -80), TEAL, 14)
			if event.reflected > 0:
				text += " · %d reflected" % event.reflected
				var reflect_point: Vector2 = actor.position + Vector2(0, -actor.height * 0.6)
				_float_text("-%d REFLECT" % event.reflected, reflect_point + Vector2(0, -30), Color("e7a16c"), 17)
				_impact(reflect_point, Color("e7a16c"), false)
			_log(text)
			_sound(125 if model.units[event.actor].type == "Troll" else 280)
			await get_tree().create_timer(duration * 0.65).timeout
			if ticket != generation:
				return
		elif event.kind == "regen":
			phase.text = "Both attacks complete  ·  regeneration"
			var actor = fighters[event.actor]
			actor.heal(duration)
			actor.set_hp(event.hp)
			var point: Vector2 = actor.position + Vector2(0, -actor.height * 0.6)
			_float_text("+%d REGEN" % event.amount, point + Vector2(0, -20), Color("a1de91"), 20)
			_ring(point, 48, Color("a1de91"), duration)
			for i in range(5):
				_float_text("+", point + Vector2(randf_range(-45, 45), randf_range(-30, 35)), Color("a1de91"), 18)
			_log("[color=#a1de91]%s regenerates %d HP → %d/%d[/color]" % [_unit_name(event.actor), event.amount, event.hp, model.units[event.actor].max_hp])
			_sound(660)
			await get_tree().create_timer(duration).timeout
			if ticket != generation:
				return
		elif event.kind == "death":
			phase.text = "Turn resolved  ·  checking deaths"
			var actor = fighters[event.actor]
			actor.die(duration)
			_impact(actor.position + Vector2(0, -10), Color("b6a077"), false)
			_log("[color=#db9783]%s falls.[/color]" % _unit_name(event.actor))
			await get_tree().create_timer(duration * 1.35).timeout
			if ticket != generation:
				return
		elif event.kind == "end":
			autoplay = false
			phase.text = "Battle complete"
			result_title.text = "BOTH ARMIES FALL" if event.winner == -1 else "%s VICTORY" % _team(event.winner).to_upper()
			result_title.add_theme_color_override("font_color", GOLD if event.winner != 1 else TEAL)
			result_subtitle.text = "%d turns fought. Restart, edit teams, or choose the next battle." % model.turn
			result_panel.show()
			_log("[color=#e6b96b]%s[/color]" % result_title.text)
	for side in range(2):
		for slot in range(model.teams[side].size()):
			var id: int = model.teams[side][slot]
			var fighter = fighters[id]
			fighter.set_hp(model.units[id].hp)
			fighter.lead = slot == 0
			var tween := create_tween().set_parallel()
			tween.tween_property(fighter, "position", _slot_position(side, slot), 0.3 / speed)
			tween.tween_property(fighter, "scale", Vector2.ONE if slot == 0 else Vector2.ONE * 0.76, 0.3 / speed)
			tween.tween_property(fighter, "modulate", Color.WHITE if slot == 0 else Color(0.8, 0.85, 0.8), 0.3 / speed)
	if not model.finished:
		phase.text = "Turn complete  ·  next leads ready"
	await get_tree().create_timer(0.4 / speed).timeout
	if ticket != generation:
		return
	busy = false
	_refresh_buttons()

func _float_text(text: String, point: Vector2, color: Color, font_size: int = 24) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("16221d"))
	label.add_theme_constant_override("outline_size", 5)
	_place(label, Rect2(point - Vector2(100, 15), Vector2(200, 45)), arena)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 10
	var tween := create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 42, 0.9 / speed)
	tween.tween_property(label, "modulate:a", 0.0, 0.7 / speed).set_delay(0.2 / speed)
	tween.chain().tween_callback(label.queue_free)

func _ring(point: Vector2, radius: float, color: Color, duration: float) -> void:
	var line := Line2D.new()
	for i in range(33):
		line.add_point(Vector2.from_angle(TAU * float(i) / 32) * radius)
	line.default_color = color
	line.width = 3
	line.position = point
	arena.add_child(line)
	var tween := create_tween().set_parallel()
	tween.tween_property(line, "scale", Vector2.ONE * 1.5, duration)
	tween.tween_property(line, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(line.queue_free)

func _impact(point: Vector2, color: Color, shielded: bool) -> void:
	if shielded:
		_ring(point, 38, color, 0.4 / speed)
	for i in range(8):
		var ray := Line2D.new()
		var vector := Vector2.from_angle(TAU * float(i) / 8 + randf_range(-0.2, 0.2))
		ray.add_point(Vector2.ZERO)
		ray.add_point(vector * randf_range(8, 18))
		ray.width = 3
		ray.default_color = color
		ray.position = point + vector * 8
		ray.z_index = 4
		arena.add_child(ray)
		var tween := create_tween().set_parallel()
		tween.tween_property(ray, "position", point + vector * 58, 0.35 / speed)
		tween.tween_property(ray, "modulate:a", 0.0, 0.35 / speed)
		tween.chain().tween_callback(ray.queue_free)
	# A short diagonal slash gives attacks a directional silhouette.
	var slash := Line2D.new()
	slash.points = PackedVector2Array([point + Vector2(-28, 24), point + Vector2(0, -5), point + Vector2(24, -35)])
	slash.width = 4
	slash.default_color = Color("f7e5b7")
	arena.add_child(slash)
	var fade := create_tween()
	fade.tween_property(slash, "modulate:a", 0.0, 0.22 / speed)
	fade.tween_callback(slash.queue_free)

func _sound(frequency: float) -> void:
	if not sound_enabled:
		return
	var data := PackedByteArray()
	data.resize(4400)
	for i in range(2200):
		var time: float = float(i) / 22050
		var value: int = int(sin(TAU * frequency * time) * exp(-time * 40) * 7000)
		data.encode_s16(i * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
