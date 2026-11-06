class_name Street
extends Node3D

## Dükkanın dışı: arka pencerelerden görünen kaldırım, yol, karşıdaki binalar
## ve geçen arabalar; yan pencerelerden görünen çimenlik ve ağaçlar.
## Hepsi basit şekiller; gölge düşürmezler (telefonda gölge hesabı pahalı).
## Tekrar eden parçalar (bina camları, çit, yol çizgisi, ağaçlar) MultiMesh ile
## tek çizimde toplanır.

## Dükkanın arka duvarının dış yüzü
const WALL_Z := -10.2
## Kaldırımın ortası (müşteriler burada yürür) ve yol şeritleri
const SIDEWALK_Z := -11.4
const ROAD_NEAR := -12.8
const ROAD_FAR := -18.4
const LANES := [-14.2, -17.0]
## Arabalar bu x aralığında görünür, dışında silinir.
const CAR_RANGE := 24.0
const CAR_COLORS := [
	Color("#d94848"), Color("#3f7fd0"), Color("#f2f2f2"), Color("#2b2d33"), Color("#e0a33d"),
	Color("#4fa65a"), Color("#8a8f99"), Color("#2fa39b"), Color("#9b5ad6"),
]
const BUILDING_COLORS := [Color("#e8c9a0"), Color("#c98f6b"), Color("#a9c4c9"), Color("#e6dccb"), Color("#b5846a"), Color("#d9b3b3")]

var _sky: StandardMaterial3D
## Mahalle modunda kamera yakın şeridin üstünden bakar: o şeritten araba geçmez.
var near_lane_clear := false:
	set(value):
		near_lane_clear = value
		if value:
			for car in _cars.duplicate():
				if is_equal_approx(car.position.z, LANES[0]):
					_cars.erase(car)
					car.queue_free()
var _cars: Array[Node3D] = []
var _car_timer := 0.0
## Toplu çizilecek parçalar: grup -> tür -> [[Transform3D, Color], ...]
## Grup 0 sokak, -1 / 1 sol / sağ yan bahçe (genişletme alınınca gizlenir).
var _batches := {}
var _group := 0
var _groups := {}


func _ready() -> void:
	_build_ground()
	_build_buildings()
	_build_trees()
	_build_lamps()
	_flush_batches()
	# Uzakta gökyüzü (vitrinlerin üst kısmından görünür). Market ve mutfak 40 m
	# yanda; oralardan görünmesin diye sadece vitrinlerin gördüğü kadar geniş.
	_sky = StandardMaterial3D.new()
	_sky.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sky.albedo_color = Color("#bfe0f5")
	add_child(_flat(Util.box(Vector3(30, 30, 0.2), _sky, Vector3(0, 12, -34))))
	for i in 3:
		_spawn_car(randf_range(-CAR_RANGE, CAR_RANGE))


func _process(delta: float) -> void:
	_car_timer -= delta
	if _car_timer <= 0.0:
		_car_timer = randf_range(2.0, 5.5)
		_spawn_car()
	for car in _cars.duplicate():
		var speed: float = car.get_meta("speed")
		car.position.x += speed * delta
		for wheel: Node3D in car.get_meta("wheels"):
			wheel.rotation.z -= speed * delta / 0.32
		if absf(car.position.x) > CAR_RANGE + 1.0:
			_cars.erase(car)
			car.queue_free()


## Gün ışığına göre gökyüzü rengi (0 gece, 1 öğlen).
func set_daylight(light: float, tint: Color) -> void:
	_sky.albedo_color = Color("#1a2140").lerp(Color("#bfe0f5") * tint, light)


func _build_ground() -> void:
	var stone := Util.tile_material(Color("#c9c4bb"), Color("#bdb7ad"), 1.4)
	# Kaldırım ve bordür
	add_child(_flat(Util.box(Vector3(60, 0.12, WALL_Z - ROAD_NEAR), stone, Vector3(0, -0.04, (WALL_Z + ROAD_NEAR) / 2))))
	add_child(_flat(Util.box(Vector3(60, 0.16, 0.18), Color("#9a958d"), Vector3(0, 0.02, ROAD_NEAR + 0.09))))
	# Asfalt ve şerit çizgileri
	var road_depth := ROAD_NEAR - ROAD_FAR
	add_child(_flat(Util.box(Vector3(60, 0.1, road_depth), Color("#3b3d42"), Vector3(0, -0.06, (ROAD_NEAR + ROAD_FAR) / 2))))
	for i in 15:
		_add("box", Vector3(1.6, 0.02, 0.14), Color("#f2efe6"), Vector3(-28 + i * 4.0, 0.0, (ROAD_NEAR + ROAD_FAR) / 2))
	# Karşı kaldırım
	add_child(_flat(Util.box(Vector3(60, 0.12, 2.0), stone, Vector3(0, -0.04, ROAD_FAR - 1.0))))
	# Yanlardaki çimenlik (yan pencerelerden görünür)
	var grass := Util.tile_material(Color("#7fb366"), Color("#76ab5e"), 0.6)
	for side in [-1.0, 1.0]:
		add_child(_flat(Util.box(Vector3(14, 0.1, 16), grass, Vector3(side * 13.2, -0.06, -2.6))))
		# Alçak çit
		_group = int(side)
		for z in range(-10, 6, 1):
			_add("box", Vector3(0.08, 0.7, 0.08), Color("#f4efe6"), Vector3(side * 8.6, 0.35, z))
		for y in [0.25, 0.55]:
			_add("box", Vector3(0.05, 0.08, 16), Color("#f4efe6"), Vector3(side * 8.6, y, -2.0))
		_group = 0


func _build_buildings() -> void:
	var x := -30.0
	var i := 0
	while x < 30.0:
		var width := randf_range(4.5, 7.5)
		var height := randf_range(5.5, 10.0)
		var color: Color = BUILDING_COLORS[i % BUILDING_COLORS.size()]
		var center := Vector3(x + width / 2, height / 2, ROAD_FAR - 2.0 - 2.0)
		add_child(_flat(Util.box(Vector3(width - 0.1, height, 4.0), color, center)))
		# Pencereler (iki sıra ve üstü)
		var front_z := center.z + 2.01
		var floors := int((height - 3.0) / 2.2)
		for f in floors:
			var cols := int(width / 1.6)
			for c in cols:
				var wx := x + (c + 0.5) * width / cols
				_add("box", Vector3(0.8, 1.1, 0.05), Color("#5b7489"), Vector3(wx, 3.6 + f * 2.2, front_z))
		# Zemin katta dükkan vitrini ve tente
		_add("box", Vector3(width * 0.6, 1.6, 0.05), Color("#6e8ea3"), Vector3(center.x, 1.2, front_z))
		var awning := _flat(Util.box(Vector3(width * 0.7, 0.08, 0.9), CAR_COLORS[(i * 3) % CAR_COLORS.size()], Vector3(center.x, 2.3, front_z + 0.4)))
		awning.rotation_degrees.x = -12
		add_child(awning)
		x += width
		i += 1


func _build_trees() -> void:
	# Kaldırım ağaçları (arka pencerelerden) ve yan bahçedeki ağaçlar
	for x in [-8.5, 8.5, -21.2, 21.2]:
		_tree(Vector3(x, 0, -12.1), 1.0)
	for side in [-1.0, 1.0]:
		_group = int(side)
		for pos in [Vector3(7.6, 0, -8.2), Vector3(9.8, 0, -5.0), Vector3(7.4, 0, -3.4), Vector3(10.5, 0, -1.0), Vector3(8.0, 0, 1.6), Vector3(12.5, 0, -7.0)]:
			_tree(Vector3(pos.x * side, 0, pos.z), randf_range(0.85, 1.25))
		for pos in [Vector3(6.8, 0, -6.0), Vector3(6.9, 0, -1.6), Vector3(7.0, 0, -9.2)]:
			_add("sphere", Vector3(1.17, 0.72, 0.9), Color("#5c9a4a"), Vector3(pos.x * side, 0.3, pos.z))
	_group = 0


func _tree(pos: Vector3, size: float) -> void:
	var basis := Basis(Vector3.UP, randf_range(0, TAU)).scaled(Vector3.ONE * size)
	var tree := Transform3D(basis, pos)
	_add("cylinder", Vector3.ONE, Color("#7a5a3a"), Vector3.ZERO)
	_batches[_group]["cylinder"][-1][0] = tree * Transform3D(Basis.from_scale(Vector3(0.28, 2.2, 0.28)), Vector3(0, 1.1, 0))
	var greens := [Color("#4f8f3f"), Color("#5fa04a"), Color("#6aab52")]
	for leaf in [[Vector3(0, 2.6, 0), 1.0], [Vector3(0.45, 2.3, 0.2), 0.75], [Vector3(-0.4, 2.4, -0.25), 0.8], [Vector3(0.1, 3.2, -0.1), 0.7]]:
		var r: float = leaf[1] * 2.0
		_add("sphere", Vector3.ONE, greens.pick_random(), Vector3.ZERO)
		_batches[_group]["sphere"][-1][0] = tree * Transform3D(Basis.from_scale(Vector3(r, r, r)), leaf[0])


func _build_lamps() -> void:
	for x in [-5.0, 5.0, -13.0, 13.0]:
		_add("cylinder", Vector3(0.12, 3.6, 0.12), Color("#3a3f47"), Vector3(x, 1.8, ROAD_NEAR + 0.5))
		_add("box", Vector3(0.12, 0.08, 0.7), Color("#3a3f47"), Vector3(x, 3.6, ROAD_NEAR + 0.75))
		_add("sphere", Vector3(0.26, 0.26, 0.26), Color("#ffe6a8"), Vector3(x, 3.5, ROAD_NEAR + 1.0))


## Basit araba: gövde, kabin, camlar, tekerlekler, farlar. Yöne göre döner.
func _spawn_car(start_x := INF) -> void:
	var lane := 1 if near_lane_clear else randi() % LANES.size()
	var dir := 1.0 if lane == 0 else -1.0
	var car := Node3D.new()
	car.position = Vector3(-dir * CAR_RANGE if start_x == INF else start_x, 0, LANES[lane])
	car.rotation_degrees.y = 0.0 if dir > 0 else 180.0
	var color: Color = CAR_COLORS.pick_random()
	var length := randf_range(3.6, 4.4)
	car.add_child(_flat(Util.box(Vector3(length, 0.55, 1.7), color, Vector3(0, 0.55, 0))))
	car.add_child(_flat(Util.box(Vector3(length * 0.55, 0.5, 1.5), color, Vector3(-length * 0.05, 1.07, 0))))
	car.add_child(_flat(Util.box(Vector3(length * 0.5, 0.38, 1.52), Color("#2a3440"), Vector3(-length * 0.05, 1.07, 0))))
	for z in [-0.86, 0.86]:
		car.add_child(_flat(Util.box(Vector3(0.12, 0.1, 0.02), Color("#fff3c4"), Vector3(length / 2, 0.62, z * 0.8))))
	var wheels: Array[Node3D] = []
	for wx in [-length * 0.32, length * 0.32]:
		for wz in [-0.82, 0.82]:
			var wheel := _flat(Util.cylinder(0.32, 0.22, Color("#1d1f23"), Vector3(wx, 0.32, wz)))
			wheel.rotation_degrees.x = 90
			var pivot := Node3D.new()
			pivot.position = Vector3(wx, 0.32, wz)
			wheel.position = Vector3.ZERO
			pivot.add_child(wheel)
			car.add_child(pivot)
			wheels.append(pivot)
	car.set_meta("speed", dir * randf_range(4.5, 8.0))
	car.set_meta("wheels", wheels)
	add_child(car)
	_cars.append(car)
	if start_x == INF and randf() < 0.12:
		Sfx.play("car_pass", 0.15, Main.SHOP)


func _flat(inst: MeshInstance3D) -> MeshInstance3D:
	return Util.no_shadow(inst)


## Toplu çizim için bir parça ekler (birim mesh, boyut ve renk).
func _add(kind: String, size: Vector3, color: Color, pos: Vector3) -> void:
	if not _batches.has(_group):
		_batches[_group] = { "box": [], "sphere": [], "cylinder": [] }
	_batches[_group][kind].append([Transform3D(Basis.from_scale(size), pos), color])


## Biriken parçaları türüne göre birer MultiMesh olarak çizer (renk kopya başına).
func _flush_batches() -> void:
	var meshes := { "box": BoxMesh.new(), "sphere": SphereMesh.new(), "cylinder": CylinderMesh.new() }
	(meshes["sphere"] as SphereMesh).radius = 0.5
	(meshes["sphere"] as SphereMesh).height = 1.0
	(meshes["sphere"] as SphereMesh).radial_segments = 12
	(meshes["sphere"] as SphereMesh).rings = 6
	(meshes["cylinder"] as CylinderMesh).top_radius = 0.5
	(meshes["cylinder"] as CylinderMesh).bottom_radius = 0.5
	(meshes["cylinder"] as CylinderMesh).height = 1.0
	(meshes["cylinder"] as CylinderMesh).radial_segments = 8
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.8
	for group in _batches:
		var parent := Node3D.new()
		add_child(parent)
		_groups[group] = parent
		for kind in _batches[group]:
			_flush_kind(parent, meshes[kind], mat, _batches[group][kind])
	_batches.clear()


## Yan bahçenin ağaç ve çitlerini gizler (o tarafa genişletme yapıldı).
func set_side_open(side: int, open: bool) -> void:
	if _groups.has(side):
		(_groups[side] as Node3D).visible = not open


func _flush_kind(parent: Node3D, mesh: Mesh, mat: Material, items: Array) -> void:
	if items.is_empty():
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = items.size()
	for i in items.size():
		multi.set_instance_transform(i, items[i][0])
		multi.set_instance_color(i, items[i][1])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = multi
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)
