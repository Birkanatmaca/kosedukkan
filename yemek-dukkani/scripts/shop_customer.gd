class_name ShopCustomer
extends Node3D

## Kapıdan gelip tezgâhta siparişini bekleyen, servis edilince tepsisini alıp
## masaya oturan ve sonra çıkan müşteri. Nereye yürüyeceğini Shop söyler.
## Yüzü ve başının üstündeki ikon ruh haline göre değişir.

signal sat_down(customer: ShopCustomer)
signal finished_eating(customer: ShopCustomer)
signal returned_tray(customer: ShopCustomer)

## QUEUED: kasa doluyken koridordaki sırada bekliyor.
## WAIT_TABLE: tepsisiyle boş masa bekliyor. RETURNING: masa bulamayıp tepsiyi geri getiriyor.
## ORDERED: siparişini verip ödedi, numarasıyla teslim alanında yemeğini bekliyor.
enum State { ARRIVING, WAITING, PAYING, TO_SEAT, EATING, LEAVING, QUEUED, WAIT_TABLE, RETURNING, ORDERED }

## Ruh hali rozetleri: [ikon, renk] (mutlu, normal, kızgın)
const MOOD_BADGES := [["smile", UiKit.GREEN], ["meh", UiKit.YELLOW], ["angry", UiKit.RED]]
const SPEED := 2.2
const EAT_TIME := 10.0
## Tepsisiyle ayakta en fazla bu kadar masa bekler.
const TABLE_WAIT_TIME := 25.0

var customer_name := ""
## Erkek ve kadın müşteriler kendi Meshy modelleriyle gelir; her biri farklı
## ten, saç ve kıyafet rengiyle boyanır. İsim de cinsiyete göre seçilir (Shop).
var male := false
## ürün -> adet
var order := {}
var state := State.ARRIVING
var patience := 60.0
var max_patience := 60.0
var table_wait := 0.0
var tap: Callable
## Servis edilen ürünler: [ürün, kalite] listesi
var served_items: Array[Array] = []
## Yemekten sonra bırakılacak yorum: [yıldız, metin]
var pending_review := []
## Kasada ödenecek tutar ve bahşiş
var sale_price := 0
var sale_tip := 0
## Sipariş numarası ve yemeğini bekleme sabrı (teslim alanında azalır)
var order_number := 0
var food_patience := 0.0
var max_food_patience := 1.0
## Kasadan ayrılırken sabrının ne kadarı kalmıştı (puana etki eder)
var counter_wait_ratio := 1.0
## Hangi kasanın sırasında: 0 oyuncunun kasası, 1 kasiyerin (Ek Kasa)
var lane := 0
## Siparişini paket alıp masaya oturmadan çıkacak mı
var takeaway := false
## { "pos": Vector3, "table": Dictionary }
var seat := {}
## Masadaki tepsi (yedikçe içindeki ürünler küçülür)
var food: Node3D
## Elde taşınan tepsi
var carrying: Node3D
## Kızıp ayrılan müşteri hep kızgın görünür.
var angry := false

## Kaldırımdan kapıya kadar yürüyeceği noktalar. İçeri girene kadar her yeni
## yolun önüne eklenir; sabrı da içeri girince azalmaya başlar.
var entry: Array = []

var _path: Array[Vector3] = []
var _rest_angle := 0.0
var _base_y := 0.0
var _eat_timer := 0.0
var _t := randf() * 10.0
var _body: PersonBody
var _icon: Sprite3D


func _ready() -> void:
	patience = max_patience
	var model := ModelBody.new()
	_body = model
	add_child(_body)
	model.build_model("erkek" if male else "kadin", CharacterSkin.random_look())

	_icon = Icons.sprite(null, _body.head_top)
	add_child(_icon)

	var collider := Util.collider_box(self, Vector3(0.7, 1.8, 0.6), Vector3(0, 0.9, 0))
	collider.set_meta("tap", func() -> void:
		if tap.is_valid():
			tap.call()
	)


func item_count() -> int:
	var n := 0
	for id in order:
		n += int(order[id])
	return n


func mood() -> int:
	return _body.mood


## Ruh hali rozeti (sipariş kartında da gösterilir).
func mood_icon() -> Texture2D:
	var badge: Array = MOOD_BADGES[_body.mood]
	return Icons.badge(badge[0], badge[1])


## Verilen noktalardan sırayla geçer, sonunda rest_angle yönüne döner.
func follow(path: Array, rest_angle: float) -> void:
	_path.clear()
	for p in entry:
		_path.append(p)
	for p in path:
		_path.append(p)
	_rest_angle = rest_angle


## Tezgâhtaki tepsiyi alıp iki eliyle önünde tutar.
func take(package: Node3D) -> void:
	carrying = package
	package.reparent(_body)
	package.rotation = Vector3.ZERO
	package.create_tween().tween_property(package, "position", _body.carry_offset, 0.3).set_trans(Tween.TRANS_SINE)


## Taşıdığını bırakır ve döndürür (yeni yerine Shop koyar).
func put_down() -> Node3D:
	var package := carrying
	carrying = null
	return package


func go_sit(path: Array, face_angle: float) -> void:
	state = State.TO_SEAT
	follow(path, face_angle)


func wait_for_table(path: Array, face_angle: float) -> void:
	state = State.WAIT_TABLE
	table_wait = TABLE_WAIT_TIME
	follow(path, face_angle)


func return_tray(path: Array) -> void:
	state = State.RETURNING
	angry = true
	follow(path, 0.0)


func leave(path: Array) -> void:
	_set_sitting(false)
	state = State.LEAVING
	follow(path, _rest_angle)


func _process(delta: float) -> void:
	_t += delta
	if not _path.is_empty():
		_walk(delta)
	elif state == State.EATING:
		_animate_eating(delta)
	else:
		_body.rotation.y = lerp_angle(_body.rotation.y, _rest_angle, 8.0 * delta)
		_body.position.y = _base_y + sin(_t * 2.0) * 0.01
		_body.relax(delta, carrying != null, _base_y != 0.0)

	match state:
		State.WAITING, State.QUEUED:
			if entry.is_empty():
				patience -= delta
		State.ORDERED:
			food_patience -= delta
		State.WAIT_TABLE:
			table_wait -= delta
	_update_mood()


func _update_mood() -> void:
	var new_mood := _body.mood
	if angry:
		new_mood = PersonBody.Mood.ANGRY
	elif state == State.WAITING or state == State.QUEUED:
		new_mood = _mood_for(patience / max_patience)
	elif state == State.WAIT_TABLE:
		new_mood = _mood_for(table_wait / TABLE_WAIT_TIME)
	elif state == State.ORDERED:
		new_mood = _mood_for(food_patience / max_food_patience)
	elif not pending_review.is_empty():
		# Servisten sonra yüzü verdiği puanı yansıtır.
		var stars: int = pending_review[0]
		new_mood = PersonBody.Mood.HAPPY if stars >= 4 else (PersonBody.Mood.NEUTRAL if stars == 3 else PersonBody.Mood.ANGRY)
	_body.set_mood(new_mood)

	# Kasada ve teslim alanında beklerken ikon kartta görünür.
	_icon.visible = state != State.WAITING and state != State.PAYING and state != State.ORDERED
	_icon.texture = mood_icon()
	if _body.mood == PersonBody.Mood.ANGRY:
		_icon.position.y = _body.head_top + absf(sin(_t * 6.0)) * 0.08


func _mood_for(ratio: float) -> int:
	if ratio > 0.6:
		return PersonBody.Mood.HAPPY
	if ratio > 0.3:
		return PersonBody.Mood.NEUTRAL
	return PersonBody.Mood.ANGRY


## Oturur, gövde sabit; kollar sırayla tepsiden ağza gider, yemek azalır.
func _animate_eating(delta: float) -> void:
	_eat_timer -= delta
	_body.position.y = _base_y
	for i in _body.arms.size():
		var bite := maxf(0.0, sin(_t * 2.4 + i * PI))
		_body.arms[i].rotation.x = lerpf(_body.arms[i].rotation.x, deg_to_rad(-40.0 - 105.0 * bite), 10.0 * delta)
	var items: Node3D = food.get_node_or_null("Items") if food else null
	if items:
		items.scale = Vector3.ONE * clampf(_eat_timer / EAT_TIME + 0.2, 0.3, 1.0)
	if _eat_timer <= 0.0:
		finished_eating.emit(self)


func _walk(delta: float) -> void:
	var target := _path[0]
	var to := target - position
	to.y = 0.0
	var dist := to.length()
	if dist <= SPEED * delta:
		position = target
		_path.pop_front()
		if not entry.is_empty():
			entry.pop_front()
		if _path.is_empty():
			_arrive()
		return
	# Merdivende yükseklik de yolla birlikte değişir.
	position.y = move_toward(position.y, target.y, absf(target.y - position.y) * SPEED * delta / dist)
	position += to / dist * SPEED * delta
	_body.rotation.y = lerp_angle(_body.rotation.y, atan2(to.x, to.z), 10.0 * delta)
	_body.position.y = _base_y + absf(sin(_t * 9.0)) * 0.04
	_body.animate_walk(_t, carrying != null)


func _arrive() -> void:
	match state:
		State.ARRIVING:
			state = State.WAITING
		State.TO_SEAT:
			state = State.EATING
			_eat_timer = EAT_TIME
			_set_sitting(true)
			_body.rotation.y = _rest_angle
			sat_down.emit(self)
		State.RETURNING:
			returned_tray.emit(self)
		State.LEAVING:
			queue_free()


func _set_sitting(sitting: bool) -> void:
	_base_y = -0.1 if sitting else 0.0
	_body.set_sitting(sitting)
