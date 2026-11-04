class_name CashRegister
extends Node3D

## Tezgâhtaki yazar kasa: dijital ekran, açılan para çekmecesi, yanında kart
## okutulan POS cihazı, bahşiş geldikçe dolan kavanoz ve paket servis telefonu
## (kurye varken paket siparişi gelince çalar; dokununca sipariş açılır).

signal phone_tapped

const DRAWER_OPEN_Z := 0.3
const NOTE_COLORS := [Color("#9b6fc0"), Color("#3f8fd0"), Color("#e0873a"), Color("#3fa866"), Color("#d9566a")]
const MAX_JAR_COINS := 40
## Kasa modelinin dokunmatik ekranı (kasaya göre): ortası, yarı genişlik/yükseklik
## yönleri ve dışa bakan yüzey normali. Blender'da modelden ölçüldü; ekran 4:3 ve
## geriye ~35° eğik. Kasa ekranı arayüzü bu dikdörtgenin üstüne oturur.
const SCREEN_CENTER := Vector3(0.009, 0.317, -0.076)
const SCREEN_RIGHT := Vector3(0.166, 0, 0)
const SCREEN_UP := Vector3(0, 0.102, -0.072)
const SCREEN_NORMAL := Vector3(0, 0.575, 0.818)

var _drawer: Node3D
var _display: Label3D
var _pos_label: Label3D
var _pos_led: MeshInstance3D
var _jar_coins: Node3D
var _jar_count := 0
var _jar_label: Label3D
var _drawer_tween: Tween
var _phone: Node3D
var _phone_screen: StandardMaterial3D
var _phone_holder: Node3D
var _ringing := false
var _ring_t := 0.0


func _ready() -> void:
	_build_register()
	_build_pos()
	_build_jar()
	_build_phone()
	show_idle()
	# Kavanoz günün bahşişini gösterir: yeniden açılınca o kadar dolu, yeni günde boş.
	_fill_jar(false)
	GameState.day_started.connect(func(_day: int) -> void: _clear_jar())


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


## Bahşiş gelince kavanoza paralar düşer (teslimde, müşteri 5 yıldız verince).
## Kavanozdaki para miktarı günün toplam bahşişine göredir: her ₺2 bir para.
func add_tip(_amount: int) -> void:
	_fill_jar(true)


func _fill_jar(animate: bool) -> void:
	var tips: int = GameState.day_stats["tips"]
	var target_count := clampi(ceili(tips / 2.0), 0, MAX_JAR_COINS)
	var i := 0
	while _jar_count < target_count:
		_drop_coin(i if animate else -1)
		i += 1
	_jar_label.text = "₺%d" % tips if tips > 0 else ""


## Bir bozuk para (her beşincisi kâğıt para) kavanozun dibinden yukarı doğru dizilir.
## delay_index -1 ise animasyonsuz yerine konur.
func _drop_coin(delay_index: int) -> void:
	var note := _jar_count % 5 == 4
	var coin := Util.box(Vector3(0.07, 0.006, 0.04), Color("#7fc77a")) if note else Util.cylinder(0.03, 0.012, Color("#f6c945"))
	var layer := _jar_count / 5
	var angle := _jar_count * 2.4
	var target := Vector3(cos(angle) * 0.035, 0.015 + layer * 0.022, sin(angle) * 0.035)
	coin.rotation_degrees = Vector3(randf_range(-25, 25), randf_range(0, 180), randf_range(-25, 25))
	_jar_coins.add_child(coin)
	_jar_count += 1
	if delay_index < 0:
		coin.position = target
		return
	coin.position = target + Vector3(0, 0.4, 0)
	var tween := coin.create_tween()
	tween.tween_interval(delay_index * 0.09)
	tween.tween_property(coin, "position", target, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(Sfx.play.bind("coin", 0.05))


func _clear_jar() -> void:
	for coin in _jar_coins.get_children():
		coin.queue_free()
	_jar_count = 0
	_jar_label.text = ""


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
	# Gövde (Meshy modeli); çekmece kapalıyken modelin içinde saklı durur.
	add_child(Util.model("equipment/kasa"))

	_drawer = Node3D.new()
	_drawer.scale = Vector3(0.9, 0.9, 0.9)
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

	# Arkada direğe takılı dijital tutar ekranı
	add_child(Util.box(Vector3(0.04, 0.5, 0.04), dark, Vector3(0, 0.25, -0.24)))
	var screen := Node3D.new()
	screen.position = Vector3(0, 0.56, -0.24)
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
	pos.add_child(Util.model("equipment/pos", Vector3.ZERO, 0.0, 0.8))
	# Ekranın üstünde durum yazısı ve ışığı
	_pos_label = Util.label3d("", 48, Color("#7dffa8"), Vector3(0, 0.29, 0.02))
	_pos_label.pixel_size = 0.0009
	_pos_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_pos_label.outline_size = 10
	_pos_label.outline_modulate = Color("#10161c")
	pos.add_child(_pos_label)
	_pos_led = Util.sphere(0.01, Color("#9aa4ae"), Vector3(0.045, 0.235, 0.03))
	pos.add_child(_pos_led)


## Telefon çalıyor mu: titrer, ekranı yanıp söner, üstünde "PAKET!" baloncuğu çıkar.
func is_ringing() -> bool:
	return _ringing


## Telefonun üstü (Hud "PAKET!" rozetini buraya koyar).
func phone_top() -> Vector3:
	return _phone_holder.global_position + Vector3(0, 0.3, 0)


func set_ringing(on: bool) -> void:
	if on == _ringing:
		return
	_ringing = on
	_ring_t = 0.0
	if not on:
		_phone.rotation = Vector3(deg_to_rad(-22.0), 0, 0)
		_phone_screen.emission = Color("#1d3550")


func _process(delta: float) -> void:
	if not _ringing:
		return
	# İki kısa çınlama, sonra kısa sessizlik; çınlarken titrer. Mutfaktayken de duyulur.
	if fmod(_ring_t, 2.0) + delta >= 2.0 or _ring_t == 0.0:
		Sfx.play("phone_ring")
	_ring_t += delta
	var phase := fmod(_ring_t, 2.0)
	var buzzing := phase < 0.9
	_phone.rotation = Vector3(deg_to_rad(-22.0), 0, deg_to_rad(5.0 * sin(_ring_t * 55.0)) if buzzing else 0.0)
	_phone_screen.emission = Color("#3fdc7a") if int(_ring_t * 4.0) % 2 == 0 else Color("#1d6b40")


func _build_phone() -> void:
	var holder := Node3D.new()
	holder.position = Vector3(0.22, 0, 0.27)
	add_child(holder)
	_phone_holder = holder
	# Masa altlığı
	holder.add_child(Util.box(Vector3(0.11, 0.025, 0.09), Color("#2c3038"), Vector3(0, 0.0125, 0)))
	_phone = Node3D.new()
	_phone.position = Vector3(0, 0.025, 0)
	_phone.rotation = Vector3(deg_to_rad(-22.0), 0, 0)
	holder.add_child(_phone)
	_phone.add_child(Util.box(Vector3(0.085, 0.165, 0.014), Color("#1b1e24"), Vector3(0, 0.0825, 0)))
	_phone_screen = StandardMaterial3D.new()
	_phone_screen.albedo_color = Color("#10161f")
	_phone_screen.emission_enabled = true
	_phone_screen.emission = Color("#1d3550")
	_phone_screen.emission_energy_multiplier = 1.4
	var screen := Util.box(Vector3(0.074, 0.145, 0.002), _phone_screen, Vector3(0, 0.0835, 0.0075))
	_phone.add_child(screen)
	var body := Util.collider_box(holder, Vector3(0.22, 0.3, 0.2), Vector3(0, 0.12, 0))
	body.set_meta("tap", func() -> void: phone_tapped.emit())


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
	# Kavanozun üstünde günün bahşişi
	_jar_label = Util.label3d("", 56, Color("#f2b33c"), Vector3(0, 0.3, 0))
	_jar_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_jar_label.outline_size = 14
	_jar_label.outline_modulate = Color("#5a3a10")
	_jar_label.pixel_size = 0.0016
	jar.add_child(_jar_label)
