#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <DHT.h>
#include <SoftwareSerial.h>
#include <Wire.h>

// Wiring:
// OLED SSD1306 I2C: SDA -> A4, SCL -> A5, VCC -> 5V, GND -> GND
// HW-507/KY-015/DHT11: S -> D3, + -> 5V, - -> GND
// HW-483 button: S -> D2, + -> 5V, - -> GND
// HM-10 BLE: TXD -> D11, RXD -> D12 through a voltage divider, GND -> GND, VCC -> 5V/3.3V per module board

constexpr byte BUTTON_PIN = 2;
constexpr byte DHT_PIN = 3;
constexpr byte BLE_RX_PIN = 11;  // Arduino receives from HM-10 TXD.
constexpr byte BLE_TX_PIN = 12;  // Arduino transmits to HM-10 RXD.

constexpr byte DHT_TYPE = DHT11;
constexpr bool BUTTON_ACTIVE_HIGH = true;
constexpr unsigned long LONG_PRESS_MS = 900;
constexpr unsigned long DEBOUNCE_MS = 35;
constexpr unsigned long SENSOR_INTERVAL_MS = 2200;
constexpr unsigned long BLE_INTERVAL_MS = 1000;
constexpr unsigned long PET_DECAY_INTERVAL_MS = 30000;

constexpr byte SCREEN_WIDTH = 128;
constexpr byte SCREEN_HEIGHT = 64;
constexpr int OLED_RESET = -1;
constexpr byte OLED_ADDRESS = 0x3C;

DHT dht(DHT_PIN, DHT_TYPE);
SoftwareSerial ble(BLE_RX_PIN, BLE_TX_PIN);
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

enum ScreenMode : byte {
  SCREEN_CLIMATE,
  SCREEN_PET,
  SCREEN_CLOCK,
};

ScreenMode screenMode = SCREEN_CLIMATE;

float temperatureC = NAN;
float humidityPercent = NAN;
byte hunger = 76;
byte happiness = 82;

bool lastRawPressed = false;
bool debouncedPressed = false;
bool longPressHandled = false;
unsigned long lastButtonChangeMs = 0;
unsigned long pressStartedMs = 0;
unsigned long lastSensorMs = 0;
unsigned long lastBleMs = 0;
unsigned long lastPetDecayMs = 0;

bool clockSynced = false;
int clockYear = 2026;
byte clockMonth = 1;
byte clockDay = 1;
byte clockHour = 0;
byte clockMinute = 0;
byte clockSecond = 0;
unsigned long clockSyncMs = 0;

char commandBuffer[80];
byte commandLength = 0;

void setup() {
  pinMode(BUTTON_PIN, INPUT);
  Serial.begin(9600);
  ble.begin(9600);
  dht.begin();

  if (!display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDRESS)) {
    Serial.println(F("SSD1306 init failed"));
  } else {
    display.clearDisplay();
    display.setTextColor(SSD1306_WHITE);
    display.setTextSize(1);
    display.setCursor(0, 0);
    display.println(F("Arduino Pet Link"));
    display.println(F("Waiting for data..."));
    display.display();
  }

  sendSnapshot();
}

void loop() {
  const unsigned long now = millis();

  handleButton(now);
  handleBleInput();

  if (now - lastSensorMs >= SENSOR_INTERVAL_MS) {
    lastSensorMs = now;
    readSensor();
    drawCurrentScreen();
  }

  if (now - lastPetDecayMs >= PET_DECAY_INTERVAL_MS) {
    lastPetDecayMs = now;
    decayPet();
    drawCurrentScreen();
  }

  if (now - lastBleMs >= BLE_INTERVAL_MS) {
    lastBleMs = now;
    sendSnapshot();
  }
}

void handleButton(unsigned long now) {
  const bool rawPressed = isButtonPressed();

  if (rawPressed != lastRawPressed) {
    lastRawPressed = rawPressed;
    lastButtonChangeMs = now;
  }

  if (now - lastButtonChangeMs < DEBOUNCE_MS || rawPressed == debouncedPressed) {
    return;
  }

  debouncedPressed = rawPressed;

  if (debouncedPressed) {
    pressStartedMs = now;
    longPressHandled = false;
    return;
  }

  const unsigned long pressMs = now - pressStartedMs;
  if (!longPressHandled && pressMs < LONG_PRESS_MS) {
    feedPet();
  }
}

bool isButtonPressed() {
  const bool high = digitalRead(BUTTON_PIN) == HIGH;
  return BUTTON_ACTIVE_HIGH ? high : !high;
}

void handleBleInput() {
  while (ble.available() > 0) {
    const char c = static_cast<char>(ble.read());
    if (c == '\n' || c == '\r') {
      if (commandLength > 0) {
        commandBuffer[commandLength] = '\0';
        handleCommand(commandBuffer);
        commandLength = 0;
      }
      continue;
    }

    if (commandLength < sizeof(commandBuffer) - 1) {
      commandBuffer[commandLength++] = c;
    }
  }

  if (debouncedPressed && !longPressHandled && millis() - pressStartedMs >= LONG_PRESS_MS) {
    nextScreen();
    longPressHandled = true;
  }
}

void handleCommand(const char* command) {
  if (strcmp(command, "FEED") == 0) {
    feedPet();
    return;
  }

  if (strcmp(command, "SCREEN:NEXT") == 0) {
    nextScreen();
    return;
  }

  if (strncmp(command, "TIME:", 5) == 0) {
    syncClock(command + 5);
    drawCurrentScreen();
  }
}

void readSensor() {
  const float newHumidity = dht.readHumidity();
  const float newTemperature = dht.readTemperature();

  if (!isnan(newHumidity)) {
    humidityPercent = newHumidity;
  }
  if (!isnan(newTemperature)) {
    temperatureC = newTemperature;
  }
}

void feedPet() {
  hunger = constrain(hunger + 18, 0, 100);
  happiness = constrain(happiness + 8, 0, 100);
  drawCurrentScreen();
  sendSnapshot();
}

void decayPet() {
  hunger = hunger > 0 ? hunger - 1 : 0;
  if (hunger < 35) {
    happiness = happiness > 1 ? happiness - 2 : 0;
  } else if (happiness > 0) {
    happiness--;
  }
}

void nextScreen() {
  screenMode = static_cast<ScreenMode>((screenMode + 1) % 3);
  drawCurrentScreen();
  sendSnapshot();
}

void drawCurrentScreen() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(0, 0);

  switch (screenMode) {
    case SCREEN_CLIMATE:
      drawClimateScreen();
      break;
    case SCREEN_PET:
      drawPetScreen();
      break;
    case SCREEN_CLOCK:
      drawClockScreen();
      break;
  }

  display.display();
}

void drawClimateScreen() {
  display.println(F("Climate"));
  display.drawLine(0, 10, 127, 10, SSD1306_WHITE);
  display.setTextSize(2);
  display.setCursor(0, 18);
  if (isnan(temperatureC)) {
    display.print(F("--.-"));
  } else {
    display.print(temperatureC, 1);
  }
  display.println(F(" C"));

  display.setCursor(0, 43);
  if (isnan(humidityPercent)) {
    display.print(F("--"));
  } else {
    display.print(humidityPercent, 0);
  }
  display.println(F(" %"));
}

void drawPetScreen() {
  display.println(F("Tamagotchi"));
  display.drawCircle(64, 32, 18, SSD1306_WHITE);
  display.fillCircle(58, 27, 2, SSD1306_WHITE);
  display.fillCircle(70, 27, 2, SSD1306_WHITE);

  if (hunger < 30 || happiness < 30) {
    display.drawLine(56, 40, 72, 36, SSD1306_WHITE);
  } else {
    display.drawLine(56, 37, 60, 41, SSD1306_WHITE);
    display.drawLine(60, 41, 68, 41, SSD1306_WHITE);
    display.drawLine(68, 41, 72, 37, SSD1306_WHITE);
  }

  display.setCursor(0, 52);
  display.print(F("Food "));
  display.print(hunger);
  display.print(F("%  Mood "));
  display.print(happiness);
  display.print(F("%"));
}

void drawClockScreen() {
  display.println(F("Clock"));
  display.drawLine(0, 10, 127, 10, SSD1306_WHITE);

  int year;
  byte month;
  byte day;
  byte hour;
  byte minute;
  byte second;
  getClock(year, month, day, hour, minute, second);

  display.setTextSize(2);
  display.setCursor(0, 19);
  printTwoDigits(display, hour);
  display.print(F(":"));
  printTwoDigits(display, minute);
  display.print(F(":"));
  printTwoDigits(display, second);

  display.setTextSize(1);
  display.setCursor(0, 47);
  if (!clockSynced) {
    display.print(F("Sync from app"));
  } else {
    printTwoDigits(display, day);
    display.print(F("."));
    printTwoDigits(display, month);
    display.print(F("."));
    display.print(year);
  }
}

void sendSnapshot() {
  ble.print(F("{\"temp\":"));
  printFloatOrNull(ble, temperatureC, 1);
  ble.print(F(",\"hum\":"));
  printFloatOrNull(ble, humidityPercent, 0);
  ble.print(F(",\"hunger\":"));
  ble.print(hunger);
  ble.print(F(",\"happy\":"));
  ble.print(happiness);
  ble.print(F(",\"screen\":\""));
  ble.print(screenName());
  ble.println(F("\"}"));
}

const char* screenName() {
  switch (screenMode) {
    case SCREEN_CLIMATE:
      return "climate";
    case SCREEN_PET:
      return "pet";
    case SCREEN_CLOCK:
      return "clock";
  }
  return "unknown";
}

void printFloatOrNull(Stream& stream, float value, byte digits) {
  if (isnan(value)) {
    stream.print(F("null"));
  } else {
    stream.print(value, digits);
  }
}

void syncClock(const char* iso) {
  int year;
  int month;
  int day;
  int hour;
  int minute;
  int second;

  if (sscanf(iso, "%d-%d-%dT%d:%d:%d", &year, &month, &day, &hour, &minute, &second) == 6) {
    clockYear = year;
    clockMonth = constrain(month, 1, 12);
    clockDay = constrain(day, 1, 31);
    clockHour = constrain(hour, 0, 23);
    clockMinute = constrain(minute, 0, 59);
    clockSecond = constrain(second, 0, 59);
    clockSyncMs = millis();
    clockSynced = true;
  }
}

void getClock(int& year, byte& month, byte& day, byte& hour, byte& minute, byte& second) {
  year = clockYear;
  month = clockMonth;
  day = clockDay;
  hour = clockHour;
  minute = clockMinute;
  second = clockSecond;

  if (!clockSynced) {
    return;
  }

  unsigned long elapsed = (millis() - clockSyncMs) / 1000UL;
  second += elapsed % 60UL;
  elapsed /= 60UL;
  minute += elapsed % 60UL;
  elapsed /= 60UL;
  hour += elapsed % 24UL;
  elapsed /= 24UL;

  if (second >= 60) {
    second -= 60;
    minute++;
  }
  if (minute >= 60) {
    minute -= 60;
    hour++;
  }
  if (hour >= 24) {
    hour -= 24;
    elapsed++;
  }

  while (elapsed > 0) {
    day++;
    if (day > daysInMonth(year, month)) {
      day = 1;
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }
    elapsed--;
  }
}

byte daysInMonth(int year, byte month) {
  static const byte days[] = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
  if (month == 2 && isLeapYear(year)) {
    return 29;
  }
  return days[month - 1];
}

bool isLeapYear(int year) {
  return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
}

void printTwoDigits(Print& printer, int value) {
  if (value < 10) {
    printer.print(F("0"));
  }
  printer.print(value);
}
