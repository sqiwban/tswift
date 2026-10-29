# TSwift: проверка Linux → iPhone

Минимальное нативное приложение на Swift и SwiftUI: текст «Счётчик: 0» и кнопка «Увеличить». Нажатие увеличивает число на один. После завершения процесса счётчик сбрасывается. Функциональность основного продукта пока не добавляется.

Целевое устройство: физический iPhone с iOS 16.0 или новее, архитектура arm64. Bundle ID до локальной переподписи: `com.sqiwban.tswift`. Версия приложения: `0.1.0 (1)`.

## Проверенные инструменты

Проверка Linux-окружения 29 октября 2026 года:

| Инструмент | Результат |
| --- | --- |
| ios-builder (`builder --version`) | v0.11.0 |
| MobAI desktop (`dpkg-query --show mobai`) | 3.5.1-1 |
| Git | 2.53.0 |
| Homebrew | 7.0.11 |
| Python | 3.14.4 |
| Swift, Xcode, XcodeGen, GitHub CLI (`gh`) | Локально отсутствуют; для запуска через builder не нужны |

В успешном запуске CI фактически проверены Xcode 26.3 (17C529), Apple Swift 6.2.4, iPhoneOS SDK 26.2 и XcodeGen 2.46.0. Архив XcodeGen проверяется по SHA-256 из официального релиза; GitHub Actions закреплены по полным commit SHA. Версии инструментов записываются в `build/tool-versions.txt` и артефакт `build-diagnostics`.

## Как устроена сборка

`project.yml` — исходная спецификация XcodeGen. В ней явно задана общая схема `TSwift`; `.xcodeproj` генерируется на macOS и не хранится в Git. Исходники приложения — в `TSwift/`, сторонних библиотек нет.

В установленной версии действительно выполнена команда:

```bash
builder init --project TSwift --ios-path . --scheme TSwift
```

Её результат сопоставлен с [шаблоном ios-builder v0.11.0](https://github.com/MobAI-App/ios-builder/blob/v0.11.0/internal/workflow/templates/ios-build.yml). Шаблон уже поддерживает XcodeGen: ищет `project.yml` / `project.yaml` с `targets:` и при отсутствии `.xcodeproj` вызывает генерацию перед сборкой.

Наш `.github/workflows/ios-build.yml` сокращён до нативного unsigned-сценария. Сохранены необходимые для builder имя файла, `run-name`, входные параметры, загрузка снимка рабочего дерева и имя артефакта `ipa`. Вместо установки последнего XcodeGen через Homebrew вызывается `scripts/generate-project.sh` с фиксированной версией и контрольной суммой.

Затем `scripts/build-unsigned.sh` вызывает `xcodebuild` с `-sdk iphoneos`, `-destination 'generic/platform=iOS'`, `ARCHS=arm64`, `CODE_SIGNING_ALLOWED=NO` и `CODE_SIGNING_REQUIRED=NO`. Полученный `.app` проверяется и упаковывается в `Payload/TSwift.app` внутри IPA. Это сборка для устройства, не для симулятора. Для unsigned IPA не требуется `-exportArchive` или `ExportOptions.plist`.

CI отвергает включённую подпись и signing-профили. В workflow нет Apple Account, сертификатов, Apple-секретов, автоматического provisioning, TestFlight, App Store Connect или сторонних платных сервисов. Используется стандартный GitHub-hosted runner `macos-15`; расход минут определяется планом GitHub и видимостью репозитория, платные раннеры не подключены.

Повторный `builder init` перезапишет наш workflow стандартным: перед его применением нужно проверить diff и вернуть закреплённые инструменты и unsigned-проверки. Воспроизводимость здесь означает генерацию проекта из версии спецификации и фиксированные версии основных инструментов; GitHub обновляет образ `macos-15`, поэтому побайтовая идентичность IPA не гарантируется.

## Сборка с Linux

Если builder ещё не установлен, официальная команда Homebrew:

```bash
brew install mobai-app/tap/ios-builder
```

Первичная авторизация — только в GitHub:

```bash
cd /home/exxxept/projects/tswift
builder --version
builder auth github
builder auth status
```

Workflow должен быть закоммичен и отправлен в default branch репозитория `sqiwban/tswift`, GitHub Actions должны быть разрешены. Для нового клона первичная публикация подготовленных файлов:

```bash
git add .gitignore .github/workflows/ios-build.yml TSwift project.yml builder.json scripts README.md
git commit -m "Add minimal unsigned SwiftUI iPhone build"
git push -u origin main
```

После первоначальной настройки обычная сборка:

```bash
builder ios build --unsigned
```

Builder загружает снимок текущих файлов, включая незакоммиченные изменения с учётом `.gitignore`, запускает Actions и скачивает IPA в `dist/`. Workflow берётся из default branch: изменения самого workflow сначала нужно commit/push. Путь к конкретному IPA будет напечатан builder.

Альтернатива через поддерживаемый upstream механизм тегов, если GitHub API недоступен:

```bash
git tag ios-build/first-iphone
git push origin ios-build/first-iphone
```

Перед этим закоммитьте все нужные изменения. Тег запускает сборку именно своего коммита и удаляется workflow после завершения. IPA скачивается со страницы соответствующего запуска [GitHub Actions](https://github.com/sqiwban/tswift/actions/workflows/ios-build.yml), из артефакта `ipa`; для скачивания нужен вход в GitHub. Артефакт `build-diagnostics` содержит сгенерированный проект с общей схемой, версии инструментов и журнал сборки. Срок хранения обоих — 7 дней.

Для ручного повторения на macOS CI, из корня репозитория:

```bash
export DEVELOPER_DIR=/Applications/Xcode_26.3.app/Contents/Developer
bash scripts/generate-project.sh
bash scripts/build-unsigned.sh
```

Локальный Mac для основного сценария не требуется.

## Подпись и установка через MobAI

Unsigned IPA нельзя запустить непосредственно на iPhone: сначала нужна локальная переподпись. Согласно [документации ios-builder](https://github.com/MobAI-App/ios-builder#code-signing), MobAI может переподписать его при установке с бесплатным Apple Account.

1. Запустите MobAI desktop на Linux. Подключите разблокированный iPhone по USB, подтвердите «Доверять этому компьютеру» на телефоне. Устройство должно появиться в MobAI.
2. Если iPhone требует режим разработчика, включите его в «Настройки → Конфиденциальность и безопасность → Режим разработчика» и подтвердите перезагрузку. См. [инструкцию Apple](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device).
3. Проверьте связь с MobAI:

   ```bash
   builder mobai ping
   ```

4. Откройте установку IPA для выбранного iPhone в MobAI, укажите скачанный файл из `dist/` и выберите локальную переподпись своим бесплатным Apple Account. Пароль и коды 2FA вводите самостоятельно только в локальном диалоге MobAI. В репозиторий и GitHub Secrets их добавлять не нужно.
5. Если iOS запрашивает доверие разработчику, откройте «Настройки → Основные → VPN и управление устройством», выберите свой профиль и подтвердите доверие.
6. Запустите **TSwift** с домашнего экрана. Проверьте переход `0 → 1 → 2 → 3` после трёх нажатий.

Для уже подписанного локально IPA документирована команда установки через тот же MobAI API:

```bash
builder mobai install /полный/путь/к/локально-подписанному.ipa
```

Замените путь на фактический абсолютный путь к подписанному файлу; при нескольких устройствах используйте подтверждённый `builder mobai install --help` параметр `--device` с ID из MobAI. В v0.11.0 у этой команды нет флагов `--resign`, `--apple-id` или параметров пароля: она передаёт файл в MobAI. Проверено с MobAI 3.5.1: передача unsigned IPA этой командой не открывает диалог переподписи и завершается `ApplicationVerificationFailed / No code signature found`. Поэтому unsigned-файл из CI нужно устанавливать через интерфейс MobAI с явной переподписью, как описано выше.

После переподписи фактический Bundle ID может отличаться от исходного; если понадобится работа с установленным приложением по ID, возьмите его из MobAI. Для этого SwiftUI-приложения debugger и hot reload не требуются.

## Если Linux видит iPhone, а MobAI не видит

В этой среде обнаружен и устранён конфликт с автоматическим подключением iPhone как фотокамеры. Файловый менеджер через `gvfsd-gphoto2` удерживал USB в конфигурации PTP, а `usbmuxd` сообщал `Could not set configuration 4 ... LIBUSB_ERROR_BUSY`.

Проверенные команды диагностики:

```bash
lsusb
systemctl status usbmuxd --no-pager
journalctl -u usbmuxd -n 30 --no-pager
gio mount --list
builder mobai ping
```

Если подтверждён именно этот конфликт, закройте просмотр фотографий iPhone и отключите его монтирование как камеры через файловый менеджер. Эквивалентная команда — `gio mount --unmount '<URI iPhone из вывода gio mount --list>'`; используйте фактический URI своей камеры. Дождитесь освобождения подключения и выполните:

```bash
sudo systemctl restart usbmuxd
```

Системный пароль вводите в своём терминале или системном диалоге. Затем MobAI должен заново обнаружить устройство; при необходимости переподключите разблокированный iPhone. В этой сессии после освобождения камеры и перезапуска службы телефон появился в MobAI API и во встроенном установщике. Это исправление конкретного подтверждённого USB-конфликта; сама по себе успешная команда `builder mobai ping` подтверждает только доступность MobAI, а не наличие телефона.

## Обновление бесплатной подписи

[Apple указывает](https://developer.apple.com/help/account/basics/about-your-developer-account), что provisioning-профиль Personal Team действует 7 дней; одновременно допускается до трёх таких приложений на устройстве. MobAI bridge тоже может занимать место в этом лимите, если установлен через ваш Personal Team.

До истечения срока или после отказа запуска снова подключите iPhone к MobAI и повторите локальную переподпись и установку того же unsigned IPA тем же Apple Account. Если код не менялся, новую компиляцию запускать не нужно: обновляется подпись и provisioning. Если код изменился, сначала выполните `builder ios build --unsigned`, затем установите новый IPA. Пароль и 2FA снова вводите сами, если MobAI их запросит. Сохраните unsigned IPA локально: артефакты CI тоже истекают через 7 дней.

## Статус проверки

- Проверены актуальные upstream-документация и исходники ios-builder, локальные версии и реальные `--help` команд.
- Проверены JSON/YAML/plist, согласованность Bundle ID, описание общей схемы, синтаксис bash и workflow через actionlint 1.7.12.
- Проверены официальный архив XcodeGen 2.46.0, его структура и SHA-256.
- [Сборка GitHub Actions №40872396954](https://github.com/sqiwban/tswift/actions/runs/40872396954): окончательный статус `completed / success`. Вызвана с Linux через `builder ios build --unsigned`; генерация общей схемы и компиляция Xcode на macOS выполнены успешно.
- IPA скачан builder в `dist/TSwift-cddff3c1.ipa` (27 043 байта). На Linux повторно проверены целостность ZIP, iPhoneOS в Info.plist и arm64/platform iOS во всех трёх Mach-O файлах. В них отсутствует `LC_CODE_SIGNATURE`; в IPA нет provisioning-профиля и `_CodeSignature`.
- SHA-256 IPA: `f672d9d5ffaa64600d84aba3199a63c7c27a0e49c3bb121663e3c060cb4a1815`; совпадает с контрольной суммой CI. Диагностика скачана в `build/ci-evidence/`.
- Физический iPhone 14 с iOS 27.0 обнаружен MobAI по USB со статусом `ready`; устранён конфликт камеры PTP с usbmuxd.
- Проверено, что `builder mobai install` без локальной переподписи получает от iPhone отказ `No code signature found`.
- Локальная подпись бесплатным Apple Account, установка, доверие/режим разработчика, запуск и работа кнопки на вашем iPhone пока не подтверждены.

Этап завершён только после успешной CI-сборки и проверки счётчика на физическом iPhone. До этого функциональность основного продукта не добавляем.

Источники: [ios-builder v0.11.0](https://github.com/MobAI-App/ios-builder/tree/v0.11.0), [спецификация XcodeGen 2.46.0](https://github.com/yonaskolb/XcodeGen/blob/2.46.0/Docs/ProjectSpec.md), [релиз XcodeGen](https://github.com/yonaskolb/XcodeGen/releases/tag/2.46.0), [образ macOS 15](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md), [MobAI API](https://mobai.run/docs/).
