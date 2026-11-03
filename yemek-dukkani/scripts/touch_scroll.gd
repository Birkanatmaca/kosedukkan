class_name TouchScroll
extends Node

## Telefonda parmakla kaydırma: ScrollContainer'ın içindeki butonlar dokunuşu
## kendine aldığı için liste sürüklenemiyordu. Bu düğüm dokunuşu herkesten önce
## (_input) görür; parmak eşiği geçecek kadar kayınca listeyi kaydırır ve altında
## kalan butonun basılmasını iptal eder (kaydırırken yanlışlıkla satın alınmaz).
## Bırakınca hafifçe süzülerek durur. Hud her ScrollContainer'a kendiliğinden takar.

## Bu kadar piksel kaymadan dokunuş normal tıklama sayılır.
const THRESHOLD := 12.0
## Süzülmenin yavaşlaması (saniyede)
const FRICTION := 6.0

var _scroll: ScrollContainer
var _touch := -1
var _start := Vector2.ZERO
var _last := Vector2.ZERO
var _dragging := false
var _velocity := Vector2.ZERO
## Kendi gönderdiğimiz sahte "bırakma" olayını yok saymak için
var _cancelling := false


func _ready() -> void:
	_scroll = get_parent() as ScrollContainer
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if _cancelling:
		return
	if not _scroll.is_visible_in_tree():
		_touch = -1
		return
	# Dokunmatik ekranda dokunuş olayları, masaüstünde fare kullanılır (ikisi birden değil).
	var touchscreen := DisplayServer.is_touchscreen_available()
	if event is InputEventScreenTouch and touchscreen:
		_press(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag and touchscreen:
		if event.index == _touch:
			_move(event.position)
	elif event is InputEventMouseButton and not touchscreen and event.button_index == MOUSE_BUTTON_LEFT:
		_press(0, event.position, event.pressed)
	elif event is InputEventMouseMotion and not touchscreen and _touch == 0:
		_move(event.position)


func _process(delta: float) -> void:
	if _touch != -1 or _velocity.length() < 5.0:
		return
	_scroll_by(_velocity * delta)
	_velocity = _velocity.lerp(Vector2.ZERO, minf(1.0, FRICTION * delta))


func _press(index: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		if _touch == -1 and _scroll.get_global_rect().has_point(pos):
			_touch = index
			_start = pos
			_last = pos
			_dragging = false
			_velocity = Vector2.ZERO
	elif index == _touch:
		_touch = -1
		if _dragging:
			get_viewport().set_input_as_handled()
		_dragging = false


func _move(pos: Vector2) -> void:
	var delta := pos - _last
	_last = pos
	if not _dragging:
		if pos.distance_to(_start) < THRESHOLD:
			return
		_dragging = true
		_cancel_press()
	_scroll_by(-delta)
	_velocity = -delta / maxf(get_process_delta_time(), 0.001)
	get_viewport().set_input_as_handled()


func _scroll_by(amount: Vector2) -> void:
	if _scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		_scroll.scroll_vertical += int(amount.y)
	if _scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		_scroll.scroll_horizontal += int(amount.x)


## Parmağın altındaki buton basılı kalmasın: dışarıda bırakılmış gibi yaparız,
## buton "pressed" vermeden normale döner.
func _cancel_press() -> void:
	# Buton "parmak hâlâ üstümde mi?" kararını son hareket olayına göre verir:
	# önce dışarı çıkmış gibi yap, sonra bırak.
	var away := InputEventMouseMotion.new()
	away.position = Vector2(-10000, -10000)
	away.global_position = away.position
	away.button_mask = MOUSE_BUTTON_MASK_LEFT
	_cancelling = true
	get_viewport().push_input(away)
	_cancelling = false
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(-10000, -10000)
	release.global_position = release.position
	_cancelling = true
	get_viewport().push_input(release)
	_cancelling = false

