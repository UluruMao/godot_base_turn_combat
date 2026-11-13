extends Node2D

const ART = {
	"Goblin": preload("res://assets/goblin.png"),
	"Troll": preload("res://assets/troll.png"),
	"Orc": preload("res://assets/orc.png")
}
const HEIGHT = {"Goblin": 132.0, "Troll": 214.0, "Orc": 170.0}
var unit: Dictionary
var body: Node2D
var sprite: Sprite2D
var hp: int
var height: float
var direction: float = 1.0
var age: float = 0.0
var dead: bool = false
var lead: bool = false
var tint: Color

func setup(data: Dictionary, front: bool) -> void:
	unit = data.duplicate()
	hp = unit.hp
	height = HEIGHT[unit.type]
	direction = 1.0 if unit.side == 0 else -1.0
	tint = Color("e6b96b") if unit.side == 0 else Color("83c9ce")
	lead = front
	body = Node2D.new()
	add_child(body)
	sprite = Sprite2D.new()
	sprite.texture = ART[unit.type]
	sprite.flip_h = direction < 0
	sprite.scale = Vector2.ONE * height / sprite.texture.get_height()
	sprite.position = Vector2(0, -height * 0.5)
	body.add_child(sprite)
	age = float(unit.id) * 1.3

func _process(delta: float) -> void:
	age += delta
	if not dead and is_instance_valid(sprite):
		sprite.position.y = -height * 0.5 + sin(age * 2.5) * 2.0
		body.scale.y = 1.0 + sin(age * 2.5) * 0.009
	queue_redraw()

func _draw() -> void:
	if dead:
		return
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.25))
	draw_circle(Vector2.ZERO, 43 if lead else 34, Color(0.02, 0.04, 0.04, 0.35))
	draw_arc(Vector2.ZERO, 46 if lead else 36, 0, TAU, 48, Color(tint, 0.75 if lead else 0.25), 2, true)
	draw_set_transform(Vector2.ZERO)
	var bar_width: float = 90 if lead else 72
	var y: float = -height - 28
	draw_style_box(_box(Color("172321"), 4), Rect2(-bar_width / 2 - 2, y - 2, bar_width + 4, 11))
	draw_style_box(_box(tint, 3), Rect2(-bar_width / 2, y, bar_width * float(hp) / unit.max_hp, 7))
	var text: String = "%s  %d/%d" % [unit.type, hp, unit.max_hp]
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(-font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x / 2, y - 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f1eadc"))
	if lead:
		draw_string(font, Vector2(-20, 28), "LEAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, tint)

func _box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	return box

func set_hp(value: int) -> void:
	hp = clampi(value, 0, unit.max_hp)
	queue_redraw()

func attack(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(body, "position", Vector2(-direction * 12, 4), duration * 0.2)
	tween.tween_property(body, "position", Vector2(direction * 58, -8), duration * 0.2).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(body, "rotation", direction * 0.12, duration * 0.2)
	tween.tween_property(body, "position", Vector2.ZERO, duration * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(body, "rotation", 0.0, duration * 0.6)

func hit(duration: float, shielded: bool = false) -> void:
	var tween := create_tween()
	body.modulate = Color(1.6, 1.6, 1.8) if shielded else Color(1.8, 0.7, 0.6)
	tween.tween_property(body, "position:x", -direction * 12, duration * 0.25)
	tween.tween_property(body, "position:x", 0.0, duration * 0.75)
	tween.parallel().tween_property(body, "modulate", Color.WHITE, duration * 0.75)

func heal(duration: float) -> void:
	body.modulate = Color(0.65, 1.5, 0.75)
	create_tween().tween_property(body, "modulate", Color.WHITE, duration)

func die(duration: float) -> void:
	dead = true
	var tween := create_tween().set_parallel()
	tween.tween_property(body, "rotation", -direction * 1.35, duration * 0.7).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(body, "position", Vector2(-direction * 25, 24), duration)
	tween.tween_property(self, "modulate:a", 0.0, duration).set_delay(duration * 0.3)
	queue_redraw()
