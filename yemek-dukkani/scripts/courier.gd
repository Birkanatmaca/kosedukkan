class_name Courier
extends Node3D

## Paket servis kuryesi. Dükkanda tezgâhın sağ ucunda telefonuyla konuşarak
## bekler. Oyuncu hazır paketleri ona verir (en fazla Staff.COURIER_CAPACITY);
## kuryeye dokununca paketleri kucaklayıp koşarak çıkar, kaldırımdan motoruna
## gider, yolda kaybolur. Paketleri teslim edince (yolun yarısında) para ve
## yorumlar gelir; sonra geri döner. Beklerken elindeki paketlerin müşterileri
## beklemeye devam eder: çok paket biriktirmek hızlı göndermekle yarışır.

enum State { ENTERING, WAITING, LEAVING, AWAY, RETURNING }

## Beklediği yerler: kasanın solundaki paket teslim noktası (tezgâha bakar)
const SPOTS := [Vector3(-1.1, 0, 0.3), Vector3(-1.85, 0, 0.3)]
const WALK_SPEED := 2.2

var data: Dictionary
var shop: Shop
var spot_index := 0
var state := State.ENTERING
## Taşıdığı paket siparişleri
var packages: Array[Dictionary] = []

var _body: ModelBody
var _path: Array[Vector3] = []
var _speed := WALK_SPEED
var _running := false
var _rest_angle := 0.0
var _t := randf() * 10.0
var _timer := 0.0
var _delivered := false
var _side := 1.0
var _stack: Node3D
## Hud kartının duracağı yükseklik (başın üstü)
var card_height := 2.2


func _ready() -> void:
	_speed = Staff.move_speed(data)
	_body = ModelBody.new()
	add_child(_body)
	_body.build_model(data.get("model", "kurye"), CharacterSkin.look_from_save(data.get("look", {})))
	_stack = Node3D.new()
	_stack.position = _body.carry_offset
	_body.add_child(_stack)
	card_height = _body.head_top - 0.15
	var body := Util.collider_box(self, Vector3(0.7, 1.9, 0.7), Vector3(0, 0.95, 0))
	body.set_meta("tap", func() -> void: shop.dispatch(self))
	# İlk gün kapıdan girip yerine geçer.
	position = Vector3(-Shop.SIDE_LANE_X, 0, Shop.DOOR.z + 0.7)
	_follow(_in_path(), 0.0)
	_refresh_status()


func is_full() -> bool:
	return packages.size() >= Staff.COURIER_CAPACITY


## Paket alabilir mi: dükkanda bekliyor ve kucağında yer var.
func can_load() -> bool:
	return state == State.WAITING and not is_full()


## Paketi kucağındaki yığına koyar (2×2 dizilir).
func load_package(order: Dictionary, bag: Node3D) -> void:
	packages.append(order)
	var i := packages.size() - 1
	bag.reparent(_stack)
	bag.rotation = Vector3.ZERO
	var target := Vector3((i % 2 - 0.5) * 0.17, (i / 2) * 0.18, 0)
	bag.create_tween().tween_property(bag, "position", target, 0.3).set_trans(Tween.TRANS_SINE)
	bag.create_tween().tween_property(bag, "scale", Vector3.ONE * 0.6, 0.3)
	_refresh_status()
	shop.couriers_changed.emit()


## Siparişi kucağından çıkarır (beklerken iptal olduysa).
func drop_package(order: Dictionary) -> void:
	var i := packages.find(order)
	if i == -1:
		return
	packages.remove_at(i)
	_rebuild_stack()
	_refresh_status()


## Yola çıkar: koşarak kapıdan çıkar, kaldırımın bir ucunda kaybolur.
func depart() -> void:
	state = State.LEAVING
	_running = true
	_delivered = false
	_side = [-1.0, 1.0].pick_random()
	var path: Array = shop.exit_path(position, -1.0)
	path[path.size() - 1] = Vector3(_side * Shop.STREET_END_X, 0, Street.SIDEWALK_Z)
	path[path.size() - 2] = Vector3(_side * 1.0, 0, Street.SIDEWALK_Z)
	_follow(path, 0.0)
	_refresh_status()
	shop.couriers_changed.emit()


## Yoldayken kalan süre (sn); dükkandaysa 0.
func time_left() -> float:
	return _timer if state == State.AWAY else 0.0


func status_text() -> String:
	match state:
		State.ENTERING:
			return "İşe geliyor"
		State.WAITING:
			return "Dükkanda • %d/%d paket" % [packages.size(), Staff.COURIER_CAPACITY]
		State.LEAVING:
			return "Yola çıkıyor • %d paket" % packages.size()
		State.AWAY:
			return ("Teslimatta • %d paket" % packages.size()) if not _delivered else "Dönüyor (%d sn)" % ceili(_timer)
		_:
			return "Dükkana dönüyor"


func _process(delta: float) -> void:
	_t += delta
	if state == State.AWAY:
		_timer -= delta
		# Yolun yarısında paketler teslim edilir; para ve yorumlar gelir.
		if not _delivered and _timer <= _trip_half():
			_delivered = true
			shop.complete_deliveries(self, packages.duplicate())
			packages.clear()
			_rebuild_stack()
			shop.couriers_changed.emit()
		if _timer <= 0.0:
			_come_back()
		return
	if not _path.is_empty():
		_walk(delta)
	else:
		_body.rotation.y = lerp_angle(_body.rotation.y, _rest_angle, 8.0 * delta)
		_body.relax(delta, not packages.is_empty(), false)


var _trip_total := 1.0


func _trip_half() -> float:
	return _trip_total * 0.5


func _come_back() -> void:
	state = State.RETURNING
	_running = false
	visible = true
	Sfx.play("scooter", 0.1, 1)
	position = Vector3(_side * Shop.STREET_END_X, 0, Street.SIDEWALK_Z)
	var path: Array[Vector3] = [Vector3(_side * 1.0, 0, Street.SIDEWALK_Z), Vector3(0, 0, -10.8), Shop.DOOR]
	path.append_array(_in_path())
	_follow(path, 0.0)


## Kapıdan beklediği yere: sağ şeritten tezgâha.
func _in_path() -> Array[Vector3]:
	var spot: Vector3 = SPOTS[spot_index]
	return [Vector3(-Shop.SIDE_LANE_X, 0, Shop.DOOR.z + 0.7), Vector3(-Shop.SIDE_LANE_X, 0, Shop.AISLE_FRONT.z), spot]


func _follow(path: Array, rest_angle: float) -> void:
	_path.clear()
	for p in path:
		_path.append(p)
	_rest_angle = rest_angle


func _walk(delta: float) -> void:
	var target := _path[0]
	var to := target - position
	to.y = 0.0
	var dist := to.length()
	var speed := _speed * (1.45 if _running else 1.0)
	if dist <= speed * delta:
		position = Vector3(target.x, position.y, target.z)
		_path.pop_front()
		if _path.is_empty():
			_arrive()
		return
	position += to / dist * speed * delta
	_body.rotation.y = lerp_angle(_body.rotation.y, atan2(to.x, to.z), 10.0 * delta)
	if _running:
		_body.animate_run(not packages.is_empty())
	else:
		_body.animate_walk(_t, not packages.is_empty())


func _arrive() -> void:
	match state:
		State.ENTERING, State.RETURNING:
			state = State.WAITING
			_refresh_status()
			shop.couriers_changed.emit()
		State.LEAVING:
			# Kaldırımın ucunda motoruna biner: görünmez olur, yolculuk başlar.
			Sfx.play("scooter", 0.1, 1)
			visible = false
			state = State.AWAY
			_trip_total = Staff.trip_time(data, packages.size())
			_timer = _trip_total
			shop.couriers_changed.emit()


func _rebuild_stack() -> void:
	var bags := _stack.get_children()
	for i in bags.size():
		if i >= packages.size():
			bags[i].queue_free()
		else:
			(bags[i] as Node3D).position = Vector3((i % 2 - 0.5) * 0.17, (i / 2) * 0.18, 0)


func _refresh_status() -> void:
	pass
