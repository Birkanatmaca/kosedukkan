class_name AccountLink
extends RefCounted

## Hesap bağlama ve bulut kayıt.
##
## Akış:
##   1. Oyuncu misafir başlar; ilerleme telefonda (SaveSystem) tutulur.
##   2. Ayarlar'dan "Google ile Bağla" / "Apple ile Bağla": telefonun kendi giriş
##      ekranı açılır, hesap kimliği alınır ve kayıt buluta yüklenir.
##   3. Yeni telefonda aynı hesapla giriş yapılınca buluttaki kayıt bulunur ve
##      "Eski dükkanın yüklensin mi?" diye sorulur.
##
## Gerçek giriş için mağaza sürümünde iki parça gerekir:
##   - Telefon tarafı: Android'de Google ile Giriş, iOS'ta Apple ile Giriş
##     eklentisi (Godot Android/iOS plugin). Eklenti yüklüyse NATIVE_SINGLETONS
##     içindeki isimle bulunur.
##   - Sunucu tarafı: kimliği doğrulayıp kaydı saklayan bir servis (ör. Firebase
##     Authentication + Firestore). Adresi BACKEND_URL'e yazılır.
## İkisi de yokken butonlar ne gerektiğini açıklayan bir mesaj gösterir.

const PROVIDERS := {
	"google": { "name": "Google", "platform": "Android" },
	"apple": { "name": "Apple", "platform": "iOS" },
}
const NATIVE_SINGLETONS := {
	"google": "GodotGoogleSignIn",
	"apple": "GodotAppleSignIn",
}
## Bulut kayıt servisinin adresi (kurulunca doldurulacak).
const BACKEND_URL := ""


static func account() -> Dictionary:
	return Saves.settings.get("account", {})


static func is_linked() -> bool:
	return not account().is_empty()


static func provider_name(provider: String) -> String:
	return PROVIDERS[provider]["name"]


## Bu cihazda bu sağlayıcıyla giriş yapılabiliyor mu?
static func available(provider: String) -> bool:
	return BACKEND_URL != "" and Engine.has_singleton(NATIVE_SINGLETONS[provider])


## Neden kullanılamadığını oyuncuya anlatan kısa açıklama.
static func unavailable_reason(provider: String) -> String:
	var platform: String = PROVIDERS[provider]["platform"]
	if OS.get_name() != platform:
		return "%s ile giriş %s telefonlarda çalışır." % [provider_name(provider), "iPhone" if platform == "iOS" else "Android"]
	return "%s ile giriş oyunun mağaza sürümünde açılacak." % provider_name(provider)


## Telefonun giriş ekranını açar; sonuç on_done(ok: bool, message: String) ile döner.
static func link(provider: String, on_done: Callable) -> void:
	if not available(provider):
		on_done.call(false, unavailable_reason(provider))
		return
	var native := Engine.get_singleton(NATIVE_SINGLETONS[provider])
	native.connect("signed_in", func(user_id: String, display_name: String) -> void:
		Saves.set_setting("account", { "provider": provider, "id": user_id, "name": display_name })
		upload_if_linked(Saves.snapshot())
		on_done.call(true, "%s hesabın bağlandı" % provider_name(provider))
	, CONNECT_ONE_SHOT)
	native.connect("sign_in_failed", func(error: String) -> void:
		on_done.call(false, "Giriş yapılamadı: %s" % error)
	, CONNECT_ONE_SHOT)
	native.call("sign_in")


## Hesap silinirken buluttaki kaydı siler ve bağlantıyı kaldırır.
static func delete_cloud() -> void:
	if is_linked() and BACKEND_URL != "":
		pass # Sunucu kurulduğunda: hesap kimliğiyle BACKEND_URL'deki kayıt silinir.
	unlink()


static func unlink() -> void:
	Saves.set_setting("account", {})


## Hesap bağlıysa kaydı buluta gönderir (SaveSystem her kayıtta çağırır).
static func upload_if_linked(_data: Dictionary) -> void:
	if not is_linked() or BACKEND_URL == "":
		return
	# Sunucu kurulduğunda: kayıt hesap kimliğiyle BACKEND_URL'e gönderilir.
