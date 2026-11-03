class_name CharacterSkin
extends RefCounted

## Karakter dokusunu bölge bölge yeniden boyar: ten, saç, üst, pantolon; temizlikçide
## ayrıca önlük ve eldiven (ikinci maske). Hangi pikselin hangi bölge olduğunu
## Blender'da çıkarılan maske söyler (tools/blender/color_mask.py).
## Gölge ve ayrıntı korunur; sadece renk değişir.

const SHADER := """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D mask_tex : filter_linear_mipmap;
uniform sampler2D mask2_tex : hint_default_black, filter_linear_mipmap;
uniform vec3 skin_ref : source_color;
uniform vec3 hair_ref : source_color;
uniform vec3 top_ref : source_color;
uniform vec3 pants_ref : source_color;
uniform vec3 skin_color : source_color;
uniform vec3 hair_color : source_color;
uniform vec3 top_color : source_color;
uniform vec3 pants_color : source_color;
uniform vec3 apron_ref : source_color;
uniform vec3 gloves_ref : source_color;
uniform vec3 apron_color : source_color;
uniform vec3 gloves_color : source_color;

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// Bölgenin ortalama rengine göre parlaklığı koruyarak yeni renge boyar.
vec3 recolor(vec3 c, vec3 ref, vec3 target) {
	return target * clamp(lum(c) / max(lum(ref), 0.001), 0.0, 1.6);
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	vec4 m = texture(mask_tex, UV);
	c = mix(c, recolor(c, skin_ref, skin_color), m.r);
	c = mix(c, recolor(c, hair_ref, hair_color), m.g);
	c = mix(c, recolor(c, top_ref, top_color), m.b);
	c = mix(c, recolor(c, pants_ref, pants_color), m.a);
	vec4 m2 = texture(mask2_tex, UV);
	c = mix(c, recolor(c, apron_ref, apron_color), m2.r);
	c = mix(c, recolor(c, gloves_ref, gloves_color), m2.g);
	ALBEDO = c;
	ROUGHNESS = 0.75;
}
"""

const SKINS := [Color("#f6d5bf"), Color("#efc09e"), Color("#e2a27a"), Color("#c3855c"), Color("#9a6440"), Color("#6f4630")]
const HAIRS := [Color("#1b1716"), Color("#2b1d16"), Color("#5a3a22"), Color("#8a4b2a"), Color("#c99a4e"), Color("#8d8a86")]
const TOPS := [
	Color("#c8502a"), Color("#d94848"), Color("#3f7fd0"), Color("#4fa65a"), Color("#8a5cc4"),
	Color("#d9a032"), Color("#2fa39b"), Color("#2f3b52"), Color("#6b6f78"), Color("#e07aa0"),
]
const PANTS := [Color("#3c699b"), Color("#2c3242"), Color("#24262b"), Color("#6b5a45"), Color("#8a7d62"), Color("#4a5a3a")]

static var _shader: Shader


## Rastgele bir görünüm: { "skin", "hair", "top", "pants" }
static func random_look() -> Dictionary:
	return { "skin": SKINS.pick_random(), "hair": HAIRS.pick_random(), "top": TOPS.pick_random(), "pants": PANTS.pick_random() }


## Kayda yazılabilir hali (renkler html metni).
static func look_to_save(look: Dictionary) -> Dictionary:
	var out := {}
	for key in look:
		out[key] = (look[key] as Color).to_html(false)
	return out


static func look_from_save(saved: Dictionary) -> Dictionary:
	var out := {}
	for key in saved:
		out[key] = Color.html(str(saved[key]))
	return out


## Önlük ve eldiven rengini sonradan değiştirir (dükkanın boyası değişince).
static func set_uniform(mat: ShaderMaterial, apron: Color, gloves: Color) -> void:
	mat.set_shader_parameter("apron_color", apron)
	mat.set_shader_parameter("gloves_color", gloves)


## Modelin dokusunu alıp verilen görünümle boyayan materyal.
## `refs`: dokudaki her bölgenin ortalama rengi (karaktere göre değişir).
## `mask2_path`: varsa önlük/eldiven maskesi; renkleri başta dokudaki gibi kalır.
static func material(source: Material, mask_path: String, refs: Dictionary, look: Dictionary, mask2_path := "") -> ShaderMaterial:
	if not _shader:
		_shader = Shader.new()
		_shader.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("albedo_tex", (source as StandardMaterial3D).albedo_texture)
	mat.set_shader_parameter("mask_tex", load(mask_path))
	if mask2_path != "":
		mat.set_shader_parameter("mask2_tex", load(mask2_path))
	for key in refs:
		mat.set_shader_parameter("%s_ref" % key, refs[key])
		mat.set_shader_parameter("%s_color" % key, look.get(key, refs[key]))
	return mat
