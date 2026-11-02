class_name FoodStudio
extends Node

## Yiyecek ikonlarını oyundaki 3D modellerden çeker: her ürün için küçük,
## şeffaf arka planlı bir sahne bir kez çizilir. Meshy modelleri gelince
## ikonlar da kendiliğinden onlara dönüşür.

const SIZE := 160


func _ready() -> void:
	for id in Items.PRODUCTS:
		Icons.register_food(id, _render(id))


func _render(id: String) -> Texture2D:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 35, 0)
	light.light_energy = 1.3
	viewport.add_child(light)

	var color := Items.cook_color(id, 1.0) if Items.COLORS.has(id) else Color.WHITE
	var model := Items.model(id, Util.material(color))
	viewport.add_child(model)

	# Ürünü kadraja sığdıran kamera
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.3 if id != "kola" else 0.26
	viewport.add_child(camera)
	var focus := Vector3(0, 0.09 if id == "kola" else 0.05, 0)
	camera.global_transform = Transform3D(Basis(), focus + Vector3(0.0, 0.45, 0.6)).looking_at(focus, Vector3.UP)
	# Ürünü hafif çapraz göster
	model.rotation_degrees.y = 30.0
	camera.current = true
	return viewport.get_texture()
