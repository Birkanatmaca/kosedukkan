class_name CashRegister
extends Node3D

## Tezgâhtaki yazar kasa: dijital ekran, açılan para çekmecesi, yanında kart
## okutulan POS cihazı ve bahşiş geldikçe dolan kavanoz.

const DRAWER_OPEN_Z := 0.3
const NOTE_COLORS := [Color("#9b6fc0"), Color("#3f8fd0"), Color("#e0873a"), Color("#3fa866"), Color("#d9566a")]
const MAX_JAR_COINS := 40

var _drawer: Node3D
var _display: Label3D
var _pos_screen: MeshInstance3D
var _pos_label: Label3D
var _pos_led: MeshInstance3D
var _jar_coins: Node3D
var _jar_count := 0
var _drawer_tween: Tween


func _ready() -> void:
	_build_register()
	_build_pos()
	_build_jar()
	show_idle()


## Ödeme başlarken tutarı gösterir.
func show_amount(amount: int) -> void:
	_set_display("₺%d" % amount)


func show_idle() -> void:
	_set_display("HOŞ GELDİNİZ")
	_set_pos("HAZIR", Color("#9aa4ae"))


func show_thanks() -> void:
	_set_display("TEŞEKKÜRLER")
	get_tree().create_timer(2.0).timeout.connect(show_idle)


## Uzun yazılar ekrana sığsın diye küçülür.
func _set_display(text: String) -> void:
	_display.text = text
	_display.font_size = 64 if text.length() <= 6 else 30


func open_drawer() -> void:
	_move_drawer(DRAWER_OPEN_Z)


func close_drawer() -> void:
	_move_drawer(0.0)


func card_wait() -> void:
	_set_pos("KART", Color("#f0c040"))


func card_ok() -> void:
	_set_pos("ONAY", Color("#3fbf6f"))


## Bahşiş kavanozuna para düşer.
func add_tip(amount: int) -> void:
	for i in clampi(amount / 2, 1, 4):
		if _jar_count >= MAX_JAR_COINS:
			return
		var coin := Util.cylinder(0.035, 0.012, Color("#f6c945"))
		var layer := _jar_count / 6
		var angle := _jar_count * 2.4
		var target := Vector3(cos(angle) * 0.05, 0.02 + layer * 0.014, sin(angle) * 0.05)
		coin.position = target + Vector3(0, 0.35, 0)
		coin.rotation_degrees = Vector3(randf_range(-20, 20), 0, randf_range(-20, 20))
		_jar_coins.add_child(coin)
		coin.create_tween().tween_property(coin, "position", target, 0.35 + i * 0.08) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		_jar_count += 1


func _move_drawer(z: float) -> void:
	if _drawer_tween:
		_drawer_tween.kill()
	_drawer_tween = _drawer.create_tween()
	_drawer_tween.tween_property(_drawer, "position:z", z, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_pos(text: String, color: Color) -> void:
	_pos_label.text = text
	_pos_led.material_override = Util.material(color)


func _build_register() -> void:
	var body := Color("#3a3f47")
	var dark := Color("#262a30")
	# Gövde ve çekmece yuvası
	add_child(Util.box(Vector3(0.5, 0.13, 0.44), body, Vector3(0, 0.065, 0)))

	_drawer = Node3D.new()
	add_child(_drawer)
	_drawer.add_child(Util.box(Vector3(0.46, 0.1, 0.4), dark, Vector3(0, 0.06, 0.02)))
	_drawer.add_child(Util.box(Vector3(0.48, 0.1, 0.02), body, Vector3(0, 0.06, 0.225)))
	_drawer.add_child(Util.box(Vector3(0.12, 0.02, 0.02), Color("#c9d1d9"), Vector3(0, 0.06, 0.24)))
	# Çekmece içi: banknot bölmeleri ve bozuk para kapları
	for i in NOTE_COLORS.size():
		var x := -0.18 + i * 0.075
		_drawer.add_child(Util.box(Vector3(0.065, 0.03, 0.2), NOTE_COLORS[i], Vector3(x, 0.115, -0.04)))
		_drawer.add_child(Util.box(Vector3(0.004, 0.04, 0.2), Color("#15171a"), Vector3(x + 0.037, 0.115, -0.04)))
	for i in 4:
		var cx := -0.15 + i * 0.1
		_drawer.add_child(Util.cylinder(0.035, 0.02, Color("#d9b648"), Vector3(cx, 0.11, 0.13)))
		_drawer.add_child(Util.cylinder(0.03, 0.022, Color("#f6c945"), Vector3(cx, 0.115, 0.13)))

	# Üst kısım: eğik tuş takımı
	var keypad := Node3D.new()
	keypad.position = Vector3(0, 0.17, 0.02)
	keypad.rotation_degrees.x = 18
	add_child(keypad)
	keypad.add_child(Util.box(Vector3(0.46, 0.08, 0.34), body))
	for row in 3:
		for col in 5:
			var key_color := Color("#e8553e") if col == 4 else Color("#d9dde0")
			keypad.add_child(Util.box(Vector3(0.06, 0.02, 0.06), key_color, Vector3(-0.16 + col * 0.08, 0.05, -0.08 + row * 0.08)))

	# Müşteriye ve kasiyere bakan dijital ekran
	add_child(Util.box(Vector3(0.04, 0.16, 0.04), dark, Vector3(0, 0.3, -0.12)))
	var screen := Node3D.new()
	screen.position = Vector3(0, 0.4, -0.12)
	screen.rotation_degrees.x = -12
	add_child(screen)
	screen.add_child(Util.box(Vector3(0.36, 0.13, 0.04), dark))
	screen.add_child(Util.box(Vector3(0.32, 0.09, 0.01), Color("#0f2a1c"), Vector3(0, 0, 0.021)))
	_display = Util.label3d("", 70, Color("#7dffa8"), Vector3(0, 0, 0.03))
	_display.pixel_size = 0.0012
	_display.font_size = 64
	screen.add_child(_display)


func _build_pos() -> void:
	var pos := Node3D.new()
	pos.position = Vector3(-0.42, 0, 0.05)
	pos.rotation_degrees.y = 15
	add_child(pos)
	pos.add_child(Util.box(Vector3(0.16, 0.06, 0.28), Color("#1d2025"), Vector3(0, 0.03, 0)))
	var top := Node3D.new()
	top.position = Vector3(0, 0.07, 0)
	top.rotation_degrees.x = 20
	pos.add_child(top)
	top.add_child(Util.box(Vector3(0.15, 0.03, 0.26), Color("#2b2f36")))
	_pos_screen = Util.box(Vector3(0.12, 0.005, 0.08), Color("#a8dcb8"), Vector3(0, 0.017, -0.07))
	top.add_child(_pos_screen)
	_pos_label = Util.label3d("", 48, Color("#1d4d2e"), Vector3(0, 0.022, -0.07))
	_pos_label.pixel_size = 0.0012
	_pos_label.rotation_degrees.x = -90
	top.add_child(_pos_label)
	for row in 3:
		for col in 3:
			top.add_child(Util.box(Vector3(0.03, 0.01, 0.025), Color("#5d6873"), Vector3(-0.035 + col * 0.035, 0.018, 0.02 + row * 0.035)))
	_pos_led = Util.sphere(0.012, Color("#9aa4ae"), Vector3(0.05, 0.02, -0.12))
	top.add_child(_pos_led)


func _build_jar() -> void:
	var jar := Node3D.new()
	jar.position = Vector3(0.42, 0, 0.08)
	add_child(jar)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.85, 0.95, 1.0, 0.28)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.1
	jar.add_child(Util.cylinder(0.075, 0.2, glass, Vector3(0, 0.1, 0)))
	jar.add_child(Util.cylinder(0.08, 0.02, Color("#c9d1d9"), Vector3(0, 0.2, 0)))
	_jar_coins = Node3D.new()
	jar.add_child(_jar_coins)
	var tag := Util.label3d("BAHŞİŞ", 40, Color("#e8553e"), Vector3(0, 0.08, 0.077))
	tag.pixel_size = 0.0015
	jar.add_child(tag)
