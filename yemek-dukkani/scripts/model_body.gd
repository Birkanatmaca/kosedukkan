class_name ModelBody
extends PersonBody

## Meshy'den gelen rig'li karakter. PersonBody ile aynı arayüzü kullanır;
## kol/bacak sallamak yerine modelin kendi animasyonlarını oynatır.
## Yüz mimikleri Blender'da eklenen shape key'lerle yapılır: ruh haline göre
## kaş ve ağız değişir, arada göz kırpar, kızgınken söylenir gibi ağzını oynatır.
## Her kopyanın teni, saçı ve kıyafeti CharacterSkin ile farklı boyanır.
## Temizlikçi gibi iş yapan karakterler play_action ile iş animasyonu oynatır,
## hold ile eline eşya (süpürge, bez, sünger) alır.

## Animasyon görevleri: görev -> Meshy/Mixamo animasyon adında geçen parça.
## Adsız animasyonlar kimliklerinin başıyla bulunur.
const CUSTOMER_ANIMS := { "walk": "Walking", "angry": "Stand_Talking_Angry", "sit": "01a1a095" }

## Karakterler. scale: modeller 1.70 m geliyor, biraz uzun görünsünler.
## sit_hips: oturma animasyonunda kalçanın yerden yüksekliği (ölçeksiz).
## refs: dokudaki bölgelerin ortalama rengi (CharacterSkin yeniden boyarken kullanır).
## frozen_idle: bekleme animasyonu yoksa yürümenin ilk karesinde durur.
const CHARACTERS := {
	"erkek": {
		"model": "res://assets/models/characters/erkek.glb",
		"mask": "res://assets/models/characters/erkek_maske.png",
		"anims": { "idle": "Talk_with_Hands_Open" }, "scale": 1.1, "sit_hips": 0.59,
		"refs": { "skin": Color("#eb9464"), "hair": Color("#2d2024"), "top": Color("#af4721"), "pants": Color("#3c699b") },
	},
	"kadin": {
		"model": "res://assets/models/characters/kadin.glb",
		"mask": "res://assets/models/characters/kadin_maske.png",
		"anims": { "idle": "Talk_Passionately" }, "scale": 1.06, "sit_hips": 0.62,
		"refs": { "skin": Color("#eda076"), "hair": Color("#342425"), "top": Color("#dc9c13"), "pants": Color("#2767ad") },
	},
	"temizlikci_erkek": {
		"model": "res://assets/models/characters/temizlikci_erkek.glb",
		"mask": "res://assets/models/characters/temizlikci_erkek_maske.png",
		"mask2": "res://assets/models/characters/temizlikci_erkek_maske_2.png",
		"anims": { "walk": "Walking", "idle": "Walking", "sweep": "01a1a125", "wipe": "01a1a138", "window": "01a1a13a" },
		"frozen_idle": true, "scale": 1.08, "sit_hips": 0.6,
		"refs": {
			"skin": Color("#de8f63"), "hair": Color("#29180a"), "top": Color("#72a874"), "pants": Color("#13444b"),
			"apron": Color("#21553b"), "gloves": Color("#45a6d3"),
		},
	},
	"temizlikci_kadin": {
		"model": "res://assets/models/characters/temizlikci_kadin.glb",
		"mask": "res://assets/models/characters/temizlikci_kadin_maske.png",
		"mask2": "res://assets/models/characters/temizlikci_kadin_maske_2.png",
		"anims": { "walk": "Walking", "idle": "Walking", "sweep": "01a1a125", "wipe": "01a1a138", "window": "01a1a13a" },
		"frozen_idle": true, "scale": 1.04, "sit_hips": 0.6,
		"refs": {
			"skin": Color("#f59b69"), "hair": Color("#3c281d"), "top": Color("#b2d8aa"), "pants": Color("#184041"),
			"apron": Color("#2c5d38"), "gloves": Color("#60abcd"),
		},
	},
	# Kurye: kendi kıyafetiyle (maskesiz, yeniden boyanmaz); dükkanda beklerken telefonuyla konuşur.
	"kurye": {
		"model": "res://assets/models/characters/kurye.glb",
		"anims": { "walk": "Walking", "idle": "Phone_Conversation", "run": "Running" },
		"scale": 1.06, "sit_hips": 0.6,
	},
}
const BLEND := 0.25

## Ruh haline göre yüz: shape key -> değer (verilmeyenler 0)
const FACES := {
	Mood.HAPPY: {},
	Mood.NEUTRAL: { "mouth_close": 0.8 },
	Mood.ANGRY: { "brow_angry": 1.0, "mouth_close": 0.8, "mouth_frown": 1.0 },
}
const FACE_KEYS := ["blink", "brow_angry", "brow_up", "mouth_close", "mouth_frown", "mouth_open"]
const BLINK_TIME := 0.14
## Taşınan tepsinin yeri: CarryPose'daki ellerin hemen üstü
const CARRY_OFFSET := Vector3(0, 0.97, 0.33)

var _player: AnimationPlayer
var _model: Node3D
var _sitting := false
var _anims := {}
var _face: MeshInstance3D
## shape key adı -> indeks
var _keys := {}
var _blink_wait := randf_range(1.0, 4.0)
var _t := randf() * 10.0
var _carry: CarryPose
var _carrying := false
var _info: Dictionary
var _skeleton: Skeleton3D
var _materials: Array[ShaderMaterial] = []
var _held := {}


## `character`: CHARACTERS anahtarı, `look`: CharacterSkin.random_look() gibi bir görünüm.
func build_model(character: String, look: Dictionary) -> void:
	_info = CHARACTERS[character]
	_model = (load(_info["model"]) as PackedScene).instantiate()
	_model.scale = Vector3.ONE * _info["scale"]
	add_child(_model)
	_player = _model.find_children("*", "AnimationPlayer", true, false)[0]
	var roles: Dictionary = CUSTOMER_ANIMS.duplicate()
	roles.merge(_info["anims"], true)
	for role in roles:
		for anim_name in _player.get_animation_list():
			if roles[role] in anim_name:
				_anims[role] = anim_name
				_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
				break
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		if _info.has("mask"):
			var mat := CharacterSkin.material(mesh.get_active_material(0), _info["mask"], _info["refs"], look, _info.get("mask2", ""))
			mesh.material_override = mat
			_materials.append(mat)
		if mesh.mesh and mesh.mesh.get_blend_shape_count() > 0:
			_face = mesh
			for key in FACE_KEYS:
				var index := mesh.find_blend_shape_by_name(key)
				if index >= 0:
					_keys[key] = index
	# Tepsi taşırken kollar animasyonun üstüne bu duruşla yazılır.
	_carry = CarryPose.new()
	_carry.body = self
	_carry.influence = 0.0
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	_skeleton.add_child(_carry)
	carry_offset = CARRY_OFFSET * _info["scale"]
	head_top = 2.0 * _info["scale"]
	mood = Mood.HAPPY
	_play("idle")


## İş animasyonu: "sweep" (yer), "wipe" (masa), "window" (cam).
func play_action(role: String) -> void:
	_carrying = false
	_play(role)


## Eşyayı bir ele bağlar; bir elde birden çok eşya durabilir, hangisinin
## görüneceğini çağıran seçer. hand: "Left" ya da "Right".
## Eşyanın konumu ve dönüşü el kemiğine göredir.
func hold(item: Node3D, hand: String) -> void:
	if not _held.has(hand):
		var attach := BoneAttachment3D.new()
		attach.bone_name = "mixamorig_%sHand" % hand
		_skeleton.add_child(attach)
		_held[hand] = attach
	_held[hand].add_child(item)


## El kemiğinin dünyadaki yeri.
func hand_position(hand: String) -> Vector3:
	var bone := _skeleton.find_bone("mixamorig_%sHand" % hand)
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(bone).origin


## Önlük ve eldiven rengi (temizlikçi; dükkan boyasına uyar).
func set_uniform(apron: Color, gloves: Color) -> void:
	for mat in _materials:
		CharacterSkin.set_uniform(mat, apron, gloves)


func _process(delta: float) -> void:
	_carry.influence = move_toward(_carry.influence, 1.0 if _carrying else 0.0, 5.0 * delta)
	if not _face:
		return
	_t += delta
	var target: Dictionary = FACES.get(mood, {}).duplicate()
	# Kızgın ve ayaktayken söylenir: ağız açılıp kapanır.
	if mood == Mood.ANGRY and not _sitting:
		var talk := absf(sin(_t * 7.0))
		target["mouth_open"] = talk * 0.6
		target["mouth_close"] = 0.8 - talk * 0.6
	_blink_wait -= delta
	if _blink_wait <= 0.0:
		target["blink"] = 1.0
		if _blink_wait < -BLINK_TIME:
			_blink_wait = randf_range(2.0, 5.0)
	for key in _keys:
		var index: int = _keys[key]
		var speed := 40.0 if key == "blink" else 8.0
		var value := lerpf(_face.get_blend_shape_value(index), target.get(key, 0.0), minf(1.0, speed * delta))
		_face.set_blend_shape_value(index, value)


func set_mood(new_mood: int) -> void:
	mood = new_mood


func animate_walk(_t: float, carrying: bool) -> void:
	_carrying = carrying
	_play("walk")


## Koşar (kurye paketleri götürürken / acele ederken).
func animate_run(carrying: bool) -> void:
	_carrying = carrying
	_play("run" if _anims.has("run") else "walk")


func relax(_delta: float, carrying: bool, sitting: bool) -> void:
	_carrying = carrying and not sitting
	if sitting:
		_play("sit")
	else:
		_play("angry" if mood == Mood.ANGRY and _anims.has("angry") else "idle")


## Oturma pozu sandalye yüksekliğine göre; müşterinin oturunca gövdeyi
## indirmesini (base_y) burada geri alırız.
func set_sitting(sitting: bool) -> void:
	_sitting = sitting
	# Uzun model oturunca kalçası sandalyenin üstünde kalmasın diye indirilir.
	_model.position.y = 0.1 + (0.59 - _info["sit_hips"] * _info["scale"]) if sitting else 0.0
	if sitting:
		_carrying = false
		_play("sit")


func _play(role: String) -> void:
	var anim_name: String = _anims.get(role, "")
	if anim_name == "":
		return
	# Bekleme animasyonu olmayan karakter yürümenin ilk karesinde durur.
	var frozen: bool = role == "idle" and _info.get("frozen_idle", false)
	if _player.assigned_animation == anim_name and _player.is_playing() != frozen:
		return
	_player.play(anim_name, BLEND)
	if frozen:
		_player.seek(0.0, true)
		_player.pause()
