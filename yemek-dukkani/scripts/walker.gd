class_name Walker
extends Node3D

## Mahallede yürüyen oyuncu karakteri (dükkan sahibi): dokunulan yere yürür.
## Başının üstünde "Sen" yazar; kırmızı tişörtlü, hep aynı görünür.

signal arrived

const SPEED := 3.4
const LOOK := { "skin": Color("#e9a27a"), "hair": Color("#2d2024"), "top": Color("#d6452f"), "pants": Color("#2f4f7a") }

var _path: Array[Vector3] = []
var _body: ModelBody
var _t := 0.0
var _face := PI


func _ready() -> void:
	_body = ModelBody.new()
	add_child(_body)
	_body.build_model("erkek", LOOK)
	var tag := Util.label3d("Sen", 64, Color.WHITE, Vector3(0, _body.head_top + 0.15, 0))
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.outline_size = 16
	tag.outline_modulate = Color("#d6452f")
	add_child(tag)


func walking() -> bool:
	return not _path.is_empty()


## Noktaları sırayla yürür; bitince arrived yayınlanır ve face yönüne döner.
func walk(path: Array, face := PI) -> void:
	_path.clear()
	for p in path:
		_path.append(p)
	_face = face


func _process(delta: float) -> void:
	_t += delta
	if _path.is_empty():
		_body.rotation.y = lerp_angle(_body.rotation.y, _face, 8.0 * delta)
		_body.relax(delta, false, false)
		return
	var target := _path[0]
	var to := target - position
	to.y = 0.0
	var dist := to.length()
	if dist <= SPEED * delta:
		position = Vector3(target.x, position.y, target.z)
		_path.pop_front()
		if _path.is_empty():
			arrived.emit()
		return
	position += to / dist * SPEED * delta
	_body.rotation.y = lerp_angle(_body.rotation.y, atan2(to.x, to.z), 10.0 * delta)
	_body.animate_walk(_t, false)
