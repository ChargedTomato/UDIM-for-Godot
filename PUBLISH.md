# Как выложить аддон на GitHub и сделать релиз

Инструкция для этого репозитория. Ничего платного не нужно, всё делается в браузере
и в PowerShell.

## 0. Что уже готово

- `addons/udim_texture/` — сам аддон (это и есть публикуемый код).
- `README.md`, `LICENSE`, `addons/udim_texture/README.md` — описание и лицензия MIT
  с двумя копирайтами (pkmollman — оригинал, UDIM Textures contributors — переработка).
- `finals/udim_texture-v1.2.1.zip` — собранный архив для скачивания.
- `.gitignore` не пускает в репозиторий `test/` (чужая модель и текстуры),
  `backup/`, `godot-udim-material-addon-main/` (старый аддон) и `finals/*.zip`
  (архивы выкладываются в Releases, а не в git).
- Локальный git уже инициализирован, ветка `main`, первый коммит есть.

## 1. Указать своё имя в коммитах

```powershell
cd E:\AI\GodotAddon\UDIM
git config user.name  "Ваше Имя"
git config user.email "you@example.com"
```

## 2. Создать пустой репозиторий на GitHub

1. Открой <https://github.com/new>.
2. **Repository name**: например `godot-udim-textures`.
3. **Public**, галочки `Add a README file`, `Add .gitignore`, `Choose a license`
   **не ставить** (иначе будет конфликт с локальными файлами).
4. `Create repository`.

## 3. Залить код

Скопируй ссылку репозитория (кнопка **Code → HTTPS**) и подставь свою:

```powershell
cd E:\AI\GodotAddon\UDIM
git remote add origin https://github.com/<логин>/godot-udim-textures.git
git push -u origin main
```

При первом `push` GitHub попросит логин и **Personal Access Token** вместо пароля
(Settings → Developer settings → Personal access tokens → Tokens (classic) →
`Generate new token`, права `repo`). Токен вводится в поле пароля.

Проверка:

```powershell
git remote -v
git log --oneline -1
```

## 4. Тег версии

```powershell
cd E:\AI\GodotAddon\UDIM
git tag -a v1.2.1 -m "UDIM Textures 1.2.1"
git push origin v1.2.1
```

## 5. Сделать релиз с архивом

1. На странице репозитория: **Releases → Draft a new release**
   (или сразу <https://github.com/<логин>/godot-udim-textures/releases/new>).
2. **Choose a tag** → `v1.2.1` (создан в шаге 4) → `Create new tag on publish` не нужно.
3. **Release title**: `UDIM Textures 1.2.1`.
4. **Describe this release** — можно вставить:

   ```markdown
   UDIM-текстуры для Godot 4.7.2: material + набор тайлов, PBR
   (albedo / roughness / metallic / normal / emission / AO) и Height (параллакс).

   Установка: распаковать архив в корень проекта (появится `addons/udim_texture/`),
   включить плагин **UDIM Textures** в `Project Settings → Plugins`.

   Подключение текстур: создать отдельный `UDIMMaterial` и перетащить PNG
   в поле **PNG Textures** (или указать папку и нажать «Собрать материал из папки»),
   затем `Ctrl+S` и назначить материал в **Material Override** меша.

   Подробно — `addons/udim_texture/README.md` внутри архива.
   Лицензия: MIT (pkmollman, оригинальный аддон; переработка под Godot 4.7).
   ```

5. **Attach binaries**: перетащи файл `E:\AI\GodotAddon\UDIM\finals\udim_texture-v1.2.1.zip`
   в поле «Attach binaries by dropping them here».
6. `Publish release`.

Итог: код лежит в репозитории, архив — в разделе Releases, ссылка на скачивание
вида `https://github.com/<логин>/godot-udim-textures/releases/latest`.

## 6. Проверить релиз как пользователь

1. Скачать `udim_texture-v1.2.1.zip` со страницы релиза.
2. Распаковать **в корень любого проекта** (не в `addons/`, а рядом с `project.godot`).
3. `Project → Project Settings → Plugins` → включить **UDIM Textures**.
4. В консоли должно появиться: `UDIM Textures 1.2.1: аддон включён.`

## 7. Выпуск следующей версии

1. Поднять номер в четырёх местах:
   - `addons/udim_texture/plugin.cfg` → `version="X.Y.Z"`;
   - `addons/udim_texture/udim_plugin.gd` → `const VERSION := "X.Y.Z"`;
   - заголовок `addons/udim_texture/README.md`;
   - `README.md` и `finals/README.md`.
2. Пересобрать архив `finals/udim_texture-X.Y.Z.zip` (внутри папка `addons/udim_texture/`,
   записи с прямыми слэшами `/`). Быстрый способ:

   ```powershell
   $src = "C:\Users\dd475\AppData\Local\Temp\opencode\udim_zip"
   Remove-Item -Recurse -Force $src -ErrorAction SilentlyContinue
   New-Item -ItemType Directory -Force "$src\addons\udim_texture" | Out-Null
   Copy-Item -Recurse -Force ".\addons\udim_texture\*" "$src\addons\udim_texture"
   $zip = "E:\AI\GodotAddon\UDIM\finals\udim_texture-X.Y.Z.zip"
   Add-Type -AssemblyName System.IO.Compression.FileSystem
   $a = [System.IO.Compression.ZipFile]::Open($zip, 'Create')
   foreach ($f in Get-ChildItem -Recurse -File $src) {
       $rel = $f.FullName.Substring($src.Length + 1).Replace('\', '/')
       $e = $a.CreateEntry($rel); $s = $f.OpenRead(); $d = $e.Open(); $s.CopyTo($d); $d.Dispose(); $s.Dispose()
   }
   $a.Dispose()
   ```

3. Коммит и пуш:

   ```powershell
   git add -A
   git commit -m "UDIM Textures X.Y.Z"
   git push
   ```

4. Тег + релиз с новым архивом (шаги 4–5), старый архив в релизах удалять не нужно.

## 8. Если понадобится GitHub CLI (необязательно)

`gh` на машине не установлен. Если захочешь делать релизы одной командой:

```powershell
winget install --id GitHub.cli
gh auth login
gh release create v1.2.1 "finals/udim_texture-v1.2.1.zip" --title "UDIM Textures 1.2.1" --notes "см. README"
```

## Частые ошибки

| Симптом | Причина | Решение |
|---|---|---|
| `remote origin already exists` | remote уже добавлен | `git remote set-url origin <ссылка>` |
| `Authentication failed` при push | вместо пароля нужен токен | создать Personal Access Token, вставить как пароль |
| `src refspec main does not match any` | локальная ветка называется иначе | `git branch -M main`, затем `git push -u origin main` |
| в релиз не прикрепляется архив | файл занят/не выбран | перетащить zip в поле Attach binaries или выбрать через «browse» |
| Godot не видит плагин после распаковки | архив распакован внутрь `addons/` | распаковать в корень проекта, чтобы получилось `<проект>/addons/udim_texture/plugin.cfg` |
