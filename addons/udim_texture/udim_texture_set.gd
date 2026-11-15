@tool
@icon("res://addons/udim_texture/icons/udim_texture_set.svg")
class_name UDIMTextureSet
extends Resource
## Набор UDIM-тайлов ОДНОЙ карты (например, только BaseColor).
##
## Тайлы можно назначить вручную через словарь [member tiles] (ключ — номер UDIM,
## значение — Texture2D), либо найти автоматически по кнопке [b]Сканировать папку[/b]:
## файлы должны называться name.1001.png, name.1002.png и т.д.
##
## [UDIMMaterial] по этому набору генерирует шейдер: у каждого тайла свой сэмплер,
## участок выбирается по целой части UV.

## Папка с тайлами (res://...).
@export_dir var folder: String = "":
	set(value):
		if folder == value:
			return
		folder = value
		if folder.is_empty():
			return
		if Engine.is_editor_hint() and auto_scan:
			rescan()

## Общая часть имени файлов без номера тайла: name.1001.png -> "name".
@export var base_name: String = "":
	set(value):
		if base_name == value:
			return
		base_name = value
		if not folder.is_empty() and Engine.is_editor_hint() and auto_scan:
			rescan()

## Автоматически перечитывать папку при смене пути/имени.
@export var auto_scan: bool = true

## Номер UDIM -> Texture2D. Заполняется автоматически или вручную.
@export var tiles: Dictionary = {}:
	set(value):
		tiles = value
		emit_changed()

## Кнопка в инспекторе: перечитать папку.
@export_tool_button("Сканировать папку", "Reload") var _scan_action: Callable = rescan


## Возвращает тайлы набора, при необходимости подхватывая их из папки.
func get_tiles() -> Dictionary:
	if tiles.is_empty() and auto_scan and not folder.is_empty() and Engine.is_editor_hint():
		rescan()
	return tiles


func has_tiles() -> bool:
	return not get_tiles().is_empty()


## Номера тайлов по возрастанию.
func get_tile_ids() -> Array:
	var ids := get_tiles().keys()
	ids.sort()
	return ids


## Перечитывает папку и заполняет [member tiles].
func rescan() -> void:
	if folder.is_empty():
		push_warning("UDIMTextureSet: не задана папка с тайлами.")
		return
	var found := scan_folder(folder, base_name)
	if found.is_empty():
		# Не затираем ручные назначения, если ничего не нашли.
		push_warning("UDIMTextureSet: в папке '%s' не найдено файлов вида name.####.png" % folder)
		return
	tiles = found


## Ищет в папке файлы name.####.ext и возвращает словарь {номер UDIM: Texture2D}.
static func scan_folder(p_folder: String, p_base_name: String = "") -> Dictionary:
	var groups := group_folder(p_folder)
	if p_base_name.is_empty():
		var merged := {}
		for base in groups.keys():
			for udim in groups[base].keys():
				merged[udim] = groups[base][udim]
		return merged
	if groups.has(p_base_name):
		return groups[p_base_name].duplicate()
	return {}


## Группирует файлы папки по имени без номера: {base_name: {udim: Texture2D}}.
static func group_folder(p_folder: String) -> Dictionary:
	var result := {}
	var dir := DirAccess.open(p_folder)
	if dir == null:
		push_error("UDIMTextureSet: не удалось открыть папку '%s'" % p_folder)
		return result

	var regex := RegEx.create_from_string("^(?<base>.+?)\\.(?<udim>\\d{4})\\.(?<ext>[A-Za-z0-9]+)$")
	for file_name in dir.get_files():
		if file_name.ends_with(".import"):
			continue
		var m := regex.search(file_name)
		if m == null:
			continue
		var udim := int(m.get_string("udim"))
		if not is_valid_udim(udim):
			continue
		var path := p_folder.path_join(file_name)
		if not ResourceLoader.exists(path):
			continue
		var tex := load(path)
		if not tex is Texture2D:
			continue
		var base := m.get_string("base")
		if not result.has(base):
			result[base] = {}
		result[base][udim] = tex
	return result


## Номер тайла UDIM: 1001 + U + 10 * V (U, V — начиная с нуля), поэтому 1001..1999.
static func is_valid_udim(udim: int) -> bool:
	return udim >= 1001 and udim <= 1999


## Ячейка UDIM (U, V) для номера тайла.
static func udim_to_cell(udim: int) -> Vector2i:
	var offset := udim - 1001
	return Vector2i(offset % 10, int(floor(float(offset) / 10.0)))


## Границы сетки тайлов: Rect2i(x = min U, y = min V, width = колонок, height = рядов).
func get_grid() -> Rect2i:
	var ids := get_tile_ids()
	if ids.is_empty():
		return Rect2i(0, 0, 1, 1)

	var min_u := 0x3FFFFFFF
	var min_v := 0x3FFFFFFF
	var max_u := -0x3FFFFFFF
	var max_v := -0x3FFFFFFF
	for id in ids:
		var cell := udim_to_cell(int(id))
		min_u = mini(min_u, cell.x)
		min_v = mini(min_v, cell.y)
		max_u = maxi(max_u, cell.x)
		max_v = maxi(max_v, cell.y)
	return Rect2i(min_u, min_v, max_u - min_u + 1, max_v - min_v + 1)
