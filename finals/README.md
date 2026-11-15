# Готовые сборки

Архивы распаковывать **в корень проекта** — внутри уже лежит `addons/udim_texture/…`,
после распаковки включить плагин в `Project Settings → Plugins`.
Инструкция по подключению своих текстур — в `addons/udim_texture/README.md`
(она лежит внутри архива).

Архивы в git не хранятся (`finals/*.zip` в `.gitignore`): они прикрепляются к
**GitHub Releases**. Как выпустить новую версию — `PUBLISH.md` в корне репозитория.

| Архив | Версия | Что внутри |
|---|---|---|
| `udim_texture-v1.2.1.zip` | 1.2.1 | UDIMMaterial + UDIMTextureSet, PBR-карты albedo/roughness/metallic/normal/emission/AO + Height (параллакс). Новое: перетаскивание PNG прямо в инспектор (поле **PNG Textures**), путь к папке вписывается текстом + кнопка **«Выбрать папку»**, импорт тайлов (`name.1001.png`), README с пошаговой инструкцией, Godot 4.7 |

Проверено на Godot **4.7.2** (Forward+, Vulkan): аддон ставится, включается и
рендерит UDIM-модель с Height-картой.

Содержимое архива:

```
addons/udim_texture/plugin.cfg
addons/udim_texture/udim_material.gd
addons/udim_texture/udim_texture_set.gd
addons/udim_texture/udim_plugin.gd
addons/udim_texture/icons/*.svg
addons/udim_texture/README.md
addons/udim_texture/LICENSE.txt
```
