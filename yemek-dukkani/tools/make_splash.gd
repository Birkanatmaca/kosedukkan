extends Node

## Telefonun açılış görselini (assets/brand/splash.png) LoadingScreen'in ilk
## karesinden üretir. Yükleme ekranı değişince yeniden çalıştır:
##   Godot --path yemek-dukkani res://tools/make_splash.tscn
## (pencereli çalışmalı; headless modda çizim yapılmaz)

const SIZE := Vector2i(1080, 2340)
const OUT := "res://assets/brand/splash.png"


func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var screen := LoadingScreen.new()
	viewport.add_child(screen)
	screen.size = Vector2(SIZE)
	screen.progress = 0.12
	for i in 4:
		await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	image.save_png(ProjectSettings.globalize_path(OUT))
	print("splash yazıldı: ", OUT)
	get_tree().quit()
