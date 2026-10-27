extends Node
## Менеджер рекламы CellColony для платформы Яндекс Игры (Yandex Games SDK).
## Отвечает за вызов полноэкранной межстраничной рекламы (Interstitial / showFullscreenAdv)
## в соответствии с требованиями модерации платформы:
## 1. Показ при логических переходах (после прохождения или проигрыша уровня при нажатии кнопок).
## 2. Глушение звука игры (шина Master) на время показа рекламы.
## 3. Остановка и запуск GameplayAPI (start / stop).
## 4. Корректная симуляция в редакторе Godot и на ПК.

signal ad_opened()
signal ad_closed(was_shown: bool)

enum AdTriggerTiming {
	ON_ACTION = 1,        ## При нажатии кнопок выхода/перехода (Рекомендация и требование модерации Яндекса)
	ON_RESULT_SCREEN = 2, ## Автоматически сразу при показе экрана победы/поражения
}

var ad_trigger_timing: AdTriggerTiming = AdTriggerTiming.ON_ACTION
var is_ad_active: bool = false
var _saved_master_mute: bool = false
var _pending_close_callback: Callable = Callable()

var _on_open_callback: JavaScriptObject = null
var _on_close_callback: JavaScriptObject = null
var _on_error_callback: JavaScriptObject = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_web_callbacks()

func _setup_web_callbacks() -> void:
	if not _is_web():
		return
	_on_open_callback = JavaScriptBridge.create_callback(_js_on_open)
	_on_close_callback = JavaScriptBridge.create_callback(_js_on_close)
	_on_error_callback = JavaScriptBridge.create_callback(_js_on_error)

func _is_web() -> bool:
	return OS.has_feature("web") or OS.has_feature("yandex")

## Показ полноэкранной рекламы (Interstitial).
## on_closed — опциональный колбэк, вызываемый после закрытия/пропуска рекламы (передаёт was_shown: bool).
func show_interstitial(on_closed: Callable = Callable()) -> void:
	if is_ad_active:
		push_warning("[AdManager] Реклама уже открыта или в процессе вызова.")
		if on_closed.is_valid():
			on_closed.call(false)
		return

	if not _is_web():
		print("[AdManager] Симуляция межстраничной рекламы (ПК / редактор Godot).")
		ad_opened.emit()
		ad_closed.emit(true)
		if on_closed.is_valid():
			on_closed.call(true)
		return

	is_ad_active = true
	_pending_close_callback = on_closed

	# Запоминаем текущее состояние звука и глушим Master-шину
	var master_bus_idx := AudioServer.get_bus_index(&"Master")
	if master_bus_idx >= 0:
		_saved_master_mute = AudioServer.is_bus_mute(master_bus_idx)
		AudioServer.set_bus_mute(master_bus_idx, true)

	var win = JavaScriptBridge.get_interface("window")
	if win and win.has("showYandexFullscreenAd"):
		win.showYandexFullscreenAd(_on_open_callback, _on_close_callback, _on_error_callback)
	elif win and win.has("ShowAd"):
		win.ShowAd(_on_close_callback)
	else:
		push_warning("[AdManager] window.showYandexFullscreenAd не найден в HTML. Пропуск рекламы.")
		_js_on_close([false])

func _js_on_open(_args: Array = []) -> void:
	print("[AdManager] Реклама открыта (звук Master отключен)")
	var master_bus_idx := AudioServer.get_bus_index(&"Master")
	if master_bus_idx >= 0:
		AudioServer.set_bus_mute(master_bus_idx, true)
	ad_opened.emit()

func _js_on_close(args: Array = []) -> void:
	var was_shown: bool = false
	if not args.is_empty():
		was_shown = bool(args[0])
	print("[AdManager] Реклама закрыта, was_shown: ", was_shown)

	is_ad_active = false

	# Восстанавливаем состояние звука, которое было до рекламы
	var master_bus_idx := AudioServer.get_bus_index(&"Master")
	if master_bus_idx >= 0:
		AudioServer.set_bus_mute(master_bus_idx, _saved_master_mute)

	ad_closed.emit(was_shown)

	var cb := _pending_close_callback
	_pending_close_callback = Callable()
	if cb.is_valid():
		cb.call(was_shown)

func _js_on_error(args: Array = []) -> void:
	var err_msg = args[0] if not args.is_empty() else "Неизвестная ошибка"
	push_warning("[AdManager] Ошибка при показе рекламы: %s" % str(err_msg))

## Уведомление платформы Яндекс Игры о начале геймплея (GameplayAPI.start)
func gameplay_start() -> void:
	if not _is_web():
		return
	var win = JavaScriptBridge.get_interface("window")
	if win and win.has("yandexGameplayStart"):
		win.yandexGameplayStart()

## Уведомление платформы Яндекс Игры об остановке геймплея (GameplayAPI.stop)
func gameplay_stop() -> void:
	if not _is_web():
		return
	var win = JavaScriptBridge.get_interface("window")
	if win and win.has("yandexGameplayStop"):
		win.yandexGameplayStop()
