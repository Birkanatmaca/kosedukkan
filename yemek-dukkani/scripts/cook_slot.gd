class_name CookSlot
extends Node3D

## Izgara ya da fritözdeki tek bir pişirme yeri. Ürünün rengi pişme
## oranına göre çiğden yanığa doğru değişir; üstünden buhar / duman çıkar.

signal tapped(slot: CookSlot)
## Dokunulan nokta da bildirilir: mutfak oraya en yakın ürünü seçer.
signal tapped_at(slot: CookSlot, point: Vector3)

var device := ""
var product := ""
var elapsed := 0.0
var cook_time := 1.0
## Pişme süresi çarpanı (hız geliştirmesiyle küçülür).
var speed := 1.0

## Tarihi geçmiş malzemeyle mi pişiyor
var spoiled := false
var _mat := StandardMaterial3D.new()
var _model: Node3D
var _smoke: CPUParticles3D


func _ready() -> void:
	_mat.roughness = 0.55
	# Yassı dokunma alanı: eğik bakan kamerada öndeki yer arkadakinin önünü kesmesin.
	var body := Util.collider_box(self, Vector3(0.48, 0.07, 0.3), Vector3(0, 0.03, 0))
	body.set_meta("tap_at", func(point: Vector3) -> void: tapped_at.emit(self, point))
	_build_smoke()


func is_empty() -> bool:
	return product == ""


func doneness() -> float:
	return 0.0 if is_empty() else elapsed / cook_time


## is_spoiled: tarihi geçmiş malzeme (yeşilimsi pişer, müşteriyi hasta eder)
func start(id: String, is_spoiled := false) -> void:
	product = id
	spoiled = is_spoiled
	elapsed = 0.0
	cook_time = float(Items.PRODUCTS[id]["cook_time"]) * speed
	Sfx.play("sizzle_start" if device == "izgara" else "fryer_drop", 0.1)
	_model = Items.model(id, _mat)
	add_child(_model)
	_model.scale = Vector3.ONE * 0.01
	_model.create_tween().tween_property(_model, "scale", Vector3.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_update_look()


## Fırında ürün kürek yerine varana kadar görünmez.
func hide_item(hidden: bool) -> void:
	if _model:
		_model.visible = not hidden


func clear() -> void:
	if _model:
		_model.queue_free()
		_model = null
	product = ""
	spoiled = false
	elapsed = 0.0
	_smoke.emitting = false


func _process(delta: float) -> void:
	if is_empty():
		return
	var before := doneness()
	elapsed = minf(elapsed + delta, cook_time * Items.MAX_DONENESS)
	# Kıvam yeşile girince hafif, yanmaya başlayınca sert titreşim
	var now := doneness()
	if before < Items.UNDER_LIMIT and now >= Items.UNDER_LIMIT:
		Haptics.light()
	elif before < Items.BURNT_LIMIT and now >= Items.BURNT_LIMIT:
		Haptics.warning()
	_update_look()


func _update_look() -> void:
	var d := doneness()
	_mat.albedo_color = Items.cook_color(product, d)
	if spoiled:
		_mat.albedo_color = _mat.albedo_color.lerp(Items.SPOILED_TINT, 0.5)
	_model.position.y = absf(sin(elapsed * 25.0)) * 0.006
	_smoke.emitting = d > 0.15
	_smoke.color = Color(1, 1, 1, 0.45) if d < Items.PERFECT_LIMIT else Color(0.2, 0.2, 0.2, 0.85)


func _build_smoke() -> void:
	_smoke = CPUParticles3D.new()
	_smoke.emitting = false
	_smoke.amount = 10
	_smoke.lifetime = 1.1
	_smoke.position = Vector3(0, 0.08, 0)
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_smoke.emission_sphere_radius = 0.1
	_smoke.direction = Vector3.UP
	_smoke.spread = 15.0
	_smoke.gravity = Vector3(0, 0.4, 0)
	_smoke.initial_velocity_min = 0.15
	_smoke.initial_velocity_max = 0.3
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 1.2

	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.8))
	ramp.set_color(1, Color(1, 1, 1, 0))
	_smoke.color_ramp = ramp

	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	_smoke.mesh = mesh
	add_child(_smoke)
