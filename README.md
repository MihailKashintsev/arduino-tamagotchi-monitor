# RenPet

RenPet is a Bluetooth Tamagotchi/weather station built with Arduino Nano, HM-10 BLE, DHT11, LCD 1602 I2C, and a Flutter app for Android and macOS.

Repository: <https://github.com/MihailKashintsev/arduino-tamagotchi-monitor>

Latest release: <https://github.com/MihailKashintsev/arduino-tamagotchi-monitor/releases/latest>

## Русский

### Что нужно

- Arduino Nano.
- LCD 1602 с I2C-контроллером, обычно адрес `0x27` или `0x3F`.
- Датчик HW-507 / KY-015 / DHT11.
- Кнопка HW-483.
- Bluetooth LE модуль HM-10.
- Провода Dupont.
- USB-кабель для Arduino Nano.
- Android-телефон или Mac для приложения RenPet.

### Сборка схемы

| Модуль | Подключение к Arduino Nano |
| --- | --- |
| LCD 1602 I2C | `SDA -> A4`, `SCL -> A5`, `VCC -> 5V`, `GND -> GND` |
| HW-507 / DHT11 | `S -> D3`, `+ -> 5V`, `- -> GND` |
| HW-483 кнопка | `S -> D2`, `+ -> 5V`, `- -> GND` |
| HM-10 BLE | `TXD -> D11`, `RXD -> D12 через делитель напряжения`, `VCC -> 5V/3.3V по вашей плате`, `GND -> GND` |

Важно: вход `RXD` у многих HM-10 рассчитан на 3.3V. Arduino Nano на `D12` выдает 5V, поэтому лучше поставить делитель напряжения между `D12` и `RXD` HM-10. Рабочий вариант: `D12 -> 1 kOhm -> RXD`, а от `RXD -> 2 kOhm -> GND`. `TXD` HM-10 можно подключать напрямую к `D11` Arduino.

Кнопка в текущем скетче работает как active-high: при нажатии на `D2` должен приходить `HIGH`. Если ваша кнопка работает наоборот, поменяйте в скетче `BUTTON_ACTIVE_HIGH` на `false`.

### Установка прошивки Arduino

1. Скачайте свежий скетч: [RenPet-firmware.ino](https://github.com/MihailKashintsev/arduino-tamagotchi-monitor/releases/latest/download/RenPet-firmware.ino).
2. Откройте файл в Arduino IDE.
3. Установите библиотеку `DHT sensor library` через Library Manager.
4. Выберите плату `Arduino Nano`.
5. Выберите процессор. Чаще всего для клонов Nano нужен `ATmega328P (Old Bootloader)`.
6. Выберите USB-порт Arduino.
7. Нажмите Upload.

LCD-библиотеки ставить не нужно. Работа с LCD 1602 I2C уже встроена в скетч через `Wire`. Адреса `0x27` и `0x3F` проверяются автоматически.

Альтернативно можно скачать готовый HEX: [RenPet-Nano-old-bootloader.hex](https://github.com/MihailKashintsev/arduino-tamagotchi-monitor/releases/latest/download/RenPet-Nano-old-bootloader.hex). Он собран для Arduino Nano с old bootloader.

### Установка приложения

Android:

1. Скачайте APK: [RenPet-Android.apk](https://github.com/MihailKashintsev/arduino-tamagotchi-monitor/releases/latest/download/RenPet-Android.apk).
2. Откройте APK на телефоне.
3. Разрешите установку из неизвестного источника, если Android попросит.
4. Дайте приложению Bluetooth-разрешения.
5. Включите Bluetooth и подключитесь к HM-10 в списке устройств приложения.

macOS:

1. Скачайте архив: [RenPet-macOS.zip](https://github.com/MihailKashintsev/arduino-tamagotchi-monitor/releases/latest/download/RenPet-macOS.zip).
2. Распакуйте архив.
3. Откройте `RenPet.app`.
4. Если macOS блокирует запуск, откройте `System Settings -> Privacy & Security` и разрешите запуск приложения.
5. Дайте Bluetooth-разрешение.

### Обновление

В приложении откройте `Настройки -> Обновления -> Проверить обновления`. Приложение проверяет последний GitHub Release и открывает страницу загрузки.

Прямые ссылки на свежие файлы:

- [Страница последнего релиза](https://github.com/MihailKashintsev/arduino-tamagotchi-monitor/releases/latest)
- [RenPet-Android.apk](https://github.com/MihailKashintsev/arduino-tamagotchi-monitor/releases/latest/download/RenPet-Android.apk)
- [RenPet-macOS.zip](https://github.com/MihailKashintsev/arduino-tamagotchi-monitor/releases/latest/download/RenPet-macOS.zip)
- [RenPet-firmware.ino](https://github.com/MihailKashintsev/arduino-tamagotchi-monitor/releases/latest/download/RenPet-firmware.ino)
- [RenPet-Nano-old-bootloader.hex](https://github.com/MihailKashintsev/arduino-tamagotchi-monitor/releases/latest/download/RenPet-Nano-old-bootloader.hex)

Ограничение прошивки: Arduino Nano нельзя надежно прошить прямо через HM-10 с текущей схемой. Для обновления прошивки используйте USB и Arduino IDE/CLI. Обновление “по воздуху” потребовало бы отдельный OTA bootloader или дополнительную схему для сброса и программирования.

### Управление

- Короткое нажатие кнопки: покормить тамагочи.
- Удержание кнопки около 900 мс: переключить экран LCD между климатом, тамагочи, временем и погодой с телефона.
- Команда приложения `FEED`: покормить по Bluetooth.
- Команда приложения `TIME:<iso datetime>`: синхронизировать время.
- Команда приложения `WEATHER:<city>,<temperature>`: показать на LCD погоду, полученную приложением через интернет.

Arduino отправляет в приложение JSON примерно раз в секунду:

```json
{"temp":23.0,"hum":45,"hunger":90,"happy":88,"screen":"pet","fw":"1.2.0"}
```

HM-10 UART BLE:

- Service: `0000FFE0-0000-1000-8000-00805F9B34FB`
- Characteristic: `0000FFE1-0000-1000-8000-00805F9B34FB`

### Сборка приложения из исходников

```bash
flutter pub get
flutter run -d macos
flutter run -d android
```

Для сборки релизов используется GitHub Actions. Новый релиз создается тегом вида `v1.2.0`.

## English

### Required Parts

- Arduino Nano.
- LCD 1602 with an I2C backpack, usually address `0x27` or `0x3F`.
- HW-507 / KY-015 / DHT11 sensor.
- HW-483 button.
- HM-10 Bluetooth LE module.
- Dupont wires.
- USB cable for Arduino Nano.
- Android phone or Mac for the RenPet app.

### Wiring

| Module | Arduino Nano connection |
| --- | --- |
| LCD 1602 I2C | `SDA -> A4`, `SCL -> A5`, `VCC -> 5V`, `GND -> GND` |
| HW-507 / DHT11 | `S -> D3`, `+ -> 5V`, `- -> GND` |
| HW-483 button | `S -> D2`, `+ -> 5V`, `- -> GND` |
| HM-10 BLE | `TXD -> D11`, `RXD -> D12 through a voltage divider`, `VCC -> 5V/3.3V depending on your board`, `GND -> GND` |

Important: many HM-10 boards use a 3.3V `RXD` input. Arduino Nano outputs 5V on `D12`, so use a voltage divider between `D12` and HM-10 `RXD`. A common setup is `D12 -> 1 kOhm -> RXD`, and `RXD -> 2 kOhm -> GND`. HM-10 `TXD` can usually go directly to Arduino `D11`.

The current sketch expects the button to be active-high: pressing it should send `HIGH` to `D2`. If your button behaves the other way around, change `BUTTON_ACTIVE_HIGH` to `false` in the sketch.

### Installing Arduino Firmware

1. Download the latest sketch: [RenPet-firmware.ino](https://github.com/MihailKashintsev/arduino-tamagotchi-monitor/releases/latest/download/RenPet-firmware.ino).
2. Open it in Arduino IDE.
3. Install `DHT sensor library` from Library Manager.
4. Select `Arduino Nano`.
5. Select the processor. Most Nano clones use `ATmega328P (Old Bootloader)`.
6. Select the Arduino USB port.
7. Click Upload.

No LCD library is required. LCD 1602 I2C support is built into the sketch using Arduino `Wire`. The sketch automatically checks `0x27` and `0x3F`.

Alternatively, download the prebuilt HEX: [RenPet-Nano-old-bootloader.hex](https://github.com/MihailKashintsev/arduino-tamagotchi-monitor/releases/latest/download/RenPet-Nano-old-bootloader.hex). It is built for Arduino Nano with the old bootloader.

### Installing the App

Android:

1. Download the APK: [RenPet-Android.apk](https://github.com/MihailKashintsev/arduino-tamagotchi-monitor/releases/latest/download/RenPet-Android.apk).
2. Open the APK on your phone.
3. Allow installation from an unknown source if Android asks.
4. Grant Bluetooth permissions.
5. Turn Bluetooth on and connect to the HM-10 from the app device list.

macOS:

1. Download the archive: [RenPet-macOS.zip](https://github.com/MihailKashintsev/arduino-tamagotchi-monitor/releases/latest/download/RenPet-macOS.zip).
2. Unzip it.
3. Open `RenPet.app`.
4. If macOS blocks the app, open `System Settings -> Privacy & Security` and allow it.
5. Grant Bluetooth permission.

### Updating

In the app, open `Settings -> Updates -> Check for updates`. The app checks the latest GitHub Release and opens the download page.

Direct latest-file links:

- [Latest release page](https://github.com/MihailKashintsev/arduino-tamagotchi-monitor/releases/latest)
- [RenPet-Android.apk](https://github.com/MihailKashintsev/arduino-tamagotchi-monitor/releases/latest/download/RenPet-Android.apk)
- [RenPet-macOS.zip](https://github.com/MihailKashintsev/arduino-tamagotchi-monitor/releases/latest/download/RenPet-macOS.zip)
- [RenPet-firmware.ino](https://github.com/MihailKashintsev/arduino-tamagotchi-monitor/releases/latest/download/RenPet-firmware.ino)
- [RenPet-Nano-old-bootloader.hex](https://github.com/MihailKashintsev/arduino-tamagotchi-monitor/releases/latest/download/RenPet-Nano-old-bootloader.hex)

Firmware limitation: Arduino Nano cannot be safely flashed through HM-10 with the current wiring. Use USB and Arduino IDE/CLI for firmware updates. True over-the-air flashing would require a custom OTA bootloader or extra reset/programming hardware.

### Controls

- Short button press: feed the Tamagotchi.
- Hold the button for about 900 ms: switch the LCD screen between climate, pet, clock, and phone weather.
- App command `FEED`: feed remotely.
- App command `TIME:<iso datetime>`: sync clock from phone/Mac.
- App command `WEATHER:<city>,<temperature>`: show phone-provided weather on the LCD.

Arduino sends this JSON payload about once per second:

```json
{"temp":23.0,"hum":45,"hunger":90,"happy":88,"screen":"pet","fw":"1.2.0"}
```

HM-10 UART BLE:

- Service: `0000FFE0-0000-1000-8000-00805F9B34FB`
- Characteristic: `0000FFE1-0000-1000-8000-00805F9B34FB`

### Building the App From Source

```bash
flutter pub get
flutter run -d macos
flutter run -d android
```

GitHub Actions builds release assets. Push a tag like `v1.2.0` to create a new release.
