@tool
extends EditorPlugin
## Точка входа аддона UDIM Textures.
##
## Сам аддон работает и без включения плагина (классы UDIMTextureSet и UDIMMaterial
## регистрируются движком как обычные @tool-скрипты). Плагин нужен, чтобы аддон
## отображался в Project Settings -> Plugins и чтобы показать подсказку в консоли.

const VERSION := "1.2.1"


func _enter_tree() -> void:
	print("UDIM Textures %s: аддон включён. Классы: UDIMTextureSet, UDIMMaterial." % VERSION)


func _exit_tree() -> void:
	pass
