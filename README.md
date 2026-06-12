# Arduino Pet Link

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

Controls:

- Short button press: feed the Tamagotchi.
- Hold button for about 900 ms: switch screen.
- App command `FEED`: feed remotely.
- App command `TIME:<iso datetime>`: sync clock from phone/Mac.

BLE payload sent every second:

```json
{"temp":23.0,"hum":45,"hunger":90,"happy":88,"screen":"pet"}
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

## Notes

The first clock screen shows a sync prompt until the app connects and sends the current time. Arduino Nano has no RTC, so time resets after power loss.
