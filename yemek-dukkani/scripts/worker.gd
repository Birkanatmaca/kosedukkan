class_name Worker
extends Node3D

## Garson / temizlikçi. Hep salonda görünür: boştayken elindeki süpürgeyle
## koridorlarda dolaşıp yerleri süpürür. Kirli masa olunca hemen gidip siler
## (masanın üstünde ilerleme görünür), tepsiyi toplayıp tezgâhın ucuna bırakır.
## Tembel olan arada mola verir.

enum State { IDLE, TO_TABLE, CLEANING, TO_DROP, RESTING, LEAVING, TO_SWEEP, SWEEPING }

## Kirli tepsilerin bırakıldığı tezgâh ucu
const DROP := Vector3(-2.4, 0, 0.45)
## Süpürülecek yerler: koridor kenarları ve masa sıralarının önü
const SWEEP_POINTS := [
	Vector3(-1.05, 0, -2.6), Vector3(1.05, 0, -2.6), Vector3(-1.05, 0, -4.8), Vector3(1.05, 0, -4.8),
	Vector3(-1.05, 0, -7.0), Vector3(1.05, 0, -7.0), Vector3(-2.0, 0, -1.95), Vector3(2.0, 0, -1.95),
	Vector3(-3.4, 0, -4.25), Vector3(3.4, 0, -4.25), Vector3(-2.0, 0, -6.55), Vector3(2.0, 0, -6.55),
]

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
var _body: PersonBody
var _broom: Node3D
var _dust: CPUParticles3D
var _icon: Sprite3D
var _name_tag: Label3D


func _ready() -> void:
	_speed = Staff.move_speed(data)
	_body = PersonBody.new()
	add_child(_body)
	_body.build(Color("#2f3b52"), [Color("#f5d2b8"), Color("#e8b48f"), Color("#c68863")].pick_random(), Color("#2b1d16"), Color("#22262e"))
	# Önlük ve şapka
	_body.add_child(Util.box(Vector3(0.4, 0.62, 0.04), Color("#f4efe6"), Vector3(0, 0.82, 0.26)))
	_body.add_child(Util.cylinder(0.2, 0.12, Color("#e8553e"), Vector3(0, 1.7, -0.01)))
	_body.add_child(Util.box(Vector3(0.22, 0.02, 0.14), Color("#e8553e"), Vector3(0, 1.65, 0.2)))
	_build_broom()

	_icon = Icons.sprite(null, 2.1)
	add_child(_icon)
	_name_tag = Util.label3d(data["name"], 52, Color.WHITE, Vector3(0, 1.85, 0))
	_name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_tag.outline_size = 14
	_name_tag.outline_modulate = Color(0.16, 0.11, 0.09)
	add_child(_name_tag)
	# İlk gün kapıdan girip süpürmeye başlar.
	_follow([Vector3(-Shop.SIDE_LANE_X, 0, Shop.DOOR.z + 0.7)], 0.0)


func fire() -> void:
	if not _table.is_empty() and _table["cleaner"] == self:
		shop.release_cleaning(_table)
	if _carry:
		_carry.queue_free()
		_carry = null
	state = State.LEAVING
	_set_icon("hand", UiKit.BLUE)
	_dust.emitting = false
	var path := Shop.corridor_path(position, Vector3(-Shop.SIDE_LANE_X, 0, Shop.DOOR.z + 0.7))
	path.append(Shop.DOOR)
	_follow(path, 0.0)


func _process(delta: float) -> void:
	_t += delta
	_broom.visible = _carry == null and state != State.CLEANING
	if not _path.is_empty():
		_walk(delta)
	else:
		_body.rotation.y = lerp_angle(_body.rotation.y, _rest_angle, 8.0 * delta)
		_body.position.y = sin(_t * 2.0) * 0.01
		match state:
			State.CLEANING:
				_animate_wiping()
			State.SWEEPING:
				_animate_sweeping()
			_:
				_body.relax(delta, _carry != null, false)
				_broom.rotation.z = lerpf(_broom.rotation.z, 0.0, 8.0 * delta)

	match state:
		State.IDLE, State.TO_SWEEP, State.SWEEPING:
			# Kirli masa her şeyden önce gelir.
			var table := shop.claim_dirty_table(self)
			if not table.is_empty():
				_dust.emitting = false
				_go_to_table(table)
			elif state == State.SWEEPING:
				_timer -= delta
				if _timer <= 0.0:
					_dust.emitting = false
					_go_sweep()
			elif state == State.IDLE:
				_go_sweep()
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
	_set_icon("circle-alert", UiKit.ORANGE)
	var pos: Vector3 = table["pos"]
	# Masanın önünde, koridor tarafında durup siler.
	var spot := Vector3(pos.x - signf(pos.x) * 0.3, 0, pos.z + Shop.LANE_OFFSET)
	_follow(Shop.corridor_path(position, spot), PI)


func _go_sweep() -> void:
	state = State.TO_SWEEP
	_set_icon("", Color.WHITE)
	var target: Vector3 = SWEEP_POINTS.pick_random()
	while target.distance_to(position) < 0.5:
		target = SWEEP_POINTS.pick_random()
	_follow(Shop.corridor_path(position, target), randf_range(-PI, PI))


func _finish_cleaning() -> void:
	for arm in _body.arms:
		arm.rotation.z = 0.0
	_carry = shop.collect_tray(_table)
	_table = {}
	if _carry:
		_carry.reparent(_body)
		_carry.rotation = Vector3.ZERO
		_carry.position = Vector3(0, 0.92, 0.42)
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
			_set_icon("spray-can", UiKit.BLUE)
		State.TO_SWEEP:
			state = State.SWEEPING
			_timer = randf_range(3.0, 5.0)
			_set_icon("brush", UiKit.GREEN)
			_dust.emitting = true
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


## Masayı silerken kollar ileri uzanıp yana sallanır.
func _animate_wiping() -> void:
	for i in _body.arms.size():
		_body.arms[i].rotation.x = deg_to_rad(-75.0)
		_body.arms[i].rotation.z = sin(_t * 12.0 + i * PI) * 0.35


## Süpürürken kollar önde, süpürge sağa sola gider.
func _animate_sweeping() -> void:
	for arm in _body.arms:
		arm.rotation.x = deg_to_rad(-45.0)
	_broom.rotation.z = sin(_t * 7.0) * 0.45
	_body.rotation.y += sin(_t * 7.0) * 0.004


func _build_broom() -> void:
	_broom = Node3D.new()
	_broom.position = Vector3(0, 0.95, 0.38)
	_body.add_child(_broom)
	var stick := Util.cylinder(0.018, 1.0, Color("#b07a48"), Vector3(0, -0.35, 0.1))
	stick.rotation_degrees.x = 25
	_broom.add_child(stick)
	_broom.add_child(Util.box(Vector3(0.3, 0.12, 0.08), Color("#e0b84a"), Vector3(0, -0.85, 0.32)))
	_broom.add_child(Util.box(Vector3(0.32, 0.03, 0.09), Color("#8a5a3a"), Vector3(0, -0.78, 0.31)))

	_dust = CPUParticles3D.new()
	_dust.emitting = false
	_dust.amount = 10
	_dust.lifetime = 0.8
	_dust.position = Vector3(0, -0.9, 0.32)
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
	_body.position.y = absf(sin(_t * 9.0)) * 0.04
	_body.animate_walk(_t, _carry != null)
