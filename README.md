# Ergohaven ZMK Config

ZMK-конфигурация для клавиатур Ergohaven (Velvet v3 и др.).

## Требования

- Docker
- bash

## Структура

```
config/              # keymap и конфигурационные файлы
  velvet_v3.keymap       # базовый keymap
  velvet_v3_ruen.keymap  # keymap с двумя слоями (EN/RU) и комбо переключения
  velvet_v3.conf         # Kconfig
  keys_ru.h              # определения русских клавиш
firmware/            # собранные .uf2 прошивки (создается при сборке)
build.sh             # скрипт сборки
```

## Сборка

Сборка выполняется в Docker-контейнере (`zmkfirmware/zmk-build-arm:stable`). При первом запуске автоматически инициализируется west workspace.

### Сборка по умолчанию

```bash
./build.sh
```

Собирает только targets из `DEFAULT_TARGETS`: `velvet_v3_left_ruen` и `velvet_v3_right`.

### Сборка конкретных targets

```bash
./build.sh velvet_v3_left_ruen
./build.sh velvet_v3_left velvet_v3_right
./build.sh settings_reset
```

### Доступные targets

```bash
./build.sh --list
```

| Target | Shield | Keymap | Описание |
|--------|--------|--------|----------|
| `velvet_v3_left` | velvet_v3_left | velvet_v3 (базовый) | Левая половина, стандартный keymap |
| `velvet_v3_left_ruen` | velvet_v3_left | velvet_v3_ruen | Левая половина, EN/RU keymap |
| `velvet_v3_right` | velvet_v3_right | velvet_v3 (базовый) | Правая половина |
| `velvet_v3_qube` | velvet_v3_qube | velvet_v3 (базовый) | Qube донгл |
| `velvet_v3_qube_ruen` | velvet_v3_qube | velvet_v3_ruen | Qube донгл, EN/RU keymap |
| `velvet_v3_left_qube` | velvet_v3_left_qube | velvet_v3 (базовый) | Левая половина для Qube |
| `settings_reset` | settings_reset | — | Сброс настроек |

### Другие команды

```bash
./build.sh --init      # инициализировать west workspace без сборки
./build.sh --clean     # удалить директории сборки и firmware
./build.sh --help      # справка
```

## Прошивка

Собранные файлы находятся в `firmware/`:

1. Подключить клавиатуру по USB
2. Перевести в режим загрузчика (двойное нажатие кнопки reset)
3. Скопировать `.uf2` файл на появившийся USB-диск

Для Velvet v3 с EN/RU keymap:
- Левая половина: `firmware/velvet_v3_left_ruen-ergohaven-zmk.uf2`
- Правая половина: `firmware/velvet_v3_right.uf2`
