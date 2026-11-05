class_name Main
extends Node3D

## Üç ekranı (Market, Dükkan, Mutfak) birbirinden uzak üç istasyon olarak kurar.
## Kamera ekranlar arasında kısa bir kararmayla geçer. 3D objelere dokunma
## ve ekranlar arası kaydırma burada işlenir.

signal screen_changed(screen: int)

enum { MARKET, SHOP, KITCHEN }

const STATION_X := [-40.0, 0.0, 40.0]
const SWIPE_DISTANCE := 90.0

var screen := SHOP
var transitioning := false
## Ödeme sırasında kamera kasaya yakınlaşır.
var register_focus := false
## Mutfakta kameranın baktığı yer: "" genel, "izgara" ya da "fritoz" yakın plan
var kitchen_view := ""
signal kitchen_view_changed(view: String)
## Dükkanı incelemek için kamera açıları: [ad, göz, hedef]. İlki oyunun normal açısı.
const SHOP_CAMS := [
	["Genel", Vector3(0, 2.5, 3.3), Vector3(0, 0.95, -4.5)],
	["Kuşbakışı", Vector3(0, 9.0, 3.6), Vector3(0, 0.2, -4.6)],
	["Salon", Vector3(-4.9, 2.9, -9.4), Vector3(0.8, 0.9, -0.2)],
	["Köşe", Vector3(5.1, 3.4, 1.0), Vector3(-1.2, 0.6, -5.8)],
	["Kasa", Vector3(0.3, 2.0, 2.7), Vector3(0.1, 1.0, -0.6)],
]
const KITCHEN_CAM_NAMES := { "": "Genel", "izgara": "Izgara", "fritoz": "Fritöz", "firin": "Fırın" }
## Dükkandaki kamera açısının sırası (SHOP_CAMS)
var shop_cam := 0
signal camera_changed(name: String)
var camera: Camera3D
var market: Market
var shop: Shop
var kitchen: Kitchen
var hud: Hud

var _views: Array[Transform3D] = []
var _env: Environment
var _sun: DirectionalLight3D
## Dükkan pencerelerinin ortak cam materyali (gece kararır)
var _fade: ColorRect
var _press_pos := Vector2.ZERO
var _pressing := false
var _pending_tap: Variant = null


func _ready() -> void:
	_build_environment()

	market = Market.new()
	market.position.x = STATION_X[MARKET]
	add_child(market)
	shop = Shop.new()
	shop.position.x = STATION_X[SHOP]
	add_child(shop)
	kitchen = Kitchen.new()
	kitchen.shop = shop
	kitchen.position.x = STATION_X[KITCHEN]
	add_child(kitchen)
	kitchen.tray_filled.connect(kitchen_focus.bind(""))

	_views = [
		_view(market, Vector3(0, 2.3, 3.6), Vector3(0, 0.5, -1.5)),
		_view(shop, Vector3(0, 2.5, 3.3), Vector3(0, 0.95, -4.5)),
		_view(kitchen, Vector3(-0.15, 3.6, 2.3), Vector3(-0.15, 0.45, 1.0)),
	]
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 66.0
	add_child(camera)
	camera.global_transform = _views[screen]
	camera.make_current()
	if not GameState.setup_done:
		# Kurulumda salon yukarıdan, panelin üstünde kalacak şekilde görünür.
		camera.global_transform = Transform3D(Basis(), Vector3(0, 11.0, 4.2)).looking_at(Vector3(0, 0, -0.2), Vector3.UP)
		GameState.setup_finished.connect(func() -> void:
			create_tween().tween_property(camera, "global_transform", _views[SHOP], 1.2) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		)

	hud = Hud.new()
	hud.setup(self)
	add_child(hud)

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 10
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.1, 0.07, 0.05, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(_fade)
	_play_intro(fade_layer)


## Açılış görseli (splash.png) LoadingScreen'in ilk karesidir: oyun açılınca aynı
## ekran üstte kalır, ilk karelerde (ikonlar ve modeller hazırlanırken) çubuk dolar,
## sonra ekran hafifçe büyüyerek kaybolur.
func _play_intro(layer: CanvasLayer) -> void:
	var intro := LoadingScreen.new()
	layer.add_child(intro)
	intro.progress = 0.12
	intro.pivot_offset = get_viewport().get_visible_rect().size * 0.5
	var tween := intro.create_tween()
	tween.tween_property(intro, "progress", 0.7, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: intro.status = "Fırın ısınıyor…")
	tween.tween_property(intro, "progress", 1.0, 0.35).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void: intro.status = "Dükkan açıldı!")
	tween.tween_interval(0.2)
	tween.tween_property(intro, "modulate:a", 0.0, 0.35)
	tween.parallel().tween_property(intro, "scale", Vector2(1.06, 1.06), 0.35)
	tween.tween_callback(intro.queue_free)


## Sipariş / ödeme ekranı açıkken kasa odağı. Kamera yerinden oynamaz (3D kasaya
## yakın plan kötü görünüyordu); arkadaki sahne bulanıklaşır, ekran büyük bir
## panel olarak açılır.
func focus_register(on: bool) -> void:
	if screen != SHOP or on == register_focus:
		return
	register_focus = on


## Kasa ekranı arayüzünün telefondaki yeri: üst bar ile alt menü arasındaki
## alanın tamamı (çok uzun ekranlarda en fazla genişliğin 1.75 katı, ortalı).
func pos_screen_rect() -> Rect2:
	var view_size := get_viewport().get_visible_rect().size
	var width := view_size.x - 24.0
	var top := 190.0 + hud.safe_top()
	var bottom := view_size.y - 160.0
	var height := minf(bottom - top, width * 1.75)
	return Rect2(12.0, top + (bottom - top - height) * 0.5, width, height)


## Mutfakta kamerayı ızgaraya / fritöze yaklaştırır ya da genel görünüme döner.
## Cihazlar ekranın üst yarısında kalır (alt yarıda mutfak paneli var).
func kitchen_focus(view: String) -> void:
	if screen != KITCHEN or view == kitchen_view:
		return
	kitchen_view = view
	kitchen_view_changed.emit(view)
	var target := _views[KITCHEN]
	match view:
		"izgara":
			target = _view(kitchen, Vector3(Kitchen.GRILL_X, 2.2, 1.35), Vector3(Kitchen.GRILL_X, 0.2, 0.15))
		"firin":
			target = _view(kitchen, Vector3(Kitchen.OVEN_X, 1.75, 1.6), Vector3(Kitchen.OVEN_X, 0.55, -0.2))
		"fritoz":
			target = _view(kitchen, Vector3(Kitchen.FRYER_X, 2.0, 1.1), Vector3(Kitchen.FRYER_X, 0.3, 0.15))
	var tween := create_tween()
	tween.tween_property(camera, "global_transform", target, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


## Kamera düğmesi: dükkanda açılar arasında, mutfakta cihazlar arasında döner.
func cycle_camera() -> void:
	if transitioning:
		return
	match screen:
		SHOP:
			_set_shop_cam((shop_cam + 1) % SHOP_CAMS.size())
		KITCHEN:
			var views: Array[String] = [""]
			for device in ["izgara", "fritoz", "firin"]:
				if GameState.menu_devices().has(device):
					views.append(device)
			kitchen_focus(views[(views.find(kitchen_view) + 1) % views.size()])
			camera_changed.emit(camera_name())


func camera_name() -> String:
	match screen:
		SHOP: return SHOP_CAMS[shop_cam][0]
		KITCHEN: return KITCHEN_CAM_NAMES.get(kitchen_view, "Genel")
	return ""


func _set_shop_cam(index: int) -> void:
	shop_cam = index
	# Kuşbakışında tavan kalkar, salonun tamamı görünür.
	shop.set_ceiling_open(SHOP_CAMS[index][0] == "Kuşbakışı")
	var target := _views[SHOP] if index == 0 else _view(shop, SHOP_CAMS[index][1], SHOP_CAMS[index][2])
	var tween := create_tween()
	tween.tween_property(camera, "global_transform", target, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	camera_changed.emit(camera_name())


func _process(_delta: float) -> void:
	# Dikey ekranda genişliği, yatay ekranda (masaüstü) yüksekliği sabit tut.
	var view_size := get_viewport().get_visible_rect().size
	camera.keep_aspect = Camera3D.KEEP_WIDTH if view_size.x < view_size.y else Camera3D.KEEP_HEIGHT
	_update_daylight()


func go_to(target: int) -> void:
	target = clampi(target, MARKET, KITCHEN)
	if target == screen or transitioning or not GameState.setup_done:
		return
	register_focus = false
	if shop_cam != 0:
		shop_cam = 0
		shop.set_ceiling_open(false)
		camera_changed.emit(camera_name())
	kitchen_view = ""
	kitchen_view_changed.emit("")
	screen = target
	transitioning = true
	screen_changed.emit(screen)
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.12)
	tween.tween_callback(func() -> void: camera.global_transform = _views[screen])
	tween.tween_property(_fade, "color:a", 0.0, 0.18)
	tween.tween_callback(func() -> void: transitioning = false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT:
			go_to(screen - 1)
		elif event.keycode == KEY_RIGHT:
			go_to(screen + 1)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_press_pos = event.position
		elif _pressing:
			_pressing = false
			var delta: Vector2 = event.position - _press_pos
			if absf(delta.x) > SWIPE_DISTANCE and absf(delta.x) > absf(delta.y):
				# Sağa kaydırınca soldaki ekrana geçilir (ve tersi).
				go_to(screen - 1 if delta.x > 0 else screen + 1)
			elif delta.length() < 30.0:
				_pending_tap = event.position


func _physics_process(_delta: float) -> void:
	if _pending_tap == null or transitioning:
		return
	var pos: Vector2 = _pending_tap
	_pending_tap = null
	var from := camera.project_ray_origin(pos)
	var query := PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(pos) * 30.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit["collider"].has_meta("tap"):
		(hit["collider"].get_meta("tap") as Callable).call()


func _view(station: Node3D, eye: Vector3, target: Vector3) -> Transform3D:
	var origin := station.position
	return Transform3D(Basis(), origin + eye).looking_at(origin + target, Vector3.UP)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	# Sahnenin dışı (toptancının tavanı, mutfak tezgâhının altı) koyu blok gibi
	# görünmesin: duvarlarla uyumlu sıcak krem.
	env.background_color = Color("#eadcc8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#fff1e0")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.4
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	_env = env

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-50, 25, 0)
	_sun.light_energy = 0.9
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 15.0
	add_child(_sun)


## Saate göre ışık: sabah sıcak, öğlen parlak, akşam turuncu, gece lacivert.
## Pencereden görünen gökyüzü de buna uyar.
func _update_daylight() -> void:
	var t := inverse_lerp(GameState.OPEN_TIME, GameState.CLOSE_TIME, GameState.minutes)
	var light := 0.12
	var tint := Color("#7f8fd6")
	if GameState.is_open:
		light = clampf(1.0 - pow((t - 0.35) * 1.6, 2.0), 0.35, 1.0)
		tint = Color("#ffe2b8").lerp(Color.WHITE, clampf(t * 3.0, 0.0, 1.0)) if t < 0.5 else Color.WHITE.lerp(Color("#ff9a5a"), (t - 0.5) * 2.0)
	_sun.light_energy = 0.9 * light
	_sun.light_color = tint
	_env.ambient_light_energy = 0.3 + 0.35 * light
	_env.ambient_light_color = Color("#fff1e0").lerp(Color("#5a6aa8"), 1.0 - light)
	_env.background_color = Color("#eadcc8").lerp(Color("#3a3548"), (1.0 - light) * 0.8)
	shop.set_daylight(light, tint)
