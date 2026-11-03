class_name CarryPose
extends SkeletonModifier3D

## Tepsi taşıma duruşu: animasyon ne olursa olsun (yürüme, bekleme) kolları
## öne uzatıp dirsekten büker; eller önde tepsiyi tutar. `influence` ile
## yumuşakça açılıp kapanır.

## Karakter yönünde (+Z ön, +X karakterin solu) kemiklerin bakacağı yönler.
## [kemik, sol kol için yön]; sağ kolda X işareti ters çevrilir.
const CHAIN := [
	["Arm", Vector3(0.18, -0.85, 0.5)],
	["ForeArm", Vector3(-0.35, 0.08, 0.93)],
	["Hand", Vector3(-0.15, 0.0, 1.0)],
]

## Yönler bu düğüme göre (karakterin kendisi)
var body: Node3D
var _bones := []


func _ready() -> void:
	var skeleton := get_skeleton()
	for side in ["Left", "Right"]:
		for link in CHAIN:
			var dir: Vector3 = link[1]
			if side == "Right":
				dir.x = -dir.x
			_bones.append([skeleton.find_bone("mixamorig_%s%s" % [side, link[0]]), dir.normalized()])


func _process_modification() -> void:
	var skeleton := get_skeleton()
	# Karakter yönünü iskelet uzayına çevir (model döndürülmüş olabilir).
	var to_skeleton := (skeleton.global_basis.inverse() * body.global_basis).orthonormalized()
	for bone in _bones:
		var index: int = bone[0]
		if index < 0:
			continue
		var parent_basis := skeleton.get_bone_global_pose(skeleton.get_bone_parent(index)).basis.orthonormalized()
		var current := parent_basis * Basis(skeleton.get_bone_pose_rotation(index))
		var target := (to_skeleton * (bone[1] as Vector3)).normalized()
		var turn := Quaternion(current.y.normalized(), target)
		var wanted := (parent_basis.inverse() * (Basis(turn) * current)).orthonormalized()
		skeleton.set_bone_pose_rotation(index, Quaternion(wanted))
