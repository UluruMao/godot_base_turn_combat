extends Control

var clock: float = 0
var motes: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 84520
	for i in range(26):
		motes.append(Vector3(rng.randf_range(20, 1000), rng.randf_range(70, 315), rng.randf_range(0.2, 1.0)))

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(0, 0, w, h), Color("253839"))
	for i in range(12):
		draw_rect(Rect2(0, i * h / 12, w, h / 12 + 1), Color("253839").lerp(Color("718274"), float(i) / 15))
	draw_circle(Vector2(w * 0.55, 100), 54, Color("c3b68a"))
	draw_circle(Vector2(w * 0.55, 100), 66, Color(0.9, 0.8, 0.5, 0.035))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 240), Vector2(0, 187), Vector2(115, 90), Vector2(205, 177), Vector2(310, 97), Vector2(420, 205), Vector2(560, 123), Vector2(685, 195), Vector2(815, 73), Vector2(w, 210), Vector2(w, 300)]), Color("455b55"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 310), Vector2(0, 260), Vector2(180, 184), Vector2(330, 242), Vector2(470, 175), Vector2(670, 240), Vector2(860, 179), Vector2(w, 230), Vector2(w, 350)]), Color("354f47"))
	for x in [15, 78, 140, 220, 320, 720, 815, 910, 980, 1020]:
		var y: float = 278 + sin(float(x)) * 12
		draw_rect(Rect2(x - 3, y - 60, 6, 95), Color("2c423b"))
		for j in range(3):
			var t: float = y - 105 + j * 22
			var extent: float = 20 + j * 8
			draw_colored_polygon(PackedVector2Array([Vector2(x, t), Vector2(x - extent, t + 48), Vector2(x + extent, t + 48)]), Color("2c423b"))
	draw_rect(Rect2(0, 329, w, h - 329), Color("484a35"))
	draw_rect(Rect2(0, 330, w, 4), Color("9a9567"))
	draw_rect(Rect2(0, 347, w, h - 347), Color("3a3c2e"))
	for i in range(45):
		var x: float = fmod(i * 73.7, w)
		var y: float = 355 + fmod(i * 13.1, 60)
		draw_line(Vector2(x, y), Vector2(x + 13, y + 1), Color("555340"), 1, true)
	# Ruined watchtowers frame the lane, rather than affecting combat.
	for x in [30, w - 65]:
		draw_rect(Rect2(x, 240, 35, 90), Color("283b36"))
		draw_rect(Rect2(x - 4, 230, 43, 16), Color("283b36"))
		for j in range(3):
			draw_rect(Rect2(x - 4 + j * 16, 218, 11, 20), Color("283b36"))
		draw_rect(Rect2(x + 13, 259, 8, 18), Color("b99b5b"))
	for mote in motes:
		var point := Vector2(mote.x + sin(clock * mote.z + mote.x) * 9, mote.y + cos(clock * 0.6 + mote.x) * 5)
		draw_circle(point, 1.4, Color(0.9, 0.85, 0.5, 0.25 + sin(clock + mote.x) * 0.2))
	draw_line(Vector2(w / 2, 337), Vector2(w / 2, 399), Color(0.8, 0.75, 0.55, 0.18), 1)
	draw_string(ThemeDB.fallback_font, Vector2(w / 2 - 29, 426), "THE FRONT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("b3b59b"))
