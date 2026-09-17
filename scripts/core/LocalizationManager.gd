extends Node
## Менеджер локализации CellColony.
## Реализует автоопределение языка под Яндекс Игры (ysdk.environment.i18n.lang, пункт 2.14)
## и стандартную Godot-локализацию через TranslationServer с реактивным переключением в рантайме.

signal language_changed(new_locale: String)

const SUPPORTED_LOCALES: Array[String] = ["ru", "en", "tr", "fr", "it"]
const LOCALE_NAMES: Dictionary = {
	"ru": "Русский",
	"en": "English",
	"tr": "Türkçe",
	"fr": "Français",
	"it": "Italiano",
}

const SETTINGS_FILE_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "general"
const SETTINGS_LOCALE_KEY: String = "locale"
const CSV_TRANSLATION_PATH: String = "res://translations/translations.csv"

var current_locale: String = "ru"
var user_manually_selected: bool = false
var _js_callback: JavaScriptObject = null
var _sdk_poll_timer: float = 0.0
var _sdk_poll_active: bool = false
var _sdk_detected: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_translations_registered()
	_setup_web_bridge()
	_initialize_language()

func _setup_web_bridge() -> void:
	if not OS.has_feature("web"):
		return
	
	# Регистрируем JavaScript коллбэк для мгновенного получения языка из Yandex SDK
	_js_callback = JavaScriptBridge.create_callback(_on_web_lang_received)
	var win = JavaScriptBridge.get_interface("window")
	if win:
		win.onYandexLangChange = _js_callback
	
	_sdk_poll_active = true
	_sdk_poll_timer = 0.0

func _process(delta: float) -> void:
	if not _sdk_poll_active or not OS.has_feature("web"):
		return
	
	_sdk_poll_timer += delta
	# Опрашиваем первые 6 секунд с интервалом ~0.25 сек
	if _sdk_poll_timer >= 6.0:
		_sdk_poll_active = false
		return
	
	# Проверяем, не появился ли язык в SDK
	var lang_info := _query_js_language()
	if not lang_info.is_empty():
		var detected_lang: String = lang_info.get("lang", "")
		var is_sdk: bool = bool(lang_info.get("is_sdk", false))
		var is_param: bool = bool(lang_info.get("is_param", false))
		
		if (is_sdk or is_param) and not detected_lang.is_empty():
			var normalized := normalize_locale(detected_lang)
			if normalized != current_locale and not user_manually_selected:
				print("[LocalizationManager] Polling: получен язык от SDK/URL: %s -> %s" % [detected_lang, normalized])
				_sdk_detected = true
				set_locale(normalized, false)
			if is_sdk:
				_sdk_poll_active = false

func _on_web_lang_received(args: Array) -> void:
	if args.is_empty():
		return
	var raw_lang := String(args[0])
	if raw_lang.is_empty():
		return
	print("[LocalizationManager] JS Callback: получен язык от Yandex SDK: ", raw_lang)
	var normalized := normalize_locale(raw_lang)
	_sdk_detected = true
	_sdk_poll_active = false
	if not user_manually_selected or normalized != current_locale:
		set_locale(normalized, false)

func get_supported_locales() -> Array[String]:
	return SUPPORTED_LOCALES.duplicate()

func get_locale_name(locale: String) -> String:
	return LOCALE_NAMES.get(locale, locale.to_upper())

func get_current_locale() -> String:
	return current_locale

func get_current_language() -> String:
	return current_locale

func set_locale(locale_code: String, save_preference: bool = true) -> void:
	var target_locale := normalize_locale(locale_code)
	current_locale = target_locale
	TranslationServer.set_locale(target_locale)
	
	if save_preference:
		user_manually_selected = true
		_save_locale_to_settings(target_locale)
	
	print("[LocalizationManager] Установлен язык: %s (%s)" % [target_locale, get_locale_name(target_locale)])
	language_changed.emit(target_locale)

func normalize_locale(raw_code: String) -> String:
	if raw_code.is_empty():
		return "en"
	
	var clean := raw_code.strip_edges().to_lower().replace("-", "_")
	var primary := clean.split("_")[0]
	
	match primary:
		"ru", "uk", "be", "kk", "uz", "ky", "tg", "az", "hy", "mo":
			return "ru"
		"tr":
			return "tr"
		"fr":
			return "fr"
		"it":
			return "it"
		"en":
			return "en"
		_:
			# Для любых других неподдерживаемых языков международный fallback — английский
			return "en"

func _initialize_language() -> void:
	# В Web-версии проверяем URL и Яндекс SDK в ПЕРВУЮ очередь (требование 2.14)
	if OS.has_feature("web"):
		var lang_info := _query_js_language()
		var web_lang: String = lang_info.get("lang", "")
		var is_sdk: bool = bool(lang_info.get("is_sdk", false))
		var is_param: bool = bool(lang_info.get("is_param", false))
		
		# Если задан URL параметр ?lang= (панель отладки Яндекса) или SDK уже готов
		if (is_param or is_sdk) and not web_lang.is_empty():
			var normalized := normalize_locale(web_lang)
			print("[LocalizationManager] Язык автоопределён через Web (SDK/URL): %s -> %s" % [web_lang, normalized])
			_sdk_detected = is_sdk
			set_locale(normalized, false)
			return
		
		# Если SDK ещё инициализируется, но есть сохранённый язык
		var saved_locale := _load_locale_from_settings()
		if not saved_locale.is_empty() and saved_locale in SUPPORTED_LOCALES:
			print("[LocalizationManager] Временный запуск с сохранённым языком (ждём SDK): ", saved_locale)
			set_locale(saved_locale, false)
			return
		
		# Если сохранённого нет, пробуем язык браузера
		if not web_lang.is_empty():
			var normalized := normalize_locale(web_lang)
			set_locale(normalized, false)
			return
	else:
		# Native / Desktop: Сначала сохранённый выбор пользователя
		var saved_locale := _load_locale_from_settings()
		if not saved_locale.is_empty() and saved_locale in SUPPORTED_LOCALES:
			print("[LocalizationManager] Применён сохранённый язык игрока: ", saved_locale)
			set_locale(saved_locale, false)
			return

	# Fallback: системный язык ОС
	var system_lang := OS.get_locale_language()
	var fallback := normalize_locale(system_lang)
	print("[LocalizationManager] Автоопределение по ОС: %s -> %s" % [system_lang, fallback])
	set_locale(fallback, false)

func _query_js_language() -> Dictionary:
	var script := """
		(function() {
			try {
				// 1. Обязательно считываем свойство SDK для фиксации платформой (требование п. 2.14)
				var sdkLang = '';
				if (window.ysdk && window.ysdk.environment && window.ysdk.environment.i18n && window.ysdk.environment.i18n.lang) {
					sdkLang = window.ysdk.environment.i18n.lang;
				}

				// 2. Проверяем URL параметр отладки Яндекса (?lang=xx)
				var urlParams = new URLSearchParams(window.location.search);
				var pLang = urlParams.get('lang');
				if (pLang && pLang.length > 0) {
					return JSON.stringify({ lang: pLang, is_param: true, is_sdk: sdkLang.length > 0 });
				}

				if (sdkLang.length > 0) {
					return JSON.stringify({ lang: sdkLang, is_param: false, is_sdk: true });
				}

				if (window.yandexLang && window.yandexLang.length > 0 && window.yandexSdkReady) {
					return JSON.stringify({ lang: window.yandexLang, is_param: false, is_sdk: true });
				}

				var navLang = navigator.language || navigator.userLanguage || '';
				return JSON.stringify({ lang: navLang, is_param: false, is_sdk: false });
			} catch (e) {
				return JSON.stringify({ lang: '', is_param: false, is_sdk: false });
			}
		})()
	"""
	var raw_res: Variant = JavaScriptBridge.eval(script)
	if raw_res != null and raw_res is String:
		var parsed = JSON.parse_string(String(raw_res))
		if parsed is Dictionary:
			return parsed
	return {}

func _load_locale_from_settings() -> String:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_FILE_PATH)
	if err == OK:
		return String(config.get_value(SETTINGS_SECTION, SETTINGS_LOCALE_KEY, ""))
	return ""

func _save_locale_to_settings(locale_code: String) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_FILE_PATH)
	config.set_value(SETTINGS_SECTION, SETTINGS_LOCALE_KEY, locale_code)
	config.save(SETTINGS_FILE_PATH)

func _ensure_translations_registered() -> void:
	# Дополняем и синхронизируем переводы из CSV файла напрямую,
	# гарантируя доступность всех актуальных ключей в рантайме
	_load_translations_from_csv(CSV_TRANSLATION_PATH)

func _load_translations_from_csv(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	
	var header_line := file.get_csv_line()
	if header_line.is_empty():
		return
	
	var locale_indices: Dictionary = {}
	for i in range(1, header_line.size()):
		var col_name := header_line[i].strip_edges().to_lower()
		if col_name in SUPPORTED_LOCALES:
			locale_indices[col_name] = i
	
	var translation_map: Dictionary = {}
	var newly_created: Array[String] = []
	for loc in locale_indices.keys():
		var existing: Translation = TranslationServer.get_translation_object(loc)
		if existing == null:
			var trans := Translation.new()
			trans.locale = loc
			translation_map[loc] = trans
			newly_created.append(loc)
		else:
			translation_map[loc] = existing
	
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.is_empty() or line.size() < 2:
			continue
		var key := line[0].strip_edges()
		if key.is_empty():
			continue
		
		for loc in locale_indices.keys():
			var col_idx: int = locale_indices[loc]
			if col_idx < line.size():
				var msg := line[col_idx]
				(translation_map[loc] as Translation).add_message(key, msg)
	
	file.close()
	
	for loc in newly_created:
		TranslationServer.add_translation(translation_map[loc])
