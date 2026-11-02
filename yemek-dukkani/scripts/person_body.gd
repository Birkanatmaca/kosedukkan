class_name PersonBody
extends Node3D

## Müşteri ve çalışanların ortak gövdesi: kalçadan dönen bacaklar, omuzdan
## dönen kollar ve ruh haline göre değişen yüz (kaşlar ve ağız).

enum Mood { HAPPY, NEUTRAL, ANGRY }

const FACE_Z := 0.2
const BROW_Y := 1.6
const MOUTH_Y := 1.42

## [sol, sağ]
var legs: Array[Node3D] = []
var arms: Array[Node3D] = []
var mood := -1

var _brows: Array[MeshInstance3D] = []
## [sol, orta, sağ]
var _mouth: Array[MeshInstance3D] = []


func build(shirt: Color, skin: Color, hair: Color, pants := Color("#34394a")) -> void:
	for x in [-0.12, 0.12]:
		var hip := Node3D.new()
		hip.position = Vector3(x, 0.6, 0)
		hip.add_child(Util.capsule(0.11, 0.6, pants, Vector3(0, -0.3, 0)))
		add_child(hip)
		legs.append(hip)
	add_child(Util.capsule(0.27, 0.8, shirt, Vector3(0, 0.9, 0)))
	for x in [-0.32, 0.32]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(x, 1.18, 0)
		shoulder.rotation_degrees.z = 8.0 if x > 0 else -8.0
		shoulder.add_child(Util.capsule(0.07, 0.55, shirt, Vector3(0, -0.26, 0)))
		shoulder.add_child(Util.sphere(0.07, skin, Vector3(0, -0.56, 0)))
		add_child(shoulder)
		arms.append(shoulder)

	add_child(Util.sphere(0.21, skin, Vector3(0, 1.5, 0)))
	add_child(Util.sphere(0.215, hair, Vector3(0, 1.56, -0.045)))
	var dark := Color("#1d1d1d")
	for x in [-0.075, 0.075]:
		add_child(Util.sphere(0.028, dark, Vector3(x, 1.52, FACE_Z - 0.01)))
		var brow := Util.box(Vector3(0.07, 0.018, 0.02), hair.darkened(0.3), Vector3(x, BROW_Y, FACE_Z - 0.02))
		add_child(brow)
		_brows.append(brow)
	for x in [-0.045, 0.0, 0.045]:
		var part := Util.box(Vector3(0.045, 0.016, 0.02), Color("#8f3a32"), Vector3(x, MOUTH_Y, FACE_Z))
		add_child(part)
		_mouth.append(part)
	set_mood(Mood.HAPPY)


## Kaş ve ağzı ruh haline göre şekillendirir.
func set_mood(new_mood: int) -> void:
	if new_mood == mood:
		return
	mood = new_mood
	var brow_angle := 0.0
	var brow_y := BROW_Y
	var side_y := MOUTH_Y
	var mid_y := MOUTH_Y
	var mouth_angle := 0.0
	match mood:
		Mood.HAPPY:
			brow_y = BROW_Y + 0.01
			side_y = MOUTH_Y + 0.008
			mid_y = MOUTH_Y - 0.008
			mouth_angle = 25.0
		Mood.ANGRY:
			brow_angle = 22.0
			brow_y = BROW_Y - 0.008
			side_y = MOUTH_Y - 0.008
			mid_y = MOUTH_Y + 0.006
			mouth_angle = -25.0
	# Kaşlar: kızgınken iç uçları aşağı iner.
	_brows[0].rotation_degrees.z = -brow_angle
	_brows[1].rotation_degrees.z = brow_angle
	for brow in _brows:
		brow.position.y = brow_y
	# Ağız: gülerken uçlar yukarı, kızgınken aşağı.
	_mouth[0].position.y = side_y
	_mouth[2].position.y = side_y
	_mouth[1].position.y = mid_y
	_mouth[0].rotation_degrees.z = -mouth_angle
	_mouth[2].rotation_degrees.z = mouth_angle


## Yürürken bacak ve kollar karşılıklı sallanır; bir şey taşıyorsa kollar önde kalır.
func animate_walk(t: float, carrying: bool) -> void:
	var swing := sin(t * 9.0) * 0.5
	legs[0].rotation.x = swing
	legs[1].rotation.x = -swing
	if carrying:
		for arm in arms:
			arm.rotation.x = deg_to_rad(-70.0)
	else:
		arms[0].rotation.x = -swing * 0.8
		arms[1].rotation.x = swing * 0.8


func relax(delta: float, carrying: bool, sitting: bool) -> void:
	var arm_target := deg_to_rad(-70.0) if carrying else 0.0
	for arm in arms:
		arm.rotation.x = lerpf(arm.rotation.x, arm_target, 10.0 * delta)
	if not sitting:
		for leg in legs:
			leg.rotation.x = lerpf(leg.rotation.x, 0.0, 10.0 * delta)


func set_sitting(sitting: bool) -> void:
	for leg in legs:
		leg.rotation_degrees.x = -90.0 if sitting else 0.0
