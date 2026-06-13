# RenPet

Flutter app for Android and macOS plus an Arduino Nano sketch for a small Bluetooth Tamagotchi/weather station.

## Hardware

Assumptions used by the sketch:

| Module | Arduino Nano pin |
| --- | --- |
| LCD 1602 I2C, address `0x27` or `0x3F` | `SDA -> A4`, `SCL -> A5`, `VCC`, `GND` |
| HW-507 / KY-015 / DHT11 | `S -> D3`, `+ -> 5V`, `- -> GND` |
| HW-483 button | `S -> D2`, `+ -> 5V`, `- -> GND` |
| HM-10 BLE module | `TXD -> D11`, `RXD -> D12`, `VCC`, `GND` |

Put a voltage divider or level shifter between Arduino `D12` and HM-10 `RXD` if your HM-10 board is not 5V tolerant.

## Arduino sketch

Open and upload:

```text
arduino/tamagotchi_station/tamagotchi_station.ino
```

Install these Arduino IDE libraries first:

- `DHT sensor library`

The LCD code is built into the sketch and uses only Arduino `Wire`, so no `LiquidCrystal_I2C`, `Adafruit SSD1306`, or `Adafruit GFX` library is needed. The sketch tries LCD I2C addresses `0x27` and `0x3F`. If the button works inverted, change `BUTTON_ACTIVE_HIGH` to `false`.

The LCD has no native Russian font, so the sketch draws the needed Cyrillic labels as custom 5x8 LCD glyphs. HD44780 LCDs can hold only 8 custom glyphs at once, so the sketch reloads the glyph set for each screen.

Controls:

- Short button press: feed the Tamagotchi.
- Hold button for about 900 ms: switch screen between climate, pet, clock, and phone weather.
- App command `FEED`: feed remotely.
- App command `TIME:<iso datetime>`: sync clock from phone/Mac.
- App command `WEATHER:<city>,<temperature>`: show phone-provided weather on the LCD.

BLE payload sent every second:

```json
{"temp":23.0,"hum":45,"hunger":90,"happy":88,"screen":"pet","fw":"1.2.0"}
```

The app expects the common HM-10 UART service/characteristic:

- Service: `0000FFE0-0000-1000-8000-00805F9B34FB`
- Characteristic: `0000FFE1-0000-1000-8000-00805F9B34FB`

## Flutter app

Install dependencies:

```bash
flutter pub get
```

Run on macOS:

```bash
flutter run -d macos
```

Run on Android:

```bash
flutter run -d android
```

The Android build includes Bluetooth LE permissions. The macOS build includes the Bluetooth entitlement and usage text.

The weather panel in the app uses Open-Meteo over the phone/Mac internet connection. Arduino does not connect to the internet; it only receives the city and temperature through HM-10 BLE.

## Releases and updates

GitHub Actions builds releases from tags named `v*`.

Each release contains:

- `RenPet-Android.apk`
- `RenPet-macOS.zip`
- `RenPet-firmware.ino`
- `RenPet-Nano-old-bootloader.hex`

The app can check the latest GitHub Release from the Settings screen and open the release page for downloading app and firmware assets.

Firmware note: Arduino Nano cannot be safely flashed through HM-10 with this wiring alone. Updating firmware from the app would require a custom OTA bootloader or extra reset/programming hardware. Use USB + Arduino IDE/CLI for the included `.ino` or `.hex` firmware asset.

## Notes

The first clock screen shows a sync prompt until the app connects and sends the current time. Arduino Nano has no RTC, so time resets after power loss.
