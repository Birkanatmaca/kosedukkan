class_name PortraitStudio
extends Node

## Personel kartlarındaki yüz portreleri: kişinin kendi görünümüyle (ten, saç,
## gömlek; önlük dükkan renginde) 3D modelinden baş ve omuz çekilir.
## Her kişi için bir kez çizilir ve saklanır.

const SIZE := 192

## kişi anahtarı -> doku
var _cache := {}


func portrait(person: Dictionary) -> Texture2D:
	# Eski kayıtlardaki adaylarda görünüm yok: şimdi verilir, işe alınınca da aynı kalır.
	if not person.has("look"):
		person["look"] = CharacterSkin.look_to_save(CharacterSkin.random_look())
	var look: Dictionary = person["look"]
	var key := "%s|%s|%s" % [person["name"], str(look), str(Decor.uniform_colors(GameState.decor))]
	if not _cache.has(key):
		_cache[key] = _render(person)
	return _cache[key]


func _render(person: Dictionary) -> Texture2D:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25, 30, 0)
	light.light_energy = 1.1
	viewport.add_child(light)

	var body := ModelBody.new()
	viewport.add_child(body)
	body.build_model(person.get("model", Staff.WORKER_MODELS["erkek"]), CharacterSkin.look_from_save(person["look"]))
	var colors := Decor.uniform_colors(GameState.decor)
	body.set_uniform(colors[0], colors[1])
	body.rotation_degrees.y = 18.0

	# Baş ve omuzlar kadrajda
	var head := body.head_top * 0.66
	var camera := Camera3D.new()
	camera.fov = 26.0
	viewport.add_child(camera)
	camera.global_transform = Transform3D(Basis(), Vector3(0.0, head + 0.08, 1.4)).looking_at(Vector3(0, head - 0.02, 0), Vector3.UP)
	camera.current = true
	# Duruş oturana kadar birkaç kare çiz, sonra dondur (sonraki karelerde maliyet yok).
	# (Sahne bu arada yeniden kurulduysa — dükkan değişimi — görüntü alanı silinmiş olabilir.)
	var ref: WeakRef = weakref(viewport)
	get_tree().create_timer(0.25).timeout.connect(func() -> void:
		var vp: SubViewport = ref.get_ref()
		if vp:
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	)
	return viewport.get_texture()
