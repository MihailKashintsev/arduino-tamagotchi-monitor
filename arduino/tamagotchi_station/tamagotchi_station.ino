#include <DHT.h>
#include <SoftwareSerial.h>
#include <Wire.h>

// Wiring:
// LCD 1602 I2C: SDA -> A4, SCL -> A5, VCC -> 5V, GND -> GND
// HW-507/KY-015/DHT11: S -> D3, + -> 5V, - -> GND
// HW-483 button: S -> D2, + -> 5V, - -> GND
// HM-10 BLE: TXD -> D11, RXD -> D12 through a voltage divider, GND -> GND, VCC -> 5V/3.3V per module board

const char FIRMWARE_VERSION[] = "1.2.0";

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
constexpr unsigned long DISPLAY_INTERVAL_MS = 500;
constexpr unsigned long PET_DECAY_INTERVAL_MS = 30000;

constexpr byte LCD_COLS = 16;
constexpr byte LCD_ROWS = 2;
constexpr byte LCD_ADDRESS_PRIMARY = 0x27;
constexpr byte LCD_ADDRESS_FALLBACK = 0x3F;

class I2cLcd : public Print {
public:
  explicit I2cLcd(byte address) : address_(address) {}

  void setAddress(byte address) {
    address_ = address;
  }

  void begin() {
    delay(50);
    write4Bits(0x30);
    delayMicroseconds(4500);
    write4Bits(0x30);
    delayMicroseconds(4500);
    write4Bits(0x30);
    delayMicroseconds(150);
    write4Bits(0x20);

    command(0x28);  // 4-bit mode, 2 lines, 5x8 font.
    command(0x0C);  // Display on, cursor off.
    command(0x06);  // Increment cursor.
    clear();
  }

  void clear() {
    command(0x01);
    delayMicroseconds(2000);
  }

  void setCursor(byte col, byte row) {
    static const byte rowOffsets[] = {0x00, 0x40};
    if (row >= LCD_ROWS) {
      row = LCD_ROWS - 1;
    }
    command(0x80 | (col + rowOffsets[row]));
  }

  void createChar(byte location, const byte charmap[]) {
    location &= 0x07;
    command(0x40 | (location << 3));
    for (byte i = 0; i < 8; i++) {
      write(charmap[i]);
    }
    command(0x80);
  }

  size_t write(uint8_t value) override {
    send(value, true);
    return 1;
  }

private:
  byte address_;
  byte backlight_ = 0x08;

  void command(byte value) {
    send(value, false);
  }

  void send(byte value, bool rs) {
    const byte mode = rs ? 0x01 : 0x00;
    write4Bits((value & 0xF0) | mode);
    write4Bits(((value << 4) & 0xF0) | mode);
  }

  void write4Bits(byte value) {
    expanderWrite(value);
    pulseEnable(value);
  }

  void expanderWrite(byte value) {
    Wire.beginTransmission(address_);
    Wire.write(value | backlight_);
    Wire.endTransmission();
  }

  void pulseEnable(byte value) {
    expanderWrite(value | 0x04);
    delayMicroseconds(1);
    expanderWrite(value & ~0x04);
    delayMicroseconds(50);
  }
};

DHT dht(DHT_PIN, DHT_TYPE);
SoftwareSerial ble(BLE_RX_PIN, BLE_TX_PIN);
I2cLcd lcd(LCD_ADDRESS_PRIMARY);

const byte GLYPH_A[8] = {0x00, 0x0E, 0x01, 0x0F, 0x11, 0x0F, 0x00, 0x00};
const byte GLYPH_V[8] = {0x1E, 0x11, 0x11, 0x1E, 0x11, 0x11, 0x1E, 0x00};
const byte GLYPH_G[8] = {0x1F, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x00};
const byte GLYPH_D[8] = {0x07, 0x09, 0x09, 0x09, 0x09, 0x1F, 0x11, 0x00};
const byte GLYPH_E[8] = {0x00, 0x0E, 0x11, 0x1F, 0x10, 0x0E, 0x00, 0x00};
const byte GLYPH_ZH[8] = {0x15, 0x15, 0x0E, 0x04, 0x0E, 0x15, 0x15, 0x00};
const byte GLYPH_I[8] = {0x11, 0x13, 0x15, 0x15, 0x19, 0x11, 0x11, 0x00};
const byte GLYPH_L[8] = {0x07, 0x09, 0x09, 0x09, 0x11, 0x11, 0x11, 0x00};
const byte GLYPH_M[8] = {0x11, 0x1B, 0x15, 0x15, 0x11, 0x11, 0x11, 0x00};
const byte GLYPH_N[8] = {0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11, 0x00};
const byte GLYPH_O[8] = {0x00, 0x0E, 0x11, 0x11, 0x11, 0x0E, 0x00, 0x00};
const byte GLYPH_P[8] = {0x1F, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x00};
const byte GLYPH_R[8] = {0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10, 0x10, 0x00};
const byte GLYPH_T[8] = {0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x00};
const byte GLYPH_TS[8] = {0x12, 0x12, 0x12, 0x12, 0x1F, 0x01, 0x01, 0x00};
const byte GLYPH_YA[8] = {0x0F, 0x11, 0x11, 0x0F, 0x05, 0x09, 0x11, 0x00};

enum ScreenMode : byte {
  SCREEN_CLIMATE,
  SCREEN_PET,
  SCREEN_CLOCK,
  SCREEN_WEATHER,
};

ScreenMode screenMode = SCREEN_CLIMATE;

float temperatureC = NAN;
float humidityPercent = NAN;
byte hunger = 76;
byte happiness = 82;
bool lcdRussian = true;
bool weatherSynced = false;
char weatherCity[17] = "No city";
float weatherTempC = NAN;

bool lastRawPressed = false;
bool debouncedPressed = false;
bool longPressHandled = false;
unsigned long lastButtonChangeMs = 0;
unsigned long pressStartedMs = 0;
unsigned long lastSensorMs = 0;
unsigned long lastBleMs = 0;
unsigned long lastDisplayMs = 0;
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
  Wire.begin();
  dht.begin();

  lcd.setAddress(detectLcdAddress());
  lcd.begin();
  drawBootAnimation();

  sendSnapshot();
}

void loop() {
  const unsigned long now = millis();

  handleButton(now);
  handleBleInput();

  if (now - lastSensorMs >= SENSOR_INTERVAL_MS) {
    lastSensorMs = now;
    readSensor();
  }

  if (now - lastPetDecayMs >= PET_DECAY_INTERVAL_MS) {
    lastPetDecayMs = now;
    decayPet();
  }

  if (now - lastDisplayMs >= DISPLAY_INTERVAL_MS) {
    lastDisplayMs = now;
    drawCurrentScreen();
  }

  if (now - lastBleMs >= BLE_INTERVAL_MS) {
    lastBleMs = now;
    sendSnapshot();
  }
}

byte detectLcdAddress() {
  if (i2cAddressResponds(LCD_ADDRESS_PRIMARY)) {
    return LCD_ADDRESS_PRIMARY;
  }
  if (i2cAddressResponds(LCD_ADDRESS_FALLBACK)) {
    return LCD_ADDRESS_FALLBACK;
  }
  return LCD_ADDRESS_PRIMARY;
}

bool i2cAddressResponds(byte address) {
  Wire.beginTransmission(address);
  return Wire.endTransmission() == 0;
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
    sendSnapshot();
    return;
  }

  if (strncmp(command, "WEATHER:", 8) == 0) {
    syncWeather(command + 8);
    drawCurrentScreen();
    sendSnapshot();
    return;
  }

  if (strncmp(command, "LANG:", 5) == 0) {
    lcdRussian = strcmp(command + 5, "EN") != 0;
    drawCurrentScreen();
    sendSnapshot();
    return;
  }

  if (strcmp(command, "PING") == 0) {
    sendSnapshot();
  }
}

void drawBootAnimation() {
  static const char* frames[] = { "(o_o)", "(^_^)", "(^o^)", "(^_^)" };
  for (byte step = 0; step < 8; step++) {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print(F("RenPet "));
    lcd.print(frames[step % 4]);
    lcd.setCursor(0, 1);
    for (byte i = 0; i < LCD_COLS; i++) {
      lcd.print(i <= step * 2 ? char(255) : ' ');
    }
    delay(180);
  }
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print(F("RenPet ready"));
  lcd.setCursor(0, 1);
  lcd.print(F("FW "));
  lcd.print(FIRMWARE_VERSION);
  delay(650);
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
  screenMode = static_cast<ScreenMode>((screenMode + 1) % 4);
  drawCurrentScreen();
  sendSnapshot();
}

void drawCurrentScreen() {
  lcd.clear();

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
    case SCREEN_WEATHER:
      drawWeatherScreen();
      break;
  }
}

void drawClimateScreen() {
  lcd.setCursor(0, 0);
  if (lcdRussian) {
    loadClimateGlyphs();
    lcd.write(byte(0));  // T
    lcd.write(byte(1));  // e
    lcd.write(byte(2));  // m
    lcd.write(byte(3));  // p
    lcd.print(F(": "));
  } else {
    lcd.print(F("Temp: "));
  }
  if (isnan(temperatureC)) {
    lcd.print(F("--.-"));
  } else {
    lcd.print(temperatureC, 1);
  }
  lcd.print(F(" C"));

  lcd.setCursor(0, 1);
  if (lcdRussian) {
    lcd.write(byte(4));  // V
    lcd.write(byte(5));  // l
    lcd.write(byte(6));  // zh
    lcd.write(byte(7));  // n
    lcd.print(F(":  "));
  } else {
    lcd.print(F("Hum:  "));
  }
  if (isnan(humidityPercent)) {
    lcd.print(F("--"));
  } else {
    lcd.print(humidityPercent, 0);
  }
  lcd.print(F(" %"));
}

void drawPetScreen() {
  lcd.setCursor(0, 0);
  if (lcdRussian) {
    loadPetGlyphs();
    lcd.write(byte(0));  // P
    lcd.write(byte(1));  // i
    lcd.write(byte(2));  // t
    lcd.write(byte(3));  // o
    lcd.write(byte(4));  // m
    lcd.write(byte(5));  // e
    lcd.write(byte(6));  // ts
    lcd.print(F(" "));
  } else {
    lcd.print(F("Pet "));
  }
  lcd.print((hunger < 30 || happiness < 30) ? F(":(") : F(":)"));

  lcd.setCursor(0, 1);
  lcd.print(F("Food"));
  print3Digits(lcd, hunger);
  lcd.print(F(" Mood"));
  print3Digits(lcd, happiness);
}

void drawClockScreen() {
  int year;
  byte month;
  byte day;
  byte hour;
  byte minute;
  byte second;
  getClock(year, month, day, hour, minute, second);

  lcd.setCursor(0, 0);
  if (lcdRussian) {
    loadClockGlyphs();
    lcd.write(byte(0));  // V
    lcd.write(byte(1));  // r
    lcd.write(byte(2));  // e
    lcd.write(byte(3));  // m
    lcd.write(byte(4));  // ya
    lcd.print(F(" "));
  } else {
    lcd.print(F("Time "));
  }
  printTwoDigits(lcd, hour);
  lcd.print(F(":"));
  printTwoDigits(lcd, minute);
  lcd.print(F(":"));
  printTwoDigits(lcd, second);

  lcd.setCursor(0, 1);
  if (!clockSynced) {
    lcd.print(F("Sync from app"));
  } else {
    if (lcdRussian) {
      lcd.write(byte(5));  // D
      lcd.write(byte(6));  // a
      lcd.write(byte(7));  // t
      lcd.write(byte(6));  // a
      lcd.print(F(" "));
    } else {
      lcd.print(F("Date "));
    }
    printTwoDigits(lcd, day);
    lcd.print(F("."));
    printTwoDigits(lcd, month);
    lcd.print(F("."));
    lcd.print(year);
  }
}

void drawWeatherScreen() {
  lcd.setCursor(0, 0);
  if (weatherSynced) {
    lcd.print(weatherCity);
  } else {
    if (lcdRussian) {
      loadWeatherGlyphs();
      lcd.write(byte(0));  // P
      lcd.write(byte(1));  // o
      lcd.write(byte(2));  // g
      lcd.write(byte(1));  // o
      lcd.write(byte(3));  // d
      lcd.write(byte(4));  // a
    } else {
      lcd.print(F("Weather"));
    }
  }

  lcd.setCursor(0, 1);
  if (!weatherSynced || isnan(weatherTempC)) {
    lcd.print(F("From phone app"));
  } else {
    lcd.print(F("Outside "));
    if (weatherTempC > -10 && weatherTempC < 100) {
      lcd.print(weatherTempC, 1);
    } else {
      lcd.print(weatherTempC, 0);
    }
    lcd.print(F(" C"));
  }
}

void loadClimateGlyphs() {
  lcd.createChar(0, GLYPH_T);
  lcd.createChar(1, GLYPH_E);
  lcd.createChar(2, GLYPH_M);
  lcd.createChar(3, GLYPH_P);
  lcd.createChar(4, GLYPH_V);
  lcd.createChar(5, GLYPH_L);
  lcd.createChar(6, GLYPH_ZH);
  lcd.createChar(7, GLYPH_N);
}

void loadPetGlyphs() {
  lcd.createChar(0, GLYPH_P);
  lcd.createChar(1, GLYPH_I);
  lcd.createChar(2, GLYPH_T);
  lcd.createChar(3, GLYPH_O);
  lcd.createChar(4, GLYPH_M);
  lcd.createChar(5, GLYPH_E);
  lcd.createChar(6, GLYPH_TS);
}

void loadClockGlyphs() {
  lcd.createChar(0, GLYPH_V);
  lcd.createChar(1, GLYPH_R);
  lcd.createChar(2, GLYPH_E);
  lcd.createChar(3, GLYPH_M);
  lcd.createChar(4, GLYPH_YA);
  lcd.createChar(5, GLYPH_D);
  lcd.createChar(6, GLYPH_A);
  lcd.createChar(7, GLYPH_T);
}

void loadWeatherGlyphs() {
  lcd.createChar(0, GLYPH_P);
  lcd.createChar(1, GLYPH_O);
  lcd.createChar(2, GLYPH_G);
  lcd.createChar(3, GLYPH_D);
  lcd.createChar(4, GLYPH_A);
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
  ble.print(F("\",\"fw\":\""));
  ble.print(FIRMWARE_VERSION);
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
    case SCREEN_WEATHER:
      return "weather";
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

void syncWeather(const char* payload) {
  const char* comma = strchr(payload, ',');
  if (comma == nullptr) {
    return;
  }

  const byte cityLength = min(static_cast<int>(comma - payload), 16);
  for (byte i = 0; i < cityLength; i++) {
    const char c = payload[i];
    weatherCity[i] = isPrintableAscii(c) && c != ',' ? c : ' ';
  }
  weatherCity[cityLength] = '\0';
  trimRight(weatherCity);

  if (weatherCity[0] == '\0') {
    strcpy(weatherCity, "City");
  }

  weatherTempC = atof(comma + 1);
  weatherSynced = true;
}

bool isPrintableAscii(char c) {
  return c >= 32 && c <= 126;
}

void trimRight(char* value) {
  int length = strlen(value);
  while (length > 0 && value[length - 1] == ' ') {
    value[length - 1] = '\0';
    length--;
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
  static const byte days[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
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

void print3Digits(Print& printer, byte value) {
  if (value < 100) {
    printer.print(F("0"));
  }
  if (value < 10) {
    printer.print(F("0"));
  }
  printer.print(value);
}
