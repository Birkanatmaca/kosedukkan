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
	["Yan Salon", Vector3(-8.6, 3.6, 3.4), Vector3(-9.0, 0.6, -4.8)],
	["Bahçe", Vector3(8.6, 3.6, 3.4), Vector3(9.0, 0.6, -4.8)],
]
## Bu açılar ancak ilgili genişletme alınınca kamera sırasına girer.
const SHOP_CAM_UPGRADE := { "Yan Salon": "annex", "Bahçe": "garden" }
const KITCHEN_CAM_NAMES := { "": "Genel", "izgara": "Izgara", "fritoz": "Fritöz", "firin": "Fırın" }
## Dükkandaki kamera açısının sırası (SHOP_CAMS)
var shop_cam := 0
signal camera_changed(name: String)
var camera: Camera3D
var market: Market
var shop: Shop
var kitchen: Kitchen
var hud: Hud

## Mahalle modu: oyuncu karakteriyle dükkanın önündeki kaldırımda yürür.
var walking := false
var walker: Walker
signal walk_changed(active: bool)
## Yürüyüşte dokunulan dükkan yeri (önüne varınca Hud panelini açar)
signal lot_reached(lot: int)
var _walk_target_lot := -1
## Kamera yoldan, iki şeridin arasından kaldırıma bakar (yakın şeritten araba geçmez).
const WALK_EYE := Vector3(0, 5.4, -15.6)
const WALK_LOOK := Vector3(0, 1.5, -10.2)

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
	shop.neighborhood.ground_tapped.connect(_walk_to_point)
	shop.neighborhood.lot_tapped.connect(_walk_to_lot)
	shop.neighborhood.home_tapped.connect(end_walk)

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
			# Fırın büyüdükçe kamera biraz geri çekilir.
			var grow := kitchen.oven_scale() - 1.0
			var ox := kitchen.oven_center_x()
			target = _view(kitchen, Vector3(ox, 1.75 + grow * 0.8, 1.6 + grow * 1.6), Vector3(ox, 0.55, -0.2))
		"fritoz":
			target = _view(kitchen, Vector3(Kitchen.FRYER_X, 2.0, 1.1), Vector3(Kitchen.FRYER_X, 0.3, 0.15))
	var tween := create_tween()
	tween.tween_property(camera, "global_transform", target, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


## Kamera düğmesi: dükkanda açılar arasında, mutfakta cihazlar arasında döner.
func cycle_camera() -> void:
	if transitioning or walking:
		return
	match screen:
		SHOP:
			var next := (shop_cam + 1) % SHOP_CAMS.size()
			while next != 0 and SHOP_CAM_UPGRADE.has(SHOP_CAMS[next][0]) \
					and GameState.upgrade_level(SHOP_CAM_UPGRADE[SHOP_CAMS[next][0]]) == 0:
				next = (next + 1) % SHOP_CAMS.size()
			_set_shop_cam(next)
		KITCHEN:
			var views: Array[String] = [""]
			for device in ["izgara", "fritoz", "firin"]:
				if GameState.menu_devices().has(device):
					views.append(device)
			kitchen_focus(views[(views.find(kitchen_view) + 1) % views.size()])
			camera_changed.emit(camera_name())


func camera_name() -> String:
	if walking:
		return "Mahalle"
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


func _process(delta: float) -> void:
	# Dikey ekranda genişliği, yatay ekranda (masaüstü) yüksekliği sabit tut.
	var view_size := get_viewport().get_visible_rect().size
	camera.keep_aspect = Camera3D.KEEP_WIDTH if view_size.x < view_size.y else Camera3D.KEEP_HEIGHT
	_update_daylight()
	if walking and walker:
		var x := clampf(walker.position.x, -Neighborhood.WALK_X + 2.0, Neighborhood.WALK_X - 2.0)
		var target := _view(shop, WALK_EYE + Vector3(x, 0, 0), WALK_LOOK + Vector3(x, 0, 0))
		camera.global_transform = camera.global_transform.interpolate_with(target, minf(1.0, 3.5 * delta))


# --- Mahalle ---------------------------------------------------------------------

## Dükkandan çıkar: karakter kapıdan kaldırıma yürür, kamera yoldan bakar.
func start_walk() -> void:
	if walking or transitioning or screen != SHOP or not GameState.setup_done:
		return
	walking = true
	register_focus = false
	if shop_cam != 0:
		shop_cam = 0
		shop.set_ceiling_open(false)
	walker = Walker.new()
	shop.add_child(walker)
	walker.position = Vector3(0, 0, Shop.DOOR.z + 0.6)
	walker.walk([Shop.DOOR, Vector3(0, 0, -10.8), Vector3(0, 0, Neighborhood.WALK_Z)], PI)
	shop.set_walk_mode(true)
	camera_changed.emit(camera_name())
	walk_changed.emit(true)


## Dükkana döner: karakter kapıdan girer, kamera salona döner.
func end_walk() -> void:
	if not walking:
		return
	walking = false
	_walk_target_lot = -1
	shop.set_walk_mode(false)
	if is_instance_valid(walker):
		walker.walk(_sidewalk_path(Vector3(0, 0, Neighborhood.WALK_Z)) + [Vector3(0, 0, -10.8), Shop.DOOR, Vector3(0, 0, Shop.DOOR.z + 0.8)])
		walker.arrived.connect(walker.queue_free)
	walker = null
	var tween := create_tween()
	tween.tween_interval(0.3)
	tween.tween_property(camera, "global_transform", _views[SHOP], 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	camera_changed.emit(camera_name())
	walk_changed.emit(false)


## Kaldırımda bir noktaya: kapının önündeyse önce kaldırıma iner.
func _sidewalk_path(to: Vector3) -> Array:
	var path: Array = []
	if walker and walker.position.z > -11.0:
		path.append(Vector3(walker.position.x, 0, Neighborhood.WALK_Z))
	path.append(to)
	return path


func _walk_to_point(point: Vector3) -> void:
	if not walking:
		return
	_walk_target_lot = -1
	var local := shop.to_local(point)
	var x := clampf(local.x, -Neighborhood.WALK_X, Neighborhood.WALK_X)
	walker.walk(_sidewalk_path(Vector3(x, 0, Neighborhood.WALK_Z)), PI)
	Sfx.play("tap")


## Bir dükkana dokunuldu: önündeki kaldırıma yürür, varınca Hud bilgi panelini açar.
func _walk_to_lot(lot: int) -> void:
	if not walking:
		return
	var x: float = Branches.LOTS[lot]["x"]
	_walk_target_lot = lot
	walker.walk(_sidewalk_path(Vector3(x + 0.9, 0, -10.9)), 0.0)
	if not walker.arrived.is_connected(_on_walker_arrived):
		walker.arrived.connect(_on_walker_arrived)
	Sfx.play("tap")


func _on_walker_arrived() -> void:
	if walking and _walk_target_lot != -1:
		var lot := _walk_target_lot
		_walk_target_lot = -1
		lot_reached.emit(lot)


## Başka dükkana geçer: kısa kararma, kayıt ve sahne yeniden kurulur.
func switch_shop(index: int) -> void:
	if transitioning:
		return
	transitioning = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.3)
	tween.tween_callback(func() -> void:
		GameState.switch_shop(index)
		Saves.save_game()
		get_tree().reload_current_scene()
	)


func go_to(target: int) -> void:
	target = clampi(target, MARKET, KITCHEN)
	if target == screen or transitioning or not GameState.setup_done:
		return
	if walking:
		end_walk()
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
			if absf(delta.x) > SWIPE_DISTANCE and absf(delta.x) > absf(delta.y) and not walking:
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
	# Mahallede sadece kaldırım ve dükkanlara dokunulur (katman 2; müşteriler, masalar değil).
	query.collision_mask = Neighborhood.LAYER if walking else 1
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit["collider"].has_meta("tap_at"):
		# Dokunulan noktayı isteyenler (mutfaktaki cihazlar: en yakın ürün seçilir)
		(hit["collider"].get_meta("tap_at") as Callable).call(hit["position"])
	elif hit and hit["collider"].has_meta("tap"):
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
	if walking:
		# Sokakta binaların üstü gökyüzü
		_env.background_color = Color("#1a2140").lerp(Color("#bfe0f5") * tint, light)
	shop.set_daylight(light, tint)
