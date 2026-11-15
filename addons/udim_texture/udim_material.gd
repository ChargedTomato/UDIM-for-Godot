@tool
@icon("res://addons/udim_texture/icons/udim_material.svg")
class_name UDIMMaterial
extends ShaderMaterial
## Материал для мешей с UDIM-развёрткой (Godot 4.7).
##
## Каждая карта (albedo, roughness, metallic, normal, emission, ao, height)
## задаётся отдельным [UDIMTextureSet]. Номер тайла выбирается по целой части UV:
## UV.x = 0..1 — тайл 1001, 1..2 — 1002 и т.д.
##
## Шейдер генерируется автоматически под конкретный набор тайлов (по одному
## сэмплеру на тайл), поэтому материал корректно сохраняется в .tres и
## загружается без пересборки.
##
## Быстрый старт: перетащи PNG-файлы в поле [b]Png Textures[/b] — карты и тайлы
## разложатся сами (слот по слову в имени, номер тайла по #### в имени).
## Второй способ: укажи [member import_folder] и нажми [b]Собрать материал из папки[/b].

## Ключевые слова в именах файлов -> слот материала. Порядок: от длинных к коротким.
const MAP_KEYWORDS := {
	"albedo": ["basecolor", "base_color", "albedo", "diffuse", "colour", "color"],
	"roughness": ["roughness", "rough"],
	"metallic": ["metallic", "metalness", "metal"],
	"normal": ["normalmap", "normal", "nrm"],
	"emission": ["emissive", "emission", "emit"],
	"ao": ["ambientocclusion", "ambient_occlusion", "occlusion", "ao"],
	"height": ["heightmap", "height_map", "height", "displacement", "disp", "parallax", "bump"],
}

const SLOTS := ["albedo", "roughness", "metallic", "normal", "emission", "ao", "height"]

## Слоты, к которым применяется sRGB-преобразование.
const SRGB_SLOTS := ["albedo", "emission"]

## Предупреждать, если тайлов в одной карте больше этого числа (много сэмплеров в шейдере).
const WARN_TILES_PER_SET := 32

@export_group("PNG текстуры")
## Перетащи сюда PNG-файлы прямо из FileSystem (можно сразу несколько).
## Слот карты определяется по слову в имени файла (BaseColor, Roughness, Normal,
## Height, AO, Emission…), номер тайла — по четырём цифрам (1001, 1002…).
## Если цифр нет, файл считается тайлом 1001.
## Список не сохраняется в .tres: он только раскладывает текстуры по слотам.
@export var png_textures: Array[Texture2D] = []:
	set(value):
		png_textures = value
		if Engine.is_editor_hint() and not value.is_empty():
			sort_textures()
## Кнопка: разложить PNG из поля выше по слотам заново.
@export_tool_button("Разложить PNG по слотам", "Reload") var _sort_png_action: Callable = sort_textures

@export_group("UDIM карты")
@export var albedo_tiles: UDIMTextureSet = null:
	set(value):
		albedo_tiles = _bind_slot(albedo_tiles, value)
		_refresh()
@export var roughness_tiles: UDIMTextureSet = null:
	set(value):
		roughness_tiles = _bind_slot(roughness_tiles, value)
		_refresh()
@export var metallic_tiles: UDIMTextureSet = null:
	set(value):
		metallic_tiles = _bind_slot(metallic_tiles, value)
		_refresh()
@export var normal_tiles: UDIMTextureSet = null:
	set(value):
		normal_tiles = _bind_slot(normal_tiles, value)
		_refresh()
@export var emission_tiles: UDIMTextureSet = null:
	set(value):
		emission_tiles = _bind_slot(emission_tiles, value)
		_refresh()
@export var ao_tiles: UDIMTextureSet = null:
	set(value):
		ao_tiles = _bind_slot(ao_tiles, value)
		_refresh()
@export var height_tiles: UDIMTextureSet = null:
	set(value):
		height_tiles = _bind_slot(height_tiles, value)
		_refresh()

@export_group("Импорт из папки")
## Путь к папке с файлами name.1001.png, name.1002.png, ... Вписывается руками,
## например res://textures (или выбери кнопкой [b]Выбрать папку[/b]).
@export var import_folder: String = ""
## Фильтр по началу имени: например "Zvenevoi_UV7_Character_".
@export var import_prefix: String = ""
## Кнопка: выбрать папку с тайлами в диалоге.
@export_tool_button("Выбрать папку", "Folder") var _pick_folder_action: Callable = pick_folder
## Кнопка: разложить файлы папки по слотам материала.
@export_tool_button("Собрать материал из папки", "Reload") var _import_action: Callable = scan_folder

@export_group("Основное")
@export var albedo_color: Color = Color.WHITE:
	set(value):
		albedo_color = value
		_refresh()
@export_range(0.0, 1.0) var metallic: float = 1.0:
	set(value):
		metallic = value
		_refresh()
@export_range(0.0, 1.0) var roughness: float = 1.0:
	set(value):
		roughness = value
		_refresh()
@export_range(0.0, 1.0) var specular: float = 0.5:
	set(value):
		specular = value
		_refresh()

@export_group("Нормали")
@export_range(0.0, 2.0) var normal_strength: float = 1.0:
	set(value):
		normal_strength = value
		_refresh()
@export var normal_flip_y: bool = false:
	set(value):
		normal_flip_y = value
		_refresh()

@export_group("Эмиссия")
@export var emission_color: Color = Color.BLACK:
	set(value):
		emission_color = value
		_refresh()
@export_range(0.0, 32.0) var emission_energy: float = 1.0:
	set(value):
		emission_energy = value
		_refresh()

@export_group("AO")
@export_range(0.0, 1.0) var ao_strength: float = 1.0:
	set(value):
		ao_strength = value
		_refresh()

@export_group("Height (параллакс)")
## Смещение в UV на единицу высоты. 0 — выключить параллакс.
@export_range(0.0, 0.5) var height_scale: float = 0.03:
	set(value):
		height_scale = value
		_refresh()
## Количество итераций уточнения (1 — обычный параллакс, 8+ — точнее на скользящих углах).
@export_range(1, 32) var height_steps: int = 8:
	set(value):
		height_steps = value
		_refresh()
## Значение Height-карты, соответствующее плоскости меша (0.5 — типовая запись, 0 — если чёрный = база).
@export_range(0.0, 1.0) var height_base: float = 0.5:
	set(value):
		height_base = value
		_refresh()
## Инвертировать Height-карту (если белое должно быть впадиной).
@export var height_flip: bool = false:
	set(value):
		height_flip = value
		_refresh()

@export_group("Прочее")
@export_range(0.0, 1.0) var alpha_scissor: float = 0.0:
	set(value):
		alpha_scissor = value
		_refresh()
@export var use_vertex_color: bool = false:
	set(value):
		use_vertex_color = value
		_refresh()

var _code := ""
var _used_params: Array[String] = []


func _init() -> void:
	_refresh()


func _validate_property(property: Dictionary) -> void:
	# Список PNG — только помощник drag&drop: в .tres его не пишем,
	# иначе он дублирует уже разложенные тайлы в слотах.
	if property.name == "png_textures":
		property.usage = PROPERTY_USAGE_EDITOR


## Пересобирает шейдер (если изменился набор тайлов) и параметры материала.
func _refresh() -> void:
	var code := _build_code()
	if code != _code:
		_code = code
		var generated := Shader.new()
		generated.code = code
		shader = generated
	_apply_params()


func _bind_slot(old: UDIMTextureSet, new_value: UDIMTextureSet) -> UDIMTextureSet:
	if old == new_value:
		return old
	if old != null and old.changed.is_connected(_on_tiles_changed):
		old.changed.disconnect(_on_tiles_changed)
	if new_value != null and not new_value.changed.is_connected(_on_tiles_changed):
		new_value.changed.connect(_on_tiles_changed)
	return new_value


func _on_tiles_changed() -> void:
	_refresh()


func _tiles_of(slot: String) -> UDIMTextureSet:
	return get(slot + "_tiles")


func _tile_ids(slot: String) -> Array:
	var set_res: UDIMTextureSet = _tiles_of(slot)
	if set_res == null or not set_res.has_tiles():
		return []
	return set_res.get_tile_ids()


func _build_code() -> String:
	_used_params.clear()

	var code := "// Сгенерировано UDIMMaterial (аддон UDIM Textures). Правки затрутся.\n"
	code += "shader_type spatial;\n"
	code += "render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;\n\n"

	# Сэмплеры тайлов: по одному на тайл каждой карты.
	for slot in SLOTS:
		var ids := _tile_ids(slot)
		if ids.size() > WARN_TILES_PER_SET:
			push_warning("UDIMMaterial: в слое '%s' %d тайлов — шейдер получится тяжёлым." % [slot, ids.size()])
		for id in ids:
			var hints := "filter_linear_mipmap_anisotropic, repeat_disable"
			if slot in SRGB_SLOTS:
				hints = "source_color, " + hints
			code += "uniform sampler2D %s_%d : %s;\n" % [slot, int(id), hints]
			_used_params.append("%s_%d" % [slot, int(id)])
	code += "\n"

	# Скалярные параметры.
	code += "uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);\n"
	code += "uniform float specular = 0.5;\n"
	code += "uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);\n"
	code += "uniform float emission_energy = 1.0;\n"
	code += "uniform float alpha_scissor = 0.0;\n"
	code += "uniform bool use_vertex_color = false;\n"
	_used_params.append_array(["albedo_color", "specular", "emission_color", "emission_energy", "alpha_scissor", "use_vertex_color"])
	if _tile_ids("metallic").is_empty():
		code += "uniform float metallic = 1.0;\n"
		_used_params.append("metallic")
	if _tile_ids("roughness").is_empty():
		code += "uniform float roughness = 1.0;\n"
		_used_params.append("roughness")
	if not _tile_ids("normal").is_empty():
		code += "uniform float normal_strength = 1.0;\n"
		code += "uniform bool normal_flip_y = false;\n"
		_used_params.append_array(["normal_strength", "normal_flip_y"])
	if not _tile_ids("ao").is_empty():
		code += "uniform float ao_strength = 1.0;\n"
		_used_params.append("ao_strength")
	if not _tile_ids("height").is_empty():
		code += "uniform float height_scale = 0.03;\n"
		code += "uniform int height_steps = 8;\n"
		code += "uniform float height_base = 0.5;\n"
		code += "uniform bool height_flip = false;\n"
		_used_params.append_array(["height_scale", "height_steps", "height_base", "height_flip"])
	code += "\n"

	# Функции выборки тайла по UV.
	for slot in SLOTS:
		if slot == "height":
			continue
		var ids := _tile_ids(slot)
		if ids.is_empty():
			continue
		code += "vec4 udim_%s(vec2 uv) {\n" % slot
		code += "\tvec2 cell = floor(uv);\n"
		code += "\tvec2 local = uv - cell;\n"
		for id in ids:
			var cell := UDIMTextureSet.udim_to_cell(int(id))
			code += "\tif (cell == vec2(%d.0, %d.0)) { return texture(%s_%d, local); }\n" % [cell.x, cell.y, slot, int(id)]
		code += "\treturn vec4(0.0);\n"
		code += "}\n\n"

	if not _tile_ids("height").is_empty():
		# Высота относительно плоскости меша: >0 — выше неё, <0 — ниже.
		code += "float udim_height_dh(vec2 cell, vec2 local) {\n"
		code += "\tfloat h = -1.0;\n"
		for id in _tile_ids("height"):
			var hcell := UDIMTextureSet.udim_to_cell(int(id))
			code += "\tif (cell == vec2(%d.0, %d.0)) { h = texture(height_%d, local).r; }\n" % [hcell.x, hcell.y, int(id)]
		code += "\tif (h < 0.0) { return 0.0; }\n"
		code += "\tif (height_flip) { h = 1.0 - h; }\n"
		code += "\treturn h - height_base;\n"
		code += "}\n\n"

		# Смещение UV по параллаксу: итеративно уточняем точку на поверхности.
		code += "vec2 udim_displace(vec2 uv, vec3 t, vec3 b, vec3 n, vec3 view_dir) {\n"
		code += "\tvec2 cell = floor(uv);\n"
		code += "\tvec2 local = uv - cell;\n"
		code += "\tfloat lt = dot(t, t);\n"
		code += "\tfloat lb = dot(b, b);\n"
		code += "\tfloat ln = dot(n, n);\n"
		code += "\tif (lt < 1e-8 || lb < 1e-8 || ln < 1e-8) { return uv; }\n"
		code += "\tvec3 view_ts = normalize(vec3(dot(view_dir, t / sqrt(lt)), dot(view_dir, b / sqrt(lb)), dot(view_dir, n / sqrt(ln))));\n"
		# TANGENT смотрит вдоль +U, BINORMAL — вверх экрана, т.е. вдоль -V,
		# поэтому вертикальная составляющая смещения берётся со знаком минус.
		code += "\tvec2 plane = vec2(view_ts.x, -view_ts.y) / max(view_ts.z, 0.2) * height_scale;\n"
		code += "\tvec2 pos = local;\n"
		code += "\tfor (int i = 0; i < 32; i++) {\n"
		code += "\t\tif (i >= height_steps) { break; }\n"
		code += "\t\tpos = local + plane * udim_height_dh(cell, clamp(pos, vec2(0.0005), vec2(0.9995)));\n"
		code += "\t}\n"
		code += "\treturn cell + clamp(pos, vec2(0.0005), vec2(0.9995));\n"
		code += "}\n\n"

	# Фрагментный шейдер.
	code += "void fragment() {\n"
	code += "\tvec2 uv = UV;\n"
	if not _tile_ids("height").is_empty():
		code += "\tif (height_scale > 0.0) { uv = udim_displace(UV, TANGENT, BINORMAL, NORMAL, VIEW); }\n"
	code += "\tvec4 albedo_tex = vec4(1.0);\n"
	if not _tile_ids("albedo").is_empty():
		code += "\talbedo_tex = udim_albedo(uv);\n"
	code += "\tALBEDO = albedo_color.rgb * albedo_tex.rgb;\n"
	code += "\tif (use_vertex_color) { ALBEDO *= COLOR.rgb; }\n"

	if _tile_ids("metallic").is_empty():
		code += "\tMETALLIC = metallic;\n"
	else:
		code += "\tMETALLIC = udim_metallic(uv).r;\n"
	if _tile_ids("roughness").is_empty():
		code += "\tROUGHNESS = roughness;\n"
	else:
		code += "\tROUGHNESS = udim_roughness(uv).r;\n"
	code += "\tSPECULAR = specular;\n"

	if not _tile_ids("normal").is_empty():
		code += "\tvec3 normal_tex = udim_normal(uv).rgb;\n"
		code += "\tif (normal_flip_y) { normal_tex.g = 1.0 - normal_tex.g; }\n"
		code += "\tNORMAL_MAP = normal_tex;\n"
		code += "\tNORMAL_MAP_DEPTH = normal_strength;\n"

	code += "\tEMISSION = emission_color.rgb * emission_energy;\n"
	if not _tile_ids("emission").is_empty():
		code += "\tEMISSION *= udim_emission(uv).rgb;\n"

	if not _tile_ids("ao").is_empty():
		code += "\tAO = mix(1.0, udim_ao(uv).r, ao_strength);\n"

	code += "\tif (alpha_scissor > 0.0) {\n"
	code += "\t\tfloat alpha = albedo_color.a * albedo_tex.a;\n"
	code += "\t\tif (alpha < alpha_scissor) { discard; }\n"
	code += "\t}\n"
	code += "}\n"

	return code


func _apply_params() -> void:
	var values := {
		"albedo_color": albedo_color,
		"specular": specular,
		"emission_color": emission_color,
		"emission_energy": emission_energy,
		"alpha_scissor": alpha_scissor,
		"use_vertex_color": use_vertex_color,
		"metallic": metallic,
		"roughness": roughness,
		"normal_strength": normal_strength,
		"normal_flip_y": normal_flip_y,
		"ao_strength": ao_strength,
		"height_scale": height_scale,
		"height_steps": height_steps,
		"height_base": height_base,
		"height_flip": height_flip,
	}
	for param in _used_params:
		if values.has(param):
			set_shader_parameter(param, values[param])

	for slot in SLOTS:
		var set_res: UDIMTextureSet = _tiles_of(slot)
		if set_res == null:
			continue
		var found := set_res.get_tiles()
		for id in found.keys():
			var param := "%s_%d" % [slot, int(id)]
			if param in _used_params:
				set_shader_parameter(param, found[id])


## Раскладывает PNG из [member png_textures] по слотам: слово в имени -> карта,
## четырёхзначный номер -> тайл UDIM.
func sort_textures() -> void:
	if png_textures.is_empty():
		push_warning("UDIMMaterial: поле PNG пустое — перетащи в него файлы текстур.")
		return

	var groups := {}
	var skipped: Array[String] = []
	for tex in png_textures:
		if tex == null:
			continue
		var file := tex.resource_path.get_file()
		if file.is_empty():
			file = tex.resource_name
		var slot := _slot_for_name(file.get_basename())
		if slot.is_empty():
			skipped.append(file)
			continue
		var udim := _udim_of_file(file)
		if not groups.has(slot):
			groups[slot] = {}
		var slot_tiles: Dictionary = groups[slot]
		slot_tiles[udim] = tex

	if groups.is_empty():
		push_warning("UDIMMaterial: в именах файлов нет ключевых слов карты (BaseColor, Roughness, Normal, Height, AO, Emission).")
		return

	var bound: Array[String] = []
	var cleared: Array[String] = []
	for slot in SLOTS:
		if not groups.has(slot):
			if _tiles_of(slot) != null:
				set(slot + "_tiles", null)
				cleared.append(slot)
			continue
		var slot_tiles: Dictionary = groups[slot]
		var ids := slot_tiles.keys()
		ids.sort()
		var set_res := UDIMTextureSet.new()
		set_res.auto_scan = false
		set_res.tiles = slot_tiles
		set(slot + "_tiles", set_res)
		var id_text: Array[String] = []
		for id in ids:
			id_text.append(str(int(id)))
		bound.append("%s: тайлы %s" % [slot, ", ".join(id_text)])

	print("UDIMMaterial: разложено PNG по слотам: %d" % bound.size())
	for line in bound:
		print("  ", line)
	if not skipped.is_empty():
		print("UDIMMaterial: пропущены (нет слова карты в имени): ", ", ".join(skipped))
	if not cleared.is_empty():
		print("UDIMMaterial: очищены слоты без PNG: ", ", ".join(cleared))
	emit_changed()
	_refresh()


## Номер тайла из имени файла: "Skin_BaseColor.1002.png" -> 1002.
## Если четырёхзначного номера нет, файл считается тайлом 1001.
static func _udim_of_file(file_name: String) -> int:
	var base := file_name.get_basename()
	var regex := RegEx.create_from_string("(?:^|[._\\- ])(\\d{4})(?:$|[._\\- ])")
	var m := regex.search(base)
	if m != null:
		var udim := int(m.get_string(1))
		if UDIMTextureSet.is_valid_udim(udim):
			return udim
	return 1001


## Открывает диалог выбора папки с тайлами (только в редакторе).
func pick_folder() -> void:
	if not Engine.is_editor_hint():
		return
	var base := EditorInterface.get_base_control()
	if base == null:
		return
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.title = "Папка с UDIM-тайлами"
	dialog.dir_selected.connect(_on_folder_selected.bind(dialog))
	dialog.canceled.connect(dialog.queue_free)
	if not import_folder.is_empty():
		dialog.current_dir = import_folder
	base.add_child(dialog)
	dialog.popup_centered_ratio(0.35)


func _on_folder_selected(dir: String, dialog: FileDialog) -> void:
	dialog.queue_free()
	import_folder = dir if dir.begins_with("res://") else ProjectSettings.localize_path(dir)
	scan_folder()


## Раскладывает тайлы из [member import_folder] по слотам по именам файлов.
func scan_folder() -> void:
	if import_folder.is_empty():
		push_warning("UDIMMaterial: не задана папка импорта (или перетащи PNG в поле Png Textures).")
		return

	var groups := UDIMTextureSet.group_folder(import_folder)
	if groups.is_empty():
		push_warning("UDIMMaterial: в '%s' нет файлов вида name.####.ext" % import_folder)
		return

	var bound: Array[String] = []
	var skipped: Array[String] = []
	for base_name in groups.keys():
		var map_name: String = base_name
		if not import_prefix.is_empty():
			if not map_name.begins_with(import_prefix):
				continue
			map_name = map_name.substr(import_prefix.length())

		var slot := _slot_for_name(map_name)
		if slot.is_empty():
			skipped.append(map_name)
			continue

		var set_res := UDIMTextureSet.new()
		set_res.auto_scan = false
		set_res.folder = import_folder
		set_res.base_name = base_name
		set_res.tiles = groups[base_name]
		set(slot + "_tiles", set_res)
		bound.append("%s -> %s" % [map_name, slot])

	print("UDIMMaterial: привязано карт: %d" % bound.size())
	for line in bound:
		print("  ", line)
	if not skipped.is_empty():
		print("UDIMMaterial: пропущены (нет подходящего слота): ", ", ".join(skipped))
	emit_changed()
	_refresh()


static func _slot_for_name(map_name: String) -> String:
	var lower := map_name.to_lower()
	var best_slot := ""
	var best_len := 0
	for slot in MAP_KEYWORDS.keys():
		for keyword in MAP_KEYWORDS[slot]:
			if lower.contains(keyword) and keyword.length() > best_len:
				best_slot = slot
				best_len = keyword.length()
	return best_slot
