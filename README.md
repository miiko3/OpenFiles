# OpenFiles

<p align="center">
  <a href="#english">English</a> · <a href="#установка">Установка</a> · <a href="#что-умеет">Возможности</a> · <a href="#автор">Автор</a>
</p>

Файловый менеджер и редактор для Android, который открывает и правит файлы **прямо в памяти устройства**. Никаких копий в приватном хранилище: всё читается и записывается в выданную вами папку.

Приложение полностью работает офлайн. Без рекламы, без телеметрии, без аккаунтов.

<p align="center">
  <img src="docs/screenshots/browser-documents.png" width="200" alt="Проводник">
  <img src="docs/screenshots/editor-word.png" width="200" alt="Редактор документов">
  <img src="docs/screenshots/editor-sheet.png" width="200" alt="Редактор таблиц">
</p>
<p align="center">
  <img src="docs/screenshots/editor-slides.png" width="200" alt="Редактор презентаций">
  <img src="docs/screenshots/viewer-markdown.png" width="200" alt="Просмотр Markdown">
  <img src="docs/screenshots/browser-text-code.png" width="200" alt="Тёмная тема">
</p>

---

## Установка

Скачайте APK из [последнего релиза](https://github.com/miiko3/OpenFiles/releases/latest) и разрешите установку из неизвестных источников.

| Файл | Для чего |
|---|---|
| `OpenFiles-<версия>-arm64-v8a.apk` | современные телефоны, **большинство устройств** |
| `OpenFiles-<версия>-armeabi-v7a.apk` | старые 32-разрядные устройства |
| `OpenFiles-<версия>-x86_64.apk` | эмуляторы и планшеты на Intel/AMD |

Требуется Android 7.0 (API 24) или новее.

---

## Что умеет

**Открывает любые файлы** — от Word и Excel до шрифтов и архивов. Неизвестный формат не приводит к ошибке: он открывается в hex-просмотре с поиском по байтам.

**Редактирует документы** — `.docx`, `.odt`, `.xlsx`, `.pptx` читаются и записываются собственными кодеками. Файл перезаписывается на месте, новый документ не создаётся.

**Аннотирует PDF** — выделение, подчёркивание, зачёркивание, заметки и рисование поверх страницы.

**Показывает презентации во весь экран** — слайд занимает весь дисплей в редакторе, а полноэкранный показ запускается одним нажатием.

**Открывает изображения** — просмотр с зумом, разбор архивов с предпросмотром содержимого.

<p align="center">
  <img src="docs/screenshots/settings-dark.png" width="200" alt="Настройки">
  <img src="docs/screenshots/help-instructions.png" width="200" alt="Инструкция">
</p>

---

## Попробовать без своих файлов

В репозитории лежит набор демонстрационных файлов — папка `docs/demo/` собрана **теми же кодеками**, которыми пользуется приложение, поэтому каждый файл заведомо открывается корректно:

```
docs/demo/
├── Документы/
│   ├── Отчёт за квартал.docx   заголовок, абзацы, список, таблица
│   ├── Бюджет.xlsx             формулы SUM, жирные строки, числа
│   ├── Презентация.pptx        текст, фигуры, таблица, переходы
│   ├── Счёт.pdf                счёт с таблицей, встроенными шрифтами и кириллицей
│   └── Инструкция.txt
├── Текст и код/
│   ├── Заметки.md              Markdown с заголовками и списками
│   ├── Данные.csv
│   ├── config.json
│   ├── main.dart
│   └── Служебная.txt
├── Изображения/
│   └── Обложка.png
└── Архивы/
    └── Резервная копия.zip
```

Скопируйте папку на телефон и выдайте приложению к ней доступ — всё содержимое откроется и отредактируется.

---

## Поддерживаемые форматы

| Категория | Форматы |
|---|---|
| Текстовые документы | `docx` `docm` `dotx` `odt` `rtf` `doc` |
| Таблицы | `xlsx` `xlsm` `xltx` `ods` `xls` `numbers` |
| Презентации | `pptx` `pptm` `potx` `odp` `ppt` |
| PDF | `pdf` |
| Текст | `txt` `log` `md` `markdown` `mdx` |
| Данные | `csv` `tsv` |
| Код | `json` `dart` `js` `jsx` `ts` `tsx` `py` `rb` `go` `rs` `java` `kt` `c` `h` `cpp` `cs` `swift` `php` `sh` `bash` `ps1` `bat` `sql` `html` `css` `scss` `xml` `yaml` `toml` `ini` `gradle` `cmake` `lua` `vue` `svelte` |
| Изображения | `png` `jpg` `jpeg` `gif` `webp` `bmp` `heic` `heif` `ico` `tif` `svg` `avif` |
| Архивы | `zip` `rar` `7z` `tar` `gz` `bz2` `xz` `zst` `apk` `iso` `jar` |
| Электронные книги | `epub` `mobi` `azw` `azw3` `fb2` |
| Шрифты | `ttf` `otf` `woff` `woff2` |

---

## Выдача доступа к файлам

Android не позволяет приложениям читать файлы без явного разрешения. При первом запуске OpenFiles открывает системный выбор папки.

**Важно для Android 11 и новее.** Системное окно не даёт выдать доступ на корень хранилища и на папку `Download` целиком — она считается слишком широкой. Нужно зайти внутрь неё и создать подпапку:

1. Откройте системный выбор папки.
2. Перейдите в `Download`.
3. Нажмите «Новая папка» и создайте, например, `OpenFiles`.
4. Войдите в неё и подтвердите «Использовать эту папку».
5. Разрешите доступ в системном диалоге.

После этого папка сохраняется в приложении, и к ней можно вернуться в любой момент.

Открыть файл из другого приложения тоже можно: установите OpenFiles приложением по умолчанию для нужных типов файлов или используйте «Отправить в» в контекстном меню.

---

## Интерфейс

**Проводник.** Список и сетка, поиск по текущей папке, четыре варианта сортировки, показ скрытых файлов, переключатель «только поддерживаемые». Долгое нажатие открывает меню: переименовать, удалить, свойства, поделиться. Кнопки создания файла и папки — в правом нижнем углу.

**Документы.** Панель снизу меняет выделенный текст: полужирный, курсив, подчёркивание, зачёркивание, размер, цвет, четыре варианта выравнивания, маркированные и нумерованные списки, шесть уровней заголовков, таблицы, линии и разрывы страниц. Есть поиск с заменой, подсчёт слов, настройка полей и ориентации страницы, экспорт в PDF, отмена и повтор действий.

**Таблицы.** Сетка с закреплёнными заголовками строк и столбцов, строка формул, навигация стрелками и Tab. Работают формулы: `SUM` `AVERAGE` `MIN` `MAX` `COUNT` `IF` `IFS` `SUMIF` `COUNTIF` `VLOOKUP` `INDEX` `MATCH` `ROUND` `CONCATENATE` `LEFT` `RIGHT` `LEN` `TODAY` и многие другие. Форматирование ячеек, восемь числовых форматов, вставка и удаление строк и столбцов, сортировка, закрепление областей, копирование и вставка, экспорт в CSV и PDF.

**Презентации.** Миниатюры слайдов слева, холст в центре, свойства объекта справа. Фигуры, надписи, таблицы, изменение размера, поворота, цвета и шрифта. Переходы между слайдами, заметки докладчика, экспорт в PDF и полноэкранный показ с таймером и предпросмотром следующего слайда.

**PDF.** Масштабирование, перелистывание, семь инструментов аннотаций и выбор цвета метки.

**Настройки.** Тема, размер текста интерфейса, показ скрытых файлов, порядок сортировки, ширина страницы, масштаб, автосохранение, язык интерфейса и список папок доступа.

**Инструкция** доступна прямо в приложении: кнопка со знаком вопроса в правом верхнем углу проводника.

---

## Оформление

Скруглённые формы повсюду, тёплая приглушённая палитра. Светлая и тёмная темы используют одни и те же оттенки — терракота, шалфей, бронза и тёплый крем. Переключение темы: настройки или кнопка в шапке экрана инструкции.

---

## Технологии

Flutter и Dart. Форматы Office разбираются и собираются вручную поверх `archive` и `xml`, без готовых офисных библиотек, поэтому поведение полностью предсказуемо и не зависит от чужих лицензий.

Доступ к файлам реализован через Storage Access Framework: нативный мост на Kotlin поверх `DocumentsContract`. Форматы сопоставляются по расширению, MIME-типы не требуются.

---

## Сборка

Нужен Flutter SDK и Android SDK.

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-per-abi
```

Готовые APK появятся в `build/app/outputs/flutter-apk/`. Установка на устройство:

```bash
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Сборка подписывается ключом из `android/key.properties`. Если файла нет, используется отладочная подпись — она годится только для личной установки.

Серверные сборки выполняются в GitHub Actions: каждый push в `main` и каждый тег `v*` собирает APK и публикует релиз.

Пересобрать демонстрационные файлы из `docs/demo/`:

```bash
OPENFILES_DEMO_OUT=docs/demo flutter test test/make_demo_test.dart
```

Без переменной окружения файлы собираются в `build/demo` и не затрагивают репозиторий.

---

## English

**OpenFiles** is a file manager and editor for Android that opens and saves files **directly in device storage**. Nothing is copied into private app storage — every read and write goes to the folder you granted.

Works fully offline. No ads, no tracking, no accounts. The interface is available in Russian and English.

### Install

Download the APK from the [latest release](https://github.com/miiko3/OpenFiles/releases/latest) and allow installation from unknown sources.

| File | Use it on |
|---|---|
| `OpenFiles-<version>-arm64-v8a.apk` | modern phones, **most devices** |
| `OpenFiles-<version>-armeabi-v7a.apk` | older 32-bit devices |
| `OpenFiles-<version>-x86_64.apk` | emulators and Intel/AMD tablets |

Requires Android 7.0 (API 24) or newer.

### What it does

- **Opens any file** — Word, OpenDocument, Excel, PDF, images, archives, fonts and e-books. Unknown formats open in a hex viewer with byte search instead of throwing an error.
- **Edits documents** — `.docx`, `.xlsx` and `.pptx` are read and written by built-in OOXML codecs. The original file is overwritten, no copy is created.
- **Annotates PDFs** — highlight, underline, strikethrough, notes and freehand drawing.
- **Shows presentations full screen** — the slide takes the whole display in the editor, and a fullscreen presenter is one tap away.

### Granting access

Android does not let apps read files without explicit permission, so OpenFiles asks for a folder on first launch.

**Important on Android 11 and newer.** The system picker refuses access to the storage root and to the `Download` folder as a whole. Create a subfolder inside it:

1. Open the system folder picker.
2. Enter `Download`.
3. Tap the create-folder button and make a folder, for example `OpenFiles`.
4. Enter it and confirm "Use this folder".
5. Allow access in the system dialog.

The folder is remembered, so you only do this once. You can also open a file from another app by setting OpenFiles as the default handler or using "Send to" in the context menu.

### Try it without your own files

The `docs/demo/` folder in this repository holds sample files built with the same codecs the app uses, so every one of them is known to open correctly: a DOCX report, an XLSX budget with formulas, a PPTX deck, a PDF invoice with embedded fonts, Markdown, CSV, JSON, Dart, a PNG and a ZIP. Copy the folder to your phone, grant access, and open everything.

### Privacy

OpenFiles has no account system, no ads and no analytics. It never requests full storage access — it only reads and writes inside the folder you selected.

---

## Автор

Проект открытый. Код, замечания и предложения — в репозитории miiko3.

- GitHub — <https://github.com/miiko3?tab=repositories>
- Telegram — <https://t.me/yetilov>
- Boosty — <https://boosty.to/miilo3>
- YooMoney — <https://yoomoney.ru/fundraise/1GJCNQ28KCK.260319>

Приложение бесплатное и без рекламы. Если оно оказалось полезным, поддержать разработку можно по ссылкам выше.

---

## Лицензия

MIT.