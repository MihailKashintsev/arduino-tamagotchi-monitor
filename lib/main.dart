import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const TamagotchiMonitorApp());
}

enum AppLanguage { ru, en }

enum LcdLanguage { ru, en }

enum AppThemeChoice { system, light, dark }

enum ColorProfile { teal, indigo, rose, amber }

enum AppSection { overview, pet, weather, devices, settings }

extension AppThemeChoiceX on AppThemeChoice {
  ThemeMode get themeMode {
    switch (this) {
      case AppThemeChoice.system:
        return ThemeMode.system;
      case AppThemeChoice.light:
        return ThemeMode.light;
      case AppThemeChoice.dark:
        return ThemeMode.dark;
    }
  }
}

extension ColorProfileX on ColorProfile {
  Color get seedColor {
    switch (this) {
      case ColorProfile.teal:
        return const Color(0xFF007C78);
      case ColorProfile.indigo:
        return const Color(0xFF4656B5);
      case ColorProfile.rose:
        return const Color(0xFFB63D64);
      case ColorProfile.amber:
        return const Color(0xFFB87518);
    }
  }

  String get label => name[0].toUpperCase() + name.substring(1);
}

class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  bool get isRu => language == AppLanguage.ru;
  String get appName => 'Arduino Pet Link';
  String get eyebrow => isRu ? 'домашняя станция' : 'home station';
  String get overview => isRu ? 'Обзор' : 'Overview';
  String get pet => isRu ? 'Тамагочи' : 'Tamagotchi';
  String get tamagotchi => isRu ? 'Тамагочи' : 'Tamagotchi';
  String get weather => isRu ? 'Погода' : 'Weather';
  String get devices => isRu ? 'Устройства' : 'Devices';
  String get settings => isRu ? 'Настройки' : 'Settings';
  String get disconnected => isRu ? 'Не подключено' : 'Disconnected';
  String get scanBle =>
      isRu ? 'Сканирование Bluetooth LE...' : 'Scanning Bluetooth LE...';
  String get chooseHm10 =>
      isRu ? 'Выберите HM-10 из списка' : 'Choose HM-10 from the list';
  String connecting(String name) =>
      isRu ? 'Подключение к $name...' : 'Connecting to $name...';
  String connectedWaiting(String name) => isRu
      ? 'Подключено к $name, жду данные Arduino'
      : 'Connected to $name, waiting for Arduino data';
  String receiving(String name) =>
      isRu ? 'Получаю данные от $name' : 'Receiving data from $name';
  String get connectionLost =>
      isRu ? 'Соединение разорвано' : 'Connection lost';
  String connectionError(Object error) =>
      isRu ? 'Ошибка подключения: $error' : 'Connection error: $error';
  String timeNotSent(Object error) => isRu
      ? 'Подключено, но время не отправлено: $error'
      : 'Connected, time was not sent: $error';
  String get connectFirst =>
      isRu ? 'Сначала подключитесь к HM-10' : 'Connect to HM-10 first';
  String get scan => isRu ? 'Сканировать' : 'Scan';
  String get refresh => isRu ? 'Обновить' : 'Refresh';
  String get temperature => isRu ? 'Температура' : 'Temperature';
  String get humidity => isRu ? 'Влажность' : 'Humidity';
  String get hunger => isRu ? 'Сытость' : 'Hunger';
  String get mood => isRu ? 'Настроение' : 'Mood';
  String get feed => isRu ? 'Покормить' : 'Feed';
  String get syncTime => isRu ? 'Синхронизировать время' : 'Sync time';
  String get ping => 'PING Arduino';
  String get city => isRu ? 'Город' : 'City';
  String get weatherHint => isRu
      ? 'Город можно изменить перед отправкой.'
      : 'Edit city before sending.';
  String get enterCity => isRu ? 'Введите город.' : 'Enter a city.';
  String gettingWeather(String city) =>
      isRu ? 'Получаю погоду для $city...' : 'Getting weather for $city...';
  String weatherSent(String city, String temp) =>
      isRu ? 'Отправлено: $city $temp °C' : 'Sent: $city $temp °C';
  String weatherError(Object error) => isRu
      ? 'Не удалось получить погоду: $error'
      : 'Could not get weather: $error';
  String get sendWeather => isRu ? 'Отправить погоду' : 'Send weather';
  String get weatherScreen => isRu ? 'Погода на LCD' : 'LCD weather';
  String get cityNotFound => isRu ? 'город не найден' : 'city not found';
  String get noCityCoords =>
      isRu ? 'нет координат города' : 'city coordinates missing';
  String get noWeatherTemp =>
      isRu ? 'нет текущей температуры' : 'current temperature missing';
  String get lastUpdate => isRu ? 'Последнее обновление' : 'Last update';
  String get noDataYet => isRu ? 'Данных ещё нет' : 'No data yet';
  String get waitingJson => isRu
      ? 'Ожидание строки JSON от Arduino'
      : 'Waiting for Arduino JSON line';
  String get bleConnected =>
      isRu ? 'BLE модуль подключен' : 'BLE module connected';
  String get bleDisconnected => isRu ? 'BLE отключен' : 'BLE disconnected';
  String get arduinoData =>
      isRu ? 'Arduino присылает данные' : 'Arduino is sending data';
  String get waitingArduino =>
      isRu ? 'Жду JSON от Arduino' : 'Waiting for Arduino JSON';
  String get arduinoHelp => isRu
      ? 'BLE-модуль найден, но Arduino пока не отвечает. Проверьте свежий скетч и провода HM-10 TXD/RXD к D11/D12 крест-накрест.'
      : 'BLE module is connected, but Arduino is not responding yet. Check the latest sketch and HM-10 TXD/RXD crossed to D11/D12.';
  String get hm10Devices => isRu ? 'HM-10 устройства' : 'HM-10 devices';
  String get scanEmpty => isRu
      ? 'Нажмите поиск и включите питание Arduino с HM-10 рядом.'
      : 'Press scan and power Arduino with HM-10 nearby.';
  String get unnamedHm10 => isRu ? 'HM-10 без имени' : 'Unnamed HM-10';
  String get ready => isRu ? 'Готово' : 'Ready';
  String get connect => isRu ? 'Подключить' : 'Connect';
  String get interfaceLanguage => isRu ? 'Язык приложения' : 'App language';
  String get lcdLanguage =>
      isRu ? 'Язык LCD/тамагочи' : 'LCD/Tamagotchi language';
  String get theme => isRu ? 'Тема' : 'Theme';
  String get colorProfile => isRu ? 'Цветовой профиль' : 'Color profile';
  String get system => isRu ? 'Система' : 'System';
  String get light => isRu ? 'Светлая' : 'Light';
  String get dark => isRu ? 'Тёмная' : 'Dark';
  String get github => isRu ? 'Открыть GitHub' : 'Open GitHub';
  String get diagnostics => isRu ? 'Диагностика' : 'Diagnostics';
  String get stationPulse => isRu ? 'пульс станции' : 'station pulse';
  String get liveData => isRu ? 'живые данные' : 'live data';
  String get lcdConsole => isRu ? 'LCD и команды' : 'LCD and commands';
}

class TamagotchiMonitorApp extends StatefulWidget {
  const TamagotchiMonitorApp({super.key});

  @override
  State<TamagotchiMonitorApp> createState() => _TamagotchiMonitorAppState();
}

class _TamagotchiMonitorAppState extends State<TamagotchiMonitorApp> {
  AppLanguage _language = AppLanguage.ru;
  LcdLanguage _lcdLanguage = LcdLanguage.ru;
  AppThemeChoice _themeChoice = AppThemeChoice.system;
  ColorProfile _colorProfile = ColorProfile.teal;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(_language);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: strings.appName,
      themeMode: _themeChoice.themeMode,
      theme: _buildTheme(_colorProfile.seedColor, Brightness.light),
      darkTheme: _buildTheme(_colorProfile.seedColor, Brightness.dark),
      home: MonitorPage(
        strings: strings,
        language: _language,
        lcdLanguage: _lcdLanguage,
        themeChoice: _themeChoice,
        colorProfile: _colorProfile,
        onLanguageChanged: (value) => setState(() => _language = value),
        onLcdLanguageChanged: (value) => setState(() => _lcdLanguage = value),
        onThemeChanged: (value) => setState(() => _themeChoice = value),
        onColorProfileChanged: (value) => setState(() => _colorProfile = value),
      ),
    );
  }

  ThemeData _buildTheme(Color seed, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: brightness,
    );
    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(
        textStyle: base.textTheme.displayLarge,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: GoogleFonts.spaceGrotesk(
        textStyle: base.textTheme.headlineLarge,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: GoogleFonts.spaceGrotesk(
        textStyle: base.textTheme.titleLarge,
        fontWeight: FontWeight.w700,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? const Color(0xFF101211)
          : const Color(0xFFF4F3EE),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: scheme.surface.withValues(
          alpha: brightness == Brightness.dark ? 0.76 : 0.9,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class MonitorPage extends StatefulWidget {
  const MonitorPage({
    super.key,
    required this.strings,
    required this.language,
    required this.lcdLanguage,
    required this.themeChoice,
    required this.colorProfile,
    required this.onLanguageChanged,
    required this.onLcdLanguageChanged,
    required this.onThemeChanged,
    required this.onColorProfileChanged,
  });

  final AppStrings strings;
  final AppLanguage language;
  final LcdLanguage lcdLanguage;
  final AppThemeChoice themeChoice;
  final ColorProfile colorProfile;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final ValueChanged<LcdLanguage> onLcdLanguageChanged;
  final ValueChanged<AppThemeChoice> onThemeChanged;
  final ValueChanged<ColorProfile> onColorProfileChanged;

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  static final Guid _hm10Service = Guid('0000ffe0-0000-1000-8000-00805f9b34fb');
  static final Guid _hm10Characteristic = Guid(
    '0000ffe1-0000-1000-8000-00805f9b34fb',
  );
  static const int _hm10WriteChunkSize = 20;

  final List<ScanResult> _scanResults = [];
  final StringBuffer _rxBuffer = StringBuffer();
  final TextEditingController _weatherCityController = TextEditingController(
    text: 'Moscow',
  );

  BluetoothDevice? _device;
  BluetoothCharacteristic? _uart;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _uartSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  AppSection _section = AppSection.overview;
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isUpdatingWeather = false;
  late String _status;
  late String _weatherStatus;
  String _lastLine = '';
  DeviceSnapshot _snapshot = DeviceSnapshot.empty();

  @override
  void initState() {
    super.initState();
    _status = widget.strings.disconnected;
    _weatherStatus = widget.strings.weatherHint;
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      final filtered = results.where(_isLikelyHm10).toList()
        ..sort((a, b) => b.rssi.compareTo(a.rssi));
      if (mounted) {
        setState(() {
          _scanResults
            ..clear()
            ..addAll(filtered);
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant MonitorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language && _device == null) {
      _status = widget.strings.disconnected;
      _weatherStatus = widget.strings.weatherHint;
    }
    if (oldWidget.lcdLanguage != widget.lcdLanguage && _uart != null) {
      final code = widget.lcdLanguage == LcdLanguage.ru ? 'RU' : 'EN';
      unawaited(_sendCommand('LANG:$code'));
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _uartSubscription?.cancel();
    _connectionSubscription?.cancel();
    _weatherCityController.dispose();
    _device?.disconnect();
    super.dispose();
  }

  bool get _connected => _device != null && _uart != null;
  bool get _hasArduinoData => _snapshot.updatedAt != null;

  bool _isLikelyHm10(ScanResult result) {
    final name = result.device.platformName.toLowerCase();
    final advertisementName = result.advertisementData.advName.toLowerCase();
    final hasHm10Service = result.advertisementData.serviceUuids.contains(
      _hm10Service,
    );
    return hasHm10Service ||
        name.contains('hm') ||
        name.contains('arduino') ||
        advertisementName.contains('hm') ||
        advertisementName.contains('arduino');
  }

  Future<void> _startScan() async {
    await _requestPermissions();
    await FlutterBluePlus.stopScan();
    setState(() {
      _scanResults.clear();
      _isScanning = true;
      _status = widget.strings.scanBle;
      _section = AppSection.devices;
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _status = _device == null ? widget.strings.chooseHm10 : _status;
        });
      }
    }
  }

  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  Future<void> _connect(ScanResult result) async {
    if (_isConnecting) return;
    setState(() {
      _isConnecting = true;
      _status = widget.strings.connecting(_deviceName(result.device));
    });

    try {
      await _uartSubscription?.cancel();
      await _connectionSubscription?.cancel();
      await _device?.disconnect();

      final device = result.device;
      await device.connect(
        timeout: const Duration(seconds: 12),
        autoConnect: false,
      );
      final services = await device.discoverServices();
      final service = services.firstWhere(
        (item) => item.uuid == _hm10Service,
        orElse: () => services.firstWhere(
          (item) => item.characteristics.any(
            (char) => char.uuid == _hm10Characteristic,
          ),
        ),
      );
      final characteristic = service.characteristics.firstWhere(
        (char) => char.uuid == _hm10Characteristic,
      );

      await characteristic.setNotifyValue(true);
      _uartSubscription = characteristic.onValueReceived.listen(_handleBytes);
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected && mounted) {
          setState(() {
            _status = widget.strings.connectionLost;
            _device = null;
            _uart = null;
          });
        }
      });

      setState(() {
        _device = device;
        _uart = characteristic;
        _status = widget.strings.connectedWaiting(_deviceName(device));
      });

      try {
        await _sendCommand('TIME:${DateTime.now().toIso8601String()}');
        final languageCode = widget.lcdLanguage == LcdLanguage.ru ? 'RU' : 'EN';
        await _sendCommand('LANG:$languageCode');
      } catch (error) {
        setState(() => _status = widget.strings.timeNotSent(error));
      }
    } catch (error) {
      setState(() => _status = widget.strings.connectionError(error));
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _handleBytes(List<int> bytes) {
    if (bytes.isEmpty) return;
    _rxBuffer.write(utf8.decode(bytes, allowMalformed: true));
    final payload = _rxBuffer.toString();
    final parts = payload.split('\n');
    _rxBuffer
      ..clear()
      ..write(parts.removeLast());

    for (final rawLine in parts) {
      final line = rawLine.trim();
      if (line.isNotEmpty) _parseLine(line);
    }
  }

  void _parseLine(String line) {
    try {
      final decoded = jsonDecode(line) as Map<String, dynamic>;
      setState(() {
        _snapshot = DeviceSnapshot.fromJson(decoded);
        if (_device != null) {
          _status = widget.strings.receiving(_deviceName(_device!));
        }
        _lastLine = line;
      });
    } catch (_) {
      setState(() => _lastLine = line);
    }
  }

  Future<void> _sendCommand(String command) async {
    final characteristic = _uart;
    if (characteristic == null) {
      setState(() => _status = widget.strings.connectFirst);
      return;
    }

    final bytes = utf8.encode('$command\n');
    final withoutResponse = characteristic.properties.writeWithoutResponse;
    for (var offset = 0; offset < bytes.length; offset += _hm10WriteChunkSize) {
      final nextOffset = offset + _hm10WriteChunkSize;
      final end = nextOffset > bytes.length ? bytes.length : nextOffset;
      await characteristic.write(
        bytes.sublist(offset, end),
        withoutResponse: withoutResponse,
      );
      await Future<void>.delayed(const Duration(milliseconds: 35));
    }
  }

  Future<void> _sendWeatherFromPhone() async {
    if (_isUpdatingWeather) return;
    final cityQuery = _weatherCityController.text.trim();
    if (cityQuery.isEmpty) {
      setState(() => _weatherStatus = widget.strings.enterCity);
      return;
    }

    setState(() {
      _isUpdatingWeather = true;
      _weatherStatus = widget.strings.gettingWeather(cityQuery);
    });

    try {
      final weather = await _fetchCurrentWeather(cityQuery);
      final displayCity = _asciiForLcd(weather.city);
      await _sendCommand(
        'WEATHER:$displayCity,${weather.temperatureC.toStringAsFixed(1)}',
      );
      if (mounted) {
        setState(() {
          _weatherStatus = widget.strings.weatherSent(
            displayCity,
            weather.temperatureC.toStringAsFixed(1),
          );
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _weatherStatus = widget.strings.weatherError(error));
      }
    } finally {
      if (mounted) setState(() => _isUpdatingWeather = false);
    }
  }

  Future<PhoneWeather> _fetchCurrentWeather(String cityQuery) async {
    final geocodingUri = Uri.https(
      'geocoding-api.open-meteo.com',
      '/v1/search',
      {'name': cityQuery, 'count': '1', 'language': 'en', 'format': 'json'},
    );
    final geocodingResponse = await http
        .get(geocodingUri)
        .timeout(const Duration(seconds: 12));
    if (geocodingResponse.statusCode != 200) {
      throw Exception('geocoding HTTP ${geocodingResponse.statusCode}');
    }

    final geocodingJson =
        jsonDecode(geocodingResponse.body) as Map<String, dynamic>;
    final results = geocodingJson['results'];
    if (results is! List ||
        results.isEmpty ||
        results.first is! Map<String, dynamic>) {
      throw Exception(widget.strings.cityNotFound);
    }

    final place = results.first as Map<String, dynamic>;
    final latitude = place['latitude'];
    final longitude = place['longitude'];
    if (latitude is! num || longitude is! num) {
      throw Exception(widget.strings.noCityCoords);
    }

    final forecastUri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current': 'temperature_2m',
    });
    final forecastResponse = await http
        .get(forecastUri)
        .timeout(const Duration(seconds: 12));
    if (forecastResponse.statusCode != 200) {
      throw Exception('weather HTTP ${forecastResponse.statusCode}');
    }

    final forecastJson =
        jsonDecode(forecastResponse.body) as Map<String, dynamic>;
    final current = forecastJson['current'];
    if (current is! Map<String, dynamic> || current['temperature_2m'] is! num) {
      throw Exception(widget.strings.noWeatherTemp);
    }

    return PhoneWeather(
      city: (place['name'] ?? cityQuery).toString(),
      temperatureC: (current['temperature_2m'] as num).toDouble(),
    );
  }

  String _asciiForLcd(String value) {
    final ascii = value
        .replaceAll(',', ' ')
        .runes
        .where((rune) => rune >= 32 && rune <= 126)
        .map(String.fromCharCode)
        .join()
        .trim();
    if (ascii.isEmpty) return 'City';
    return ascii.length <= 16 ? ascii : ascii.substring(0, 16).trim();
  }

  String _deviceName(BluetoothDevice device) {
    final name = device.platformName.trim();
    return name.isEmpty ? device.remoteId.str : name;
  }

  Future<void> _openGithub() async {
    final uri = Uri.parse(
      'https://github.com/MihailKashintsev/arduino-tamagotchi-monitor',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final shell = _ShellState(
      strings: widget.strings,
      language: widget.language,
      lcdLanguage: widget.lcdLanguage,
      themeChoice: widget.themeChoice,
      colorProfile: widget.colorProfile,
      section: _section,
      status: _status,
      weatherStatus: _weatherStatus,
      lastLine: _lastLine,
      snapshot: _snapshot,
      scanResults: _scanResults,
      connected: _connected,
      hasArduinoData: _hasArduinoData,
      isScanning: _isScanning,
      isConnecting: _isConnecting,
      isUpdatingWeather: _isUpdatingWeather,
      weatherCityController: _weatherCityController,
      onSectionChanged: (section) => setState(() => _section = section),
      onScan: _startScan,
      onConnect: _connect,
      onFeed: _connected ? () => _sendCommand('FEED') : null,
      onSyncTime: _connected
          ? () => _sendCommand('TIME:${DateTime.now().toIso8601String()}')
          : null,
      onPing: _connected ? () => _sendCommand('PING') : null,
      onSendWeather: _connected ? _sendWeatherFromPhone : null,
      onOpenGithub: _openGithub,
      onLanguageChanged: widget.onLanguageChanged,
      onLcdLanguageChanged: widget.onLcdLanguageChanged,
      onThemeChanged: widget.onThemeChanged,
      onColorProfileChanged: widget.onColorProfileChanged,
    );

    return Scaffold(
      body: Stack(
        children: [
          _AppBackdrop(seed: widget.colorProfile.seedColor),
          SafeArea(child: _ResponsiveShell(state: shell)),
        ],
      ),
    );
  }
}

class _ShellState {
  const _ShellState({
    required this.strings,
    required this.language,
    required this.lcdLanguage,
    required this.themeChoice,
    required this.colorProfile,
    required this.section,
    required this.status,
    required this.weatherStatus,
    required this.lastLine,
    required this.snapshot,
    required this.scanResults,
    required this.connected,
    required this.hasArduinoData,
    required this.isScanning,
    required this.isConnecting,
    required this.isUpdatingWeather,
    required this.weatherCityController,
    required this.onSectionChanged,
    required this.onScan,
    required this.onConnect,
    required this.onFeed,
    required this.onSyncTime,
    required this.onPing,
    required this.onSendWeather,
    required this.onOpenGithub,
    required this.onLanguageChanged,
    required this.onLcdLanguageChanged,
    required this.onThemeChanged,
    required this.onColorProfileChanged,
  });

  final AppStrings strings;
  final AppLanguage language;
  final LcdLanguage lcdLanguage;
  final AppThemeChoice themeChoice;
  final ColorProfile colorProfile;
  final AppSection section;
  final String status;
  final String weatherStatus;
  final String lastLine;
  final DeviceSnapshot snapshot;
  final List<ScanResult> scanResults;
  final bool connected;
  final bool hasArduinoData;
  final bool isScanning;
  final bool isConnecting;
  final bool isUpdatingWeather;
  final TextEditingController weatherCityController;
  final ValueChanged<AppSection> onSectionChanged;
  final VoidCallback onScan;
  final ValueChanged<ScanResult> onConnect;
  final VoidCallback? onFeed;
  final VoidCallback? onSyncTime;
  final VoidCallback? onPing;
  final VoidCallback? onSendWeather;
  final VoidCallback onOpenGithub;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final ValueChanged<LcdLanguage> onLcdLanguageChanged;
  final ValueChanged<AppThemeChoice> onThemeChanged;
  final ValueChanged<ColorProfile> onColorProfileChanged;
}

class _AppBackdrop extends StatelessWidget {
  const _AppBackdrop({required this.seed});

  final Color seed;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -160,
            right: -140,
            child: _BlurDisc(
              color: seed.withValues(alpha: dark ? 0.25 : 0.18),
              size: 360,
            ),
          ),
          Positioned(
            bottom: -170,
            left: -150,
            child: _BlurDisc(
              color: seed.withValues(alpha: dark ? 0.18 : 0.12),
              size: 420,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurDisc extends StatelessWidget {
  const _BlurDisc({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 120, spreadRadius: 60)],
      ),
    );
  }
}

class _ResponsiveShell extends StatelessWidget {
  const _ResponsiveShell({required this.state});

  final _ShellState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final body = Row(
          children: [
            if (wide) _SideNav(state: state),
            Expanded(child: _SectionViewport(state: state)),
          ],
        );

        if (wide) return body;
        return Column(
          children: [
            Expanded(child: body),
            _BottomNav(state: state),
          ],
        );
      },
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({required this.state});

  final _ShellState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      margin: const EdgeInsets.all(18),
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BrandBlock(strings: state.strings),
          const SizedBox(height: 28),
          ...AppSection.values.map(
            (section) => _NavItem(
              section: section,
              selected: state.section == section,
              strings: state.strings,
              onTap: () => state.onSectionChanged(section),
            ),
          ),
          const Spacer(),
          _MiniLinkStatus(
            connected: state.connected,
            hasArduinoData: state.hasArduinoData,
            strings: state.strings,
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.state});

  final _ShellState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: _panelDecoration(context),
      child: NavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedIndex: AppSection.values.indexOf(state.section),
        onDestinationSelected: (index) =>
            state.onSectionChanged(AppSection.values[index]),
        destinations: AppSection.values.map((section) {
          return NavigationDestination(
            icon: Icon(_sectionIcon(section)),
            selectedIcon: Icon(_sectionSelectedIcon(section)),
            label: _sectionLabel(section, state.strings),
          );
        }).toList(),
      ),
    );
  }
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(Icons.memory, color: colors.onPrimary, size: 28),
        ),
        const SizedBox(height: 16),
        Text(
          strings.appName,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 0.95,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          strings.eyebrow.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            letterSpacing: 1.4,
            color: colors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.section,
    required this.selected,
    required this.strings,
    required this.onTap,
  });

  final AppSection section;
  final bool selected;
  final AppStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? colors.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? _sectionSelectedIcon(section)
                    : _sectionIcon(section),
                color: selected
                    ? colors.onPrimaryContainer
                    : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _sectionLabel(section, strings),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected
                        ? colors.onPrimaryContainer
                        : colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionViewport extends StatelessWidget {
  const _SectionViewport({required this.state});

  final _ShellState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TopCommandBar(state: state),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.025, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(state.section),
                child: _buildSection(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection() {
    switch (state.section) {
      case AppSection.overview:
        return _OverviewScreen(state: state);
      case AppSection.pet:
        return _PetScreen(state: state);
      case AppSection.weather:
        return _WeatherScreen(state: state);
      case AppSection.devices:
        return _DevicesScreen(state: state);
      case AppSection.settings:
        return _SettingsScreen(state: state);
    }
  }
}

class _TopCommandBar extends StatelessWidget {
  const _TopCommandBar({required this.state});

  final _ShellState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(context),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.strings.appName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_sectionLabel(state.section, state.strings)} · ${state.status}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _PulseDot(
            active: state.connected,
            warning: state.connected && !state.hasArduinoData,
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: state.isScanning ? null : state.onScan,
            icon: Icon(
              state.isScanning ? Icons.bluetooth_searching : Icons.search,
            ),
            label: Text(state.strings.scan),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: state.strings.github,
            onPressed: state.onOpenGithub,
            icon: const Icon(Icons.code),
          ),
        ],
      ),
    );
  }
}

class _OverviewScreen extends StatelessWidget {
  const _OverviewScreen({required this.state});

  final _ShellState state;

  @override
  Widget build(BuildContext context) {
    final updated = state.snapshot.updatedAt == null
        ? state.strings.noDataYet
        : DateFormat('dd.MM.yyyy HH:mm:ss').format(state.snapshot.updatedAt!);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroStatusPanel(state: state),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final cards = [
                _MetricTile(
                  icon: Icons.thermostat,
                  title: state.strings.temperature,
                  value: state.snapshot.temperature == null
                      ? '-- °C'
                      : '${state.snapshot.temperature!.toStringAsFixed(1)} °C',
                  accent: const Color(0xFFE4572E),
                ),
                _MetricTile(
                  icon: Icons.water_drop,
                  title: state.strings.humidity,
                  value: state.snapshot.humidity == null
                      ? '-- %'
                      : '${state.snapshot.humidity!.toStringAsFixed(0)} %',
                  accent: const Color(0xFF1789FC),
                ),
                _MetricTile(
                  icon: Icons.restaurant,
                  title: state.strings.hunger,
                  value: state.snapshot.hungerPercent == null
                      ? '-- %'
                      : '${state.snapshot.hungerPercent} %',
                  accent: const Color(0xFF23A455),
                ),
                _MetricTile(
                  icon: Icons.sentiment_satisfied,
                  title: state.strings.mood,
                  value: state.snapshot.happinessPercent == null
                      ? '-- %'
                      : '${state.snapshot.happinessPercent} %',
                  accent: const Color(0xFFB950B7),
                ),
              ];
              return GridView.count(
                crossAxisCount: wide ? 4 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: wide ? 1.12 : 1.2,
                children: cards,
              );
            },
          ),
          const SizedBox(height: 16),
          _GlassPanel(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.strings.lastUpdate,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(updated),
                  const SizedBox(height: 12),
                  SelectableText(
                    state.lastLine.isEmpty
                        ? state.strings.waitingJson
                        : state.lastLine,
                    style: GoogleFonts.jetBrainsMono(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatusPanel extends StatelessWidget {
  const _HeroStatusPanel({required this.state});

  final _ShellState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _GlassPanel(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    state.connected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    color: colors.onPrimary,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.strings.stationPulse,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.status,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _StatePill(
                  icon: Icons.bluetooth,
                  label: state.connected
                      ? state.strings.bleConnected
                      : state.strings.bleDisconnected,
                  active: state.connected,
                ),
                _StatePill(
                  icon: Icons.developer_board,
                  label: state.hasArduinoData
                      ? state.strings.arduinoData
                      : state.strings.waitingArduino,
                  active: state.hasArduinoData,
                ),
              ],
            ),
            if (state.connected && !state.hasArduinoData) ...[
              const SizedBox(height: 16),
              Text(state.strings.arduinoHelp),
            ],
          ],
        ),
      ),
    );
  }
}

class _PetScreen extends StatelessWidget {
  const _PetScreen({required this.state});

  final _ShellState state;

  @override
  Widget build(BuildContext context) {
    final hunger = state.snapshot.hungerPercent;
    final mood = state.snapshot.happinessPercent;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GlassPanel(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _PetAvatar(hunger: hunger, mood: mood),
                  const SizedBox(height: 18),
                  Text(
                    state.strings.tamagotchi,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _AnimatedProgress(
                    label: state.strings.hunger,
                    value: hunger,
                    color: const Color(0xFF23A455),
                  ),
                  const SizedBox(height: 16),
                  _AnimatedProgress(
                    label: state.strings.mood,
                    value: mood,
                    color: const Color(0xFFB950B7),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: state.onFeed,
                        icon: const Icon(Icons.restaurant),
                        label: Text(state.strings.feed),
                      ),
                      OutlinedButton.icon(
                        onPressed: state.onPing,
                        icon: const Icon(Icons.network_ping),
                        label: Text(state.strings.ping),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherScreen extends StatelessWidget {
  const _WeatherScreen({required this.state});

  final _ShellState state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GlassPanel(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud, size: 34),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.strings.weatherScreen,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: state.weatherCityController,
                    decoration: InputDecoration(
                      labelText: state.strings.city,
                      prefixIcon: const Icon(Icons.location_city),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => state.onSendWeather?.call(),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: state.isUpdatingWeather
                            ? null
                            : state.onSendWeather,
                        icon: Icon(
                          state.isUpdatingWeather
                              ? Icons.hourglass_top
                              : Icons.send,
                        ),
                        label: Text(state.strings.sendWeather),
                      ),
                      Text(state.weatherStatus),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DevicesScreen extends StatelessWidget {
  const _DevicesScreen({required this.state});

  final _ShellState state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: _GlassPanel(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      state.strings.hm10Devices,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: state.strings.refresh,
                    onPressed: state.isScanning ? null : state.onScan,
                    icon: Icon(
                      state.isScanning
                          ? Icons.bluetooth_searching
                          : Icons.refresh,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (state.isScanning) const LinearProgressIndicator(),
              if (!state.isScanning && state.scanResults.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    state.strings.scanEmpty,
                    textAlign: TextAlign.center,
                  ),
                ),
              ...state.scanResults.map(
                (result) => _DeviceRow(
                  result: result,
                  selected:
                      state.connected &&
                      state.scanResults.any(
                        (r) => r.device.remoteId == result.device.remoteId,
                      ),
                  isConnecting: state.isConnecting,
                  strings: state.strings,
                  onConnect: state.onConnect,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen({required this.state});

  final _ShellState state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: _GlassPanel(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.strings.settings,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 22),
              _SettingLabel(state.strings.interfaceLanguage),
              const SizedBox(height: 8),
              SegmentedButton<AppLanguage>(
                segments: const [
                  ButtonSegment(value: AppLanguage.ru, label: Text('RU')),
                  ButtonSegment(value: AppLanguage.en, label: Text('EN')),
                ],
                selected: {state.language},
                onSelectionChanged: (selected) =>
                    state.onLanguageChanged(selected.first),
              ),
              const SizedBox(height: 18),
              _SettingLabel(state.strings.lcdLanguage),
              const SizedBox(height: 8),
              SegmentedButton<LcdLanguage>(
                segments: const [
                  ButtonSegment(value: LcdLanguage.ru, label: Text('RU')),
                  ButtonSegment(value: LcdLanguage.en, label: Text('EN')),
                ],
                selected: {state.lcdLanguage},
                onSelectionChanged: (selected) =>
                    state.onLcdLanguageChanged(selected.first),
              ),
              const SizedBox(height: 18),
              _SettingLabel(state.strings.theme),
              const SizedBox(height: 8),
              SegmentedButton<AppThemeChoice>(
                segments: [
                  ButtonSegment(
                    value: AppThemeChoice.system,
                    icon: const Icon(Icons.brightness_auto),
                    label: Text(state.strings.system),
                  ),
                  ButtonSegment(
                    value: AppThemeChoice.light,
                    icon: const Icon(Icons.light_mode),
                    label: Text(state.strings.light),
                  ),
                  ButtonSegment(
                    value: AppThemeChoice.dark,
                    icon: const Icon(Icons.dark_mode),
                    label: Text(state.strings.dark),
                  ),
                ],
                selected: {state.themeChoice},
                onSelectionChanged: (selected) =>
                    state.onThemeChanged(selected.first),
              ),
              const SizedBox(height: 18),
              _SettingLabel(state.strings.colorProfile),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                children: ColorProfile.values.map((profile) {
                  final selected = profile == state.colorProfile;
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => state.onColorProfileChanged(profile),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 64,
                      height: 44,
                      decoration: BoxDecoration(
                        color: profile.seedColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: state.onOpenGithub,
                icon: const Icon(Icons.open_in_new),
                label: Text(state.strings.github),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.result,
    required this.selected,
    required this.isConnecting,
    required this.strings,
    required this.onConnect,
  });

  final ScanResult result;
  final bool selected;
  final bool isConnecting;
  final AppStrings strings;
  final ValueChanged<ScanResult> onConnect;

  @override
  Widget build(BuildContext context) {
    final name = result.device.platformName.trim().isEmpty
        ? strings.unnamedHm10
        : result.device.platformName.trim();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(selected ? Icons.check_circle : Icons.bluetooth),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text('${result.device.remoteId.str} · RSSI ${result.rssi}'),
              ],
            ),
          ),
          FilledButton(
            onPressed: isConnecting ? null : () => onConnect(result),
            child: Text(selected ? strings.ready : strings.connect),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent),
            const Spacer(),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: Text(
                value,
                key: ValueKey(value),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetAvatar extends StatelessWidget {
  const _PetAvatar({required this.hunger, required this.mood});

  final int? hunger;
  final int? mood;

  @override
  Widget build(BuildContext context) {
    final sad = (hunger ?? 100) < 35 || (mood ?? 100) < 35;
    final colors = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.96, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        width: 168,
        height: 168,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(44),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: CustomPaint(
          painter: _PetFacePainter(color: colors.onPrimaryContainer, sad: sad),
        ),
      ),
    );
  }
}

class _PetFacePainter extends CustomPainter {
  const _PetFacePainter({required this.color, required this.sad});

  final Color color;
  final bool sad;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = color;
    canvas.drawCircle(Offset(size.width * 0.36, size.height * 0.38), 7, fill);
    canvas.drawCircle(Offset(size.width * 0.64, size.height * 0.38), 7, fill);
    final mouth = Path();
    if (sad) {
      mouth.moveTo(size.width * 0.35, size.height * 0.68);
      mouth.quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.55,
        size.width * 0.65,
        size.height * 0.68,
      );
    } else {
      mouth.moveTo(size.width * 0.34, size.height * 0.58);
      mouth.quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.75,
        size.width * 0.66,
        size.height * 0.58,
      );
    }
    canvas.drawPath(mouth, paint);
  }

  @override
  bool shouldRepaint(covariant _PetFacePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.sad != sad;
  }
}

class _AnimatedProgress extends StatelessWidget {
  const _AnimatedProgress({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final target = (value ?? 0).clamp(0, 100) / 100;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value == null ? 0 : target),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(value == null ? '-- %' : '$value %'),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 14,
                value: value == null ? null : animated,
                color: color,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MiniLinkStatus extends StatelessWidget {
  const _MiniLinkStatus({
    required this.connected,
    required this.hasArduinoData,
    required this.strings,
  });

  final bool connected;
  final bool hasArduinoData;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatePill(
          icon: Icons.bluetooth,
          label: connected ? strings.bleConnected : strings.bleDisconnected,
          active: connected,
        ),
        const SizedBox(height: 8),
        _StatePill(
          icon: Icons.developer_board,
          label: hasArduinoData ? strings.arduinoData : strings.waitingArduino,
          active: hasArduinoData,
        ),
      ],
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: active
            ? colors.primaryContainer
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot({required this.active, required this.warning});

  final bool active;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning
        ? Colors.amber
        : active
        ? Colors.green
        : Theme.of(context).colorScheme.outline;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.72, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, _) {
        return Container(
          width: 14 + value * 4,
          height: 14 + value * 4,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 16 * value,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GlassPanel extends StatefulWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  State<_GlassPanel> createState() => _GlassPanelState();
}

class _GlassPanelState extends State<_GlassPanel> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.006 : 1,
        duration: const Duration(milliseconds: 180),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: _panelDecoration(context).copyWith(
            border: Border.all(
              color: colors.outlineVariant.withValues(
                alpha: _hovered ? 0.75 : 0.42,
              ),
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _SettingLabel extends StatelessWidget {
  const _SettingLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

BoxDecoration _panelDecoration(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: colors.surface.withValues(alpha: dark ? 0.72 : 0.82),
    borderRadius: BorderRadius.circular(28),
    border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.42)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.28 : 0.08),
        blurRadius: 28,
        offset: const Offset(0, 16),
      ),
    ],
  );
}

IconData _sectionIcon(AppSection section) {
  switch (section) {
    case AppSection.overview:
      return Icons.dashboard_outlined;
    case AppSection.pet:
      return Icons.smart_toy_outlined;
    case AppSection.weather:
      return Icons.cloud_outlined;
    case AppSection.devices:
      return Icons.bluetooth_searching;
    case AppSection.settings:
      return Icons.tune;
  }
}

IconData _sectionSelectedIcon(AppSection section) {
  switch (section) {
    case AppSection.overview:
      return Icons.dashboard;
    case AppSection.pet:
      return Icons.smart_toy;
    case AppSection.weather:
      return Icons.cloud;
    case AppSection.devices:
      return Icons.bluetooth_connected;
    case AppSection.settings:
      return Icons.tune;
  }
}

String _sectionLabel(AppSection section, AppStrings strings) {
  switch (section) {
    case AppSection.overview:
      return strings.overview;
    case AppSection.pet:
      return strings.pet;
    case AppSection.weather:
      return strings.weather;
    case AppSection.devices:
      return strings.devices;
    case AppSection.settings:
      return strings.settings;
  }
}

class DeviceSnapshot {
  const DeviceSnapshot({
    required this.temperature,
    required this.humidity,
    required this.hungerPercent,
    required this.happinessPercent,
    required this.screen,
    required this.updatedAt,
  });

  factory DeviceSnapshot.empty() {
    return const DeviceSnapshot(
      temperature: null,
      humidity: null,
      hungerPercent: null,
      happinessPercent: null,
      screen: null,
      updatedAt: null,
    );
  }

  factory DeviceSnapshot.fromJson(Map<String, dynamic> json) {
    num? readNum(String key) => json[key] is num ? json[key] as num : null;
    return DeviceSnapshot(
      temperature: readNum('temp')?.toDouble(),
      humidity: readNum('hum')?.toDouble(),
      hungerPercent: readNum('hunger')?.round().clamp(0, 100),
      happinessPercent: readNum('happy')?.round().clamp(0, 100),
      screen: json['screen']?.toString(),
      updatedAt: DateTime.now(),
    );
  }

  final double? temperature;
  final double? humidity;
  final int? hungerPercent;
  final int? happinessPercent;
  final String? screen;
  final DateTime? updatedAt;
}

class PhoneWeather {
  const PhoneWeather({required this.city, required this.temperatureC});

  final String city;
  final double temperatureC;
}
