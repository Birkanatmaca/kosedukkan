class_name Util
extends RefCounted

## Prototip için basit şekil, materyal, arayüz stili ve efekt yardımcıları.
## Mesh ve materyaller önbelleğe alınır; aynı objeler aynı kaynakları paylaşır.
## Şekil fonksiyonlarındaki `look` bir Color ya da hazır bir Material olabilir.

const TILE_SHADER := """
shader_type spatial;
uniform vec3 color_a : source_color;
uniform vec3 color_b : source_color;
uniform float tile_scale = 1.0;
uniform bool vertical = false;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = (vertical ? world_pos.xy : world_pos.xz) * tile_scale;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec3 col = mix(color_a, color_b, mod(cell.x + cell.y, 2.0));
	float grout = step(0.03, f.x) * step(0.03, f.y);
	ALBEDO = mix(col * 0.85, col, grout);
	ROUGHNESS = 0.6;
}
"""

static var _materials := {}
static var _meshes := {}
static var _scenes := {}
static var _tile_shader: Shader


static func material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.75
		_materials[key] = mat
	return _materials[key]


## Dünya koordinatına göre döşenen kareli zemin / fayans materyali.
static func tile_material(a: Color, b: Color, tile_scale := 1.0, vertical := false) -> ShaderMaterial:
	if _tile_shader == null:
		_tile_shader = Shader.new()
		_tile_shader.code = TILE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _tile_shader
	mat.set_shader_parameter("color_a", a)
	mat.set_shader_parameter("color_b", b)
	mat.set_shader_parameter("tile_scale", tile_scale)
	mat.set_shader_parameter("vertical", vertical)
	return mat


static func box(size: Vector3, look, pos := Vector3.ZERO) -> MeshInstance3D:
	var key := "box:%s" % size
	if not _meshes.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size
		_meshes[key] = mesh
	return _instance(_meshes[key], look, pos)


static func cylinder(radius: float, height: float, look, pos := Vector3.ZERO) -> MeshInstance3D:
	var key := "cyl:%s:%s" % [radius, height]
	if not _meshes.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = height
		mesh.radial_segments = 20
		mesh.rings = 0
		_meshes[key] = mesh
	return _instance(_meshes[key], look, pos)


static func capsule(radius: float, height: float, look, pos := Vector3.ZERO) -> MeshInstance3D:
	var key := "cap:%s:%s" % [radius, height]
	if not _meshes.has(key):
		var mesh := CapsuleMesh.new()
		mesh.radius = radius
		mesh.height = height
		mesh.radial_segments = 20
		mesh.rings = 6
		_meshes[key] = mesh
	return _instance(_meshes[key], look, pos)


static func sphere(radius: float, look, pos := Vector3.ZERO) -> MeshInstance3D:
	var key := "sph:%s" % radius
	if not _meshes.has(key):
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = 20
		mesh.rings = 10
		_meshes[key] = mesh
	return _instance(_meshes[key], look, pos)


static func collider_box(parent: Node3D, size: Vector3, pos := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	body.position = pos
	parent.add_child(body)
	return body


static func label3d(text: String, font_size: int, color: Color, pos := Vector3.ZERO) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.modulate = color
	label.outline_size = 0
	label.pixel_size = 0.004
	label.position = pos
	label.font = UiKit.font(900)
	return label


## Türkçe büyük harf: i → İ, ı → I (to_upper bunu bilmez).
static func upper_tr(text: String) -> String:
	return text.replace("i", "İ").replace("ı", "I").to_upper()


## Label3D yazısının dünya birimindeki genişliği.
static func label_width(label: Label3D) -> float:
	return label.font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x * label.pixel_size


## Yazıyı max_width'e sığdırır: önce yazı boyutunu min_size'a kadar küçültür,
## yine sığmazsa iki satıra böler. Döner: [genişlik, satır sayısı].
static func fit_label(label: Label3D, max_width: float, min_size: int) -> Array:
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var width := label_width(label)
	if width > max_width:
		label.font_size = maxi(min_size, int(label.font_size * max_width / width))
		width = label_width(label)
	if width <= max_width:
		return [width, 1]
	# Tek kelimeyi bölmek çirkin olur: alt sınırı aşıp tek satıra sığdır.
	if not label.text.contains(" "):
		label.font_size = int(label.font_size * max_width / width)
		return [label_width(label), 1]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.width = max_width / label.pixel_size
	return [max_width, 2]


## Yukarı süzülüp kaybolan yazı (+₺14 gibi).
static func float_text(parent: Node, global_pos: Vector3, text: String, color := Color.WHITE) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 90
	label.outline_size = 20
	label.pixel_size = 0.004
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font = UiKit.font(900)
	label.outline_modulate = Color(0.16, 0.11, 0.09)
	parent.add_child(label)
	label.global_position = global_pos
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", global_pos + Vector3(0, 0.7, 0), 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


## Yuvarlak köşeli arayüz kutusu.
static func style(color: Color, radius := 20, margin := 12, shadow := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	if shadow:
		s.shadow_color = Color(0, 0, 0, 0.18)
		s.shadow_size = 10
		s.shadow_offset = Vector2(0, 4)
	return s


## Meshy modelini (assets/models altındaki GLB) yerleştirir. Sahne bir kez yüklenir,
## tüm kopyalar aynı mesh ve dokuyu paylaşır.
static func model(path: String, pos := Vector3.ZERO, yaw := 0.0, scale := 1.0) -> Node3D:
	if not _scenes.has(path):
		_scenes[path] = load("res://assets/models/%s.glb" % path)
	var inst: Node3D = (_scenes[path] as PackedScene).instantiate()
	inst.position = pos
	inst.rotation_degrees.y = yaw
	inst.scale = Vector3.ONE * scale
	return inst


## Gölge düşürmesin (duvar, tavan gibi büyük yüzeyler için).
static func no_shadow(inst: MeshInstance3D) -> MeshInstance3D:
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst


## Modelin tüm mesh'leri (renk ya da doku değiştirmek için).
static func meshes(node: Node) -> Array[Node]:
	return node.find_children("*", "MeshInstance3D", true, false)


static func _instance(mesh: Mesh, look, pos: Vector3) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = look if look is Material else material(look)
	inst.position = pos
	return inst
