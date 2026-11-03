class_name Market
extends Node3D

## Market (toptancı) ekranı. 3D sahne sadece dekor; satın alma arayüzden yapılır.

const SHELF_ITEMS := ["tavuk", "tavuk_sis", "kofte", "patates", "kola"]


func _ready() -> void:
	add_child(Util.box(Vector3(12, 0.1, 10), Util.tile_material(Color("#dfe3e6"), Color("#cfd5d9"), 1.0), Vector3(0, -0.05, -1)))
	add_child(Util.box(Vector3(12, 5, 0.2), Color("#d6ecd9"), Vector3(0, 2.5, -2.4)))
	for x in [-6.0, 6.0]:
		add_child(Util.box(Vector3(0.2, 5, 10), Color("#c9e3cd"), Vector3(x, 2.5, -1)))
	add_child(Util.box(Vector3(3.2, 0.7, 0.1), Color("#2f8f5b"), Vector3(0, 3.55, -2.25)))
	add_child(Util.label3d("TOPTANCI", 120, Color.WHITE, Vector3(0, 3.55, -2.19)))

	for unit in 2:
		var ux := -1.15 + unit * 2.3
		for x in [-1.05, 1.05]:
			add_child(Util.box(Vector3(0.07, 2.8, 0.7), Color("#8a5a3a"), Vector3(ux + x, 1.4, -1.9)))
		for row in 3:
			var y := 0.35 + row * 0.95
			add_child(Util.box(Vector3(2.2, 0.06, 0.7), Color("#a8714b"), Vector3(ux, y, -1.9)))
			for c in 3:
				var id: String = SHELF_ITEMS[(unit * 3 + row + c) % SHELF_ITEMS.size()]
				_crate(Vector3(ux - 0.68 + c * 0.68, y + 0.03, -1.9), id)

	var light := OmniLight3D.new()
	light.position = Vector3(0, 3.0, 0.5)
	light.light_color = Color("#fff3dd")
	light.light_energy = 1.2
	light.omni_range = 6.0
	add_child(light)


func _crate(pos: Vector3, id: String) -> void:
	add_child(Util.box(Vector3(0.6, 0.28, 0.5), Color("#c48b55"), pos + Vector3(0, 0.14, 0)))
	add_child(Util.box(Vector3(0.62, 0.04, 0.52), Color("#a8714b"), pos + Vector3(0, 0.2, 0)))
	var mat: Material = Util.material(Items.COLORS[id][0]) if Items.COLORS.has(id) else Util.material(Color.WHITE)
	for i in 3:
		var item := Items.model(id, mat)
		item.position = pos + Vector3(-0.17 + i * 0.17, 0.28, 0.02 * (i % 2))
		item.rotation_degrees.y = i * 50.0
		item.scale = Vector3.ONE * 0.8
		add_child(item)
