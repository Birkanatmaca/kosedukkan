class_name Worker
extends Node3D

## Garson / temizlikçi. Hep salonda görünür ve boş durmaz: sırayla yerleri
## süpürür ya da pencereleri siler. Kirli masa olunca hemen gidip elindeki bezle
## siler (masanın üstünde ilerleme görünür), tepsiyi toplayıp tezgâhın ucuna bırakır.
## Tembel olan arada mola verir. Meshy modeliyle çizilir; gömleği, pantolonu, teni
## ve saçı kişiye göre, önlüğü ve eldivenleri dükkanın boyasına göre boyanır.

enum State { IDLE, TO_TABLE, CLEANING, TO_DROP, RESTING, LEAVING, TO_SWEEP, SWEEPING, TO_WINDOW, WINDOW }

## Kirli tepsilerin bırakıldığı tezgâh ucu
const DROP := Vector3(-2.4, 0, 0.45)
## Süpürülecek yerler: koridor kenarları ve masa sıralarının önü
const SWEEP_POINTS := [
	Vector3(-1.05, 0, -2.6), Vector3(1.05, 0, -2.6), Vector3(-1.05, 0, -4.8), Vector3(1.05, 0, -4.8),
	Vector3(-1.05, 0, -7.0), Vector3(1.05, 0, -7.0), Vector3(-2.0, 0, -1.95), Vector3(2.0, 0, -1.95),
	Vector3(-3.4, 0, -4.25), Vector3(3.4, 0, -4.25), Vector3(-2.0, 0, -6.55), Vector3(2.0, 0, -6.55),
]
## Silinecek pencerelerin önü: [durulacak yer, bakış açısı]. Yan pencerelerde masa
## sıralarının arasında durur.
const WINDOW_SPOTS := [
	[Vector3(-3.0, 0, -9.5), PI], [Vector3(-4.0, 0, -9.5), PI], [Vector3(3.0, 0, -9.5), PI], [Vector3(4.0, 0, -9.5), PI],
]
## Süpürgenin ucu karakterin önünde bu uzaklıkta yere değer.
const BROOM_REACH := 0.55

var data: Dictionary
var shop: Shop
var state := State.IDLE

var _speed := 2.2
var _path: Array[Vector3] = []
var _rest_angle := 0.0
var _timer := 0.0
var _clean_total := 1.0
var _t := randf() * 10.0
var _table: Dictionary
var _carry: Node3D
var _body: ModelBody
var _broom: Node3D
var _cloth: Node3D
var _sponge: Node3D
var _dust: CPUParticles3D
var _icon: Sprite3D
var _name_tag: Label3D


func _ready() -> void:
	_speed = Staff.move_speed(data)
	# Eski kayıtlarda görünüm yoksa şimdi verilir (bir sonraki kayıtta saklanır).
	if not data.has("look"):
		data["look"] = CharacterSkin.look_to_save(CharacterSkin.random_look())
	_body = ModelBody.new()
	add_child(_body)
	_body.build_model(data.get("model", Staff.WORKER_MODELS["erkek"]), CharacterSkin.look_from_save(data["look"]))
	var colors := shop.uniform_colors()
	_body.set_uniform(colors[0], colors[1])
	_build_tools()

	_icon = Icons.sprite(null, _body.head_top + 0.3)
	add_child(_icon)
	_name_tag = Util.label3d(data["name"], 52, Color.WHITE, Vector3(0, _body.head_top, 0))
	_name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_tag.outline_size = 14
	_name_tag.outline_modulate = Color(0.16, 0.11, 0.09)
	add_child(_name_tag)
	# İlk gün kapıdan girip işe koyulur.
	_follow([Vector3(-Shop.SIDE_LANE_X, 0, Shop.DOOR.z + 0.7)], 0.0)


## Önlük ve eldiven rengi (dükkanın boyası değişince Shop çağırır).
func set_uniform(apron: Color, gloves: Color) -> void:
	_body.set_uniform(apron, gloves)


func fire() -> void:
	if not _table.is_empty() and _table["cleaner"] == self:
		shop.release_cleaning(_table)
	if _carry:
		_carry.queue_free()
		_carry = null
	state = State.LEAVING
	_set_icon("hand", UiKit.BLUE)
	_show_tool(null)
	var path := Shop.corridor_path(position, Vector3(-Shop.SIDE_LANE_X, 0, Shop.DOOR.z + 0.7))
	path.append(Shop.DOOR)
	_follow(path, 0.0)


func _process(delta: float) -> void:
	_t += delta
	if not _path.is_empty():
		_walk(delta)
	else:
		_body.rotation.y = lerp_angle(_body.rotation.y, _rest_angle, 8.0 * delta)
		match state:
			State.CLEANING:
				_body.play_action("wipe")
			State.SWEEPING:
				_body.play_action("sweep")
			State.WINDOW:
				_body.play_action("window")
			_:
				_body.relax(delta, _carry != null, false)
	if _broom.visible:
		_aim_broom()

	match state:
		State.IDLE, State.TO_SWEEP, State.SWEEPING, State.TO_WINDOW, State.WINDOW:
			# Kirli masa her şeyden önce gelir.
			var table := shop.claim_dirty_table(self)
			if not table.is_empty():
				_go_to_table(table)
			elif state == State.SWEEPING or state == State.WINDOW:
				_timer -= delta
				if _timer <= 0.0:
					_go_work()
			elif state == State.IDLE:
				_go_work()
		State.CLEANING:
			_timer -= delta
			shop.set_clean_progress(_table, 1.0 - _timer / _clean_total)
			if _timer <= 0.0:
				_finish_cleaning()
		State.RESTING:
			_timer -= delta
			if _timer <= 0.0:
				state = State.IDLE


## Başının üstündeki durum rozeti; boş isim rozeti gizler.
func _set_icon(icon: String, color: Color) -> void:
	_icon.visible = icon != ""
	if icon != "":
		_icon.texture = Icons.badge(icon, color)


func _go_to_table(table: Dictionary) -> void:
	_table = table
	state = State.TO_TABLE
	_show_tool(null)
	_set_icon("circle-alert", UiKit.ORANGE)
	var pos: Vector3 = table["pos"]
	# Masanın önünde, koridor tarafında durup siler (ön bahçede kaldırım tarafında).
	var spot := Vector3(pos.x - signf(pos.x) * 0.3, 0, pos.z + Shop.LANE_OFFSET)
	if Shop.is_outside(pos):
		spot = Vector3(pos.x, 0, Shop.PATIO_LANE_Z)
	_follow(Shop.corridor_path(position, spot), PI)


## Boşta kalınca iş bulur: çoğunlukla yer süpürür, arada pencere siler.
func _go_work() -> void:
	_show_tool(null)
	_set_icon("", Color.WHITE)
	if randf() < 0.4:
		state = State.TO_WINDOW
		var spot: Array = WINDOW_SPOTS.pick_random()
		_follow(Shop.corridor_path(position, spot[0]), spot[1])
		return
	state = State.TO_SWEEP
	var target: Vector3 = SWEEP_POINTS.pick_random()
	while target.distance_to(position) < 0.5:
		target = SWEEP_POINTS.pick_random()
	_follow(Shop.corridor_path(position, target), randf_range(-PI, PI))


func _finish_cleaning() -> void:
	_show_tool(null)
	_carry = shop.collect_tray(_table)
	_table = {}
	if _carry:
		_carry.reparent(_body)
		_carry.rotation = Vector3.ZERO
		_carry.position = _body.carry_offset
	state = State.TO_DROP
	_set_icon("", Color.WHITE)
	var path := Shop.corridor_path(position, Vector3(-Shop.SIDE_LANE_X, 0, Shop.AISLE_FRONT.z))
	path.append(DROP)
	_follow(path, 0.0)


func _arrive() -> void:
	match state:
		State.TO_TABLE:
			state = State.CLEANING
			_clean_total = Staff.clean_time(data)
			_timer = _clean_total
			_show_tool(_cloth)
			_set_icon("spray-can", UiKit.BLUE)
			Sfx.play("spray", 0.1, Main.SHOP)
		State.TO_SWEEP:
			state = State.SWEEPING
			_timer = randf_range(4.0, 6.0)
			_show_tool(_broom)
			_set_icon("brush", UiKit.GREEN)
		State.TO_WINDOW:
			state = State.WINDOW
			_timer = randf_range(4.0, 6.0)
			_show_tool(_sponge)
			_set_icon("sparkles", UiKit.BLUE)
		State.TO_DROP:
			if _carry:
				_carry.queue_free()
				_carry = null
			Sfx.play("pop")
			if randf() < Staff.rest_chance(data):
				state = State.RESTING
				_timer = randf_range(5.0, 9.0)
				_set_icon("coffee", UiKit.PURPLE)
			else:
				state = State.IDLE
		State.LEAVING:
			queue_free()


## Elindeki aleti değiştirir (null: eli boş).
func _show_tool(tool: Node3D) -> void:
	for item in [_broom, _cloth, _sponge]:
		item.visible = item == tool
	_dust.emitting = tool == _broom


## Süpürge sağ elden geçer, ucu karakterin önünde yere değer; el hareket ettikçe
## süpürge de yerde sağa sola kayar.
func _aim_broom() -> void:
	var hand := _body.hand_position("Right")
	var forward := _body.global_basis.z.normalized()
	var head := hand + forward * BROOM_REACH
	head.y = global_position.y + 0.02
	var up := (hand - head).normalized()
	var side := up.cross(forward).normalized()
	_broom.global_transform = Transform3D(Basis(side, up, side.cross(up)), head)


## Aletler: süpürge (sahneye bağlı, her karede ele göre yönlenir), masa bezi
## ve pencere süngeri (sağ ele bağlı).
func _build_tools() -> void:
	_broom = Node3D.new()
	_broom.top_level = true
	add_child(_broom)
	_broom.add_child(Util.cylinder(0.016, 1.15, Color("#b07a48"), Vector3(0, 0.6, 0)))
	_broom.add_child(Util.box(Vector3(0.32, 0.1, 0.07), Color("#e0b84a"), Vector3(0, 0.05, 0)))
	_broom.add_child(Util.box(Vector3(0.34, 0.035, 0.08), Color("#8a5a3a"), Vector3(0, 0.11, 0)))

	# El kemiğinde parmaklar +Y, avuç +Z yönünde: bez ve sünger avucun önünde durur.
	_cloth = Node3D.new()
	_cloth.add_child(Util.box(Vector3(0.2, 0.17, 0.014), Color("#dfeaf5"), Vector3(0, 0.08, 0.055)))
	var flap := Util.box(Vector3(0.2, 0.08, 0.012), Color("#c9d9ea"), Vector3(0, -0.02, 0.07))
	flap.rotation_degrees.x = 35
	_cloth.add_child(flap)
	_body.hold(_cloth, "Right")

	_sponge = Node3D.new()
	_sponge.add_child(Util.box(Vector3(0.13, 0.09, 0.05), Color("#ffd33d"), Vector3(0, 0.08, 0.06)))
	_sponge.add_child(Util.box(Vector3(0.13, 0.09, 0.018), Color("#3fae5a"), Vector3(0, 0.08, 0.094)))
	_body.hold(_sponge, "Right")

	_dust = CPUParticles3D.new()
	_dust.emitting = false
	_dust.amount = 10
	_dust.lifetime = 0.8
	_dust.position = Vector3(0, 0.02, 0)
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(0.2, 0.02, 0.05)
	_dust.direction = Vector3.UP
	_dust.spread = 60.0
	_dust.gravity = Vector3(0, 0.2, 0)
	_dust.initial_velocity_min = 0.1
	_dust.initial_velocity_max = 0.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.75, 0.65, 0.5, 0.6))
	ramp.set_color(1, Color(0.75, 0.65, 0.5, 0.0))
	_dust.color_ramp = ramp
	var mesh := SphereMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.06
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	_dust.mesh = mesh
	_broom.add_child(_dust)
	_show_tool(null)


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
	if dist <= _speed * delta:
		position = Vector3(target.x, position.y, target.z)
		_path.pop_front()
		if _path.is_empty():
			_arrive()
		return
	position += to / dist * _speed * delta
	_body.rotation.y = lerp_angle(_body.rotation.y, atan2(to.x, to.z), 10.0 * delta)
	_body.animate_walk(_t, _carry != null)
