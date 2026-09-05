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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_translations_registered()
	_initialize_language()

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
	# 1. Сначала проверяем сохранённый выбор пользователя
	var saved_locale := _load_locale_from_settings()
	if not saved_locale.is_empty() and saved_locale in SUPPORTED_LOCALES:
		print("[LocalizationManager] Применён сохранённый язык игрока: ", saved_locale)
		set_locale(saved_locale, false)
		return
	
	# 2. Автоопределение для Яндекс Игр и Web
	if OS.has_feature("web"):
		var web_lang := _detect_web_language()
		if not web_lang.is_empty():
			var normalized := normalize_locale(web_lang)
			print("[LocalizationManager] Язык автоопределён через Web/Яндекс SDK: %s -> %s" % [web_lang, normalized])
			set_locale(normalized, false)
			return
	
	# 3. Системный язык устройства / редактора
	var system_lang := OS.get_locale_language()
	var fallback := normalize_locale(system_lang)
	print("[LocalizationManager] Автоопределение по ОС: %s -> %s" % [system_lang, fallback])
	set_locale(fallback, false)

func _detect_web_language() -> String:
	var script := """
		(function() {
			try {
				// 1. Приоритет: Яндекс SDK ysdk.environment.i18n.lang (п. 2.14 требований)
				if (window.ysdk && window.ysdk.environment && window.ysdk.environment.i18n && window.ysdk.environment.i18n.lang) {
					return String(window.ysdk.environment.i18n.lang);
				}
				// 2. URL параметр ?lang=... для удобного тестирования и черновиков
				var urlParams = new URLSearchParams(window.location.search);
				var paramLang = urlParams.get('lang');
				if (paramLang && paramLang.length > 0) {
					return String(paramLang);
				}
				// 3. Язык браузера
				var navLang = navigator.language || navigator.userLanguage || '';
				return String(navLang);
			} catch (e) {
				return '';
			}
		})()
	"""
	var result: Variant = JavaScriptBridge.eval(script)
	if result != null and result is String:
		return String(result)
	return ""

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
	# Проверяем, зарегистрированы ли уже переводы в TranslationServer
	var has_translations := false
	for loc in SUPPORTED_LOCALES:
		if not TranslationServer.get_translation_object(loc) == null:
			has_translations = true
			break
	
	if has_translations:
		return
	
	# Если скомпилированные .translation файлы не загрузились автоматически,
	# парсим CSV напрямую в Translation объекты для абсолютной автономности
	_load_translations_from_csv(CSV_TRANSLATION_PATH)

func _load_translations_from_csv(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("[LocalizationManager] CSV файл переводов не найден: " + path)
		return
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[LocalizationManager] Не удалось открыть CSV файл: " + path)
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
	for loc in locale_indices.keys():
		var trans := Translation.new()
		trans.locale = loc
		translation_map[loc] = trans
	
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
	
	for loc in translation_map.keys():
		TranslationServer.add_translation(translation_map[loc])
	
	print("[LocalizationManager] Успешно загружены и зарегистрированы переводы из CSV для: ", translation_map.keys())
