import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
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
        return const Color(0xFF0A7C78);
      case ColorProfile.indigo:
        return const Color(0xFF4057A8);
      case ColorProfile.rose:
        return const Color(0xFFB23A5B);
      case ColorProfile.amber:
        return const Color(0xFFAD7417);
    }
  }
}

class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  bool get isRu => language == AppLanguage.ru;
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
  String get cityNotFound => isRu ? 'город не найден' : 'city not found';
  String get noCityCoords =>
      isRu ? 'нет координат города' : 'city coordinates missing';
  String get noWeatherTemp =>
      isRu ? 'нет текущей температуры' : 'current temperature missing';
  String get scan => isRu ? 'Сканировать' : 'Scan';
  String get temperature => isRu ? 'Температура' : 'Temperature';
  String get humidity => isRu ? 'Влажность' : 'Humidity';
  String get weatherForScreen => isRu ? 'Погода для экрана' : 'Weather screen';
  String get city => isRu ? 'Город' : 'City';
  String get sendWeather => isRu ? 'Отправить погоду' : 'Send weather';
  String get tamagotchi => isRu ? 'Тамагочи' : 'Tamagotchi';
  String get hunger => isRu ? 'Сытость' : 'Hunger';
  String get mood => isRu ? 'Настроение' : 'Mood';
  String get feed => isRu ? 'Покормить' : 'Feed';
  String get syncTime => isRu ? 'Синхронизировать время' : 'Sync time';
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
  String get devices => isRu ? 'HM-10 устройства' : 'HM-10 devices';
  String get refresh => isRu ? 'Обновить' : 'Refresh';
  String get scanEmpty => isRu
      ? 'Нажмите поиск и включите питание Arduino с HM-10 рядом.'
      : 'Press scan and power Arduino with HM-10 nearby.';
  String get unnamedHm10 => isRu ? 'HM-10 без имени' : 'Unnamed HM-10';
  String get ready => isRu ? 'Готово' : 'Ready';
  String get connect => isRu ? 'Подключить' : 'Connect';
  String get settings => isRu ? 'Настройки' : 'Settings';
  String get interfaceLanguage => isRu ? 'Язык приложения' : 'App language';
  String get lcdLanguage =>
      isRu ? 'Язык LCD/тамагочи' : 'LCD/Tamagotchi language';
  String get theme => isRu ? 'Тема' : 'Theme';
  String get colorProfile => isRu ? 'Цветовой профиль' : 'Color profile';
  String get system => isRu ? 'Система' : 'System';
  String get light => isRu ? 'Светлая' : 'Light';
  String get dark => isRu ? 'Тёмная' : 'Dark';
  String get github => isRu ? 'Открыть GitHub' : 'Open GitHub';
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
    final seed = _colorProfile.seedColor;
    final strings = AppStrings(_language);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Arduino Pet Link',
      themeMode: _themeChoice.themeMode,
      theme: _buildTheme(seed, Brightness.light),
      darkTheme: _buildTheme(seed, Brightness.dark),
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
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? const Color(0xFF101412)
          : const Color(0xFFF4F7F2),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainerLowest,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
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
    if (!Platform.isAndroid) {
      return;
    }

    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  Future<void> _connect(ScanResult result) async {
    if (_isConnecting) {
      return;
    }

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
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  void _handleBytes(List<int> bytes) {
    if (bytes.isEmpty) {
      return;
    }

    _rxBuffer.write(utf8.decode(bytes, allowMalformed: true));
    final payload = _rxBuffer.toString();
    final parts = payload.split('\n');
    _rxBuffer
      ..clear()
      ..write(parts.removeLast());

    for (final rawLine in parts) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      _parseLine(line);
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
    if (_isUpdatingWeather) {
      return;
    }

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
      if (mounted) {
        setState(() => _isUpdatingWeather = false);
      }
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

    if (ascii.isEmpty) {
      return 'City';
    }
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
    final connected = _device != null && _uart != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arduino Pet Link'),
        actions: [
          IconButton(
            tooltip: 'GitHub',
            onPressed: _openGithub,
            icon: const Icon(Icons.code),
          ),
          IconButton(
            tooltip: widget.strings.scan,
            onPressed: _isScanning ? null : _startScan,
            icon: Icon(_isScanning ? Icons.bluetooth_searching : Icons.search),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Flex(
                direction: wide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    fit: wide ? FlexFit.tight : FlexFit.loose,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _StatusPanel(
                        key: ValueKey(
                          '${widget.language}-${widget.colorProfile}',
                        ),
                        strings: widget.strings,
                        status: _status,
                        connected: connected,
                        hasArduinoData: _snapshot.updatedAt != null,
                        snapshot: _snapshot,
                        lastLine: _lastLine,
                        onFeed: connected ? () => _sendCommand('FEED') : null,
                        onSyncTime: connected
                            ? () => _sendCommand(
                                'TIME:${DateTime.now().toIso8601String()}',
                              )
                            : null,
                        onPing: connected ? () => _sendCommand('PING') : null,
                        weatherCityController: _weatherCityController,
                        weatherStatus: _weatherStatus,
                        isUpdatingWeather: _isUpdatingWeather,
                        onSendWeather: connected ? _sendWeatherFromPhone : null,
                      ),
                    ),
                  ),
                  SizedBox(width: wide ? 16 : 0, height: wide ? 0 : 16),
                  Flexible(
                    fit: wide ? FlexFit.tight : FlexFit.loose,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SettingsPanel(
                          strings: widget.strings,
                          language: widget.language,
                          lcdLanguage: widget.lcdLanguage,
                          themeChoice: widget.themeChoice,
                          colorProfile: widget.colorProfile,
                          onLanguageChanged: widget.onLanguageChanged,
                          onLcdLanguageChanged: widget.onLcdLanguageChanged,
                          onThemeChanged: widget.onThemeChanged,
                          onColorProfileChanged: widget.onColorProfileChanged,
                          onOpenGithub: _openGithub,
                        ),
                        const SizedBox(height: 16),
                        _DeviceList(
                          strings: widget.strings,
                          results: _scanResults,
                          isScanning: _isScanning,
                          isConnecting: _isConnecting,
                          selectedId: _device?.remoteId.str,
                          onScan: _startScan,
                          onConnect: _connect,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AnimatedCard extends StatefulWidget {
  const _AnimatedCard({required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: child,
          ),
        );
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          scale: _hovered ? 1.01 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Card(color: widget.color, child: widget.child),
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.strings,
    required this.language,
    required this.lcdLanguage,
    required this.themeChoice,
    required this.colorProfile,
    required this.onLanguageChanged,
    required this.onLcdLanguageChanged,
    required this.onThemeChanged,
    required this.onColorProfileChanged,
    required this.onOpenGithub,
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
  final VoidCallback onOpenGithub;

  @override
  Widget build(BuildContext context) {
    return _AnimatedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.settings,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: strings.github,
                  onPressed: onOpenGithub,
                  icon: const Icon(Icons.open_in_new),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SettingLabel(strings.interfaceLanguage),
            const SizedBox(height: 8),
            SegmentedButton<AppLanguage>(
              segments: const [
                ButtonSegment(value: AppLanguage.ru, label: Text('RU')),
                ButtonSegment(value: AppLanguage.en, label: Text('EN')),
              ],
              selected: {language},
              onSelectionChanged: (selected) =>
                  onLanguageChanged(selected.first),
            ),
            const SizedBox(height: 16),
            _SettingLabel(strings.lcdLanguage),
            const SizedBox(height: 8),
            SegmentedButton<LcdLanguage>(
              segments: const [
                ButtonSegment(value: LcdLanguage.ru, label: Text('RU')),
                ButtonSegment(value: LcdLanguage.en, label: Text('EN')),
              ],
              selected: {lcdLanguage},
              onSelectionChanged: (selected) =>
                  onLcdLanguageChanged(selected.first),
            ),
            const SizedBox(height: 16),
            _SettingLabel(strings.theme),
            const SizedBox(height: 8),
            SegmentedButton<AppThemeChoice>(
              segments: [
                ButtonSegment(
                  value: AppThemeChoice.system,
                  icon: const Icon(Icons.brightness_auto),
                  label: Text(strings.system),
                ),
                ButtonSegment(
                  value: AppThemeChoice.light,
                  icon: const Icon(Icons.light_mode),
                  label: Text(strings.light),
                ),
                ButtonSegment(
                  value: AppThemeChoice.dark,
                  icon: const Icon(Icons.dark_mode),
                  label: Text(strings.dark),
                ),
              ],
              selected: {themeChoice},
              onSelectionChanged: (selected) => onThemeChanged(selected.first),
            ),
            const SizedBox(height: 16),
            _SettingLabel(strings.colorProfile),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ColorProfile.values.map((profile) {
                final selected = profile == colorProfile;
                return Tooltip(
                  message: profile.name,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onColorProfileChanged(profile),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 42,
                      height: 34,
                      decoration: BoxDecoration(
                        color: profile.seedColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: [
                          if (selected)
                            BoxShadow(
                              color: profile.seedColor.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: selected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
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
    return Text(label, style: Theme.of(context).textTheme.labelLarge);
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    super.key,
    required this.status,
    required this.strings,
    required this.connected,
    required this.hasArduinoData,
    required this.snapshot,
    required this.lastLine,
    required this.onFeed,
    required this.onSyncTime,
    required this.onPing,
    required this.weatherCityController,
    required this.weatherStatus,
    required this.isUpdatingWeather,
    required this.onSendWeather,
  });

  final String status;
  final AppStrings strings;
  final bool connected;
  final bool hasArduinoData;
  final DeviceSnapshot snapshot;
  final String lastLine;
  final VoidCallback? onFeed;
  final VoidCallback? onSyncTime;
  final VoidCallback? onPing;
  final TextEditingController weatherCityController;
  final String weatherStatus;
  final bool isUpdatingWeather;
  final VoidCallback? onSendWeather;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm:ss');
    final updated = snapshot.updatedAt == null
        ? strings.noDataYet
        : formatter.format(snapshot.updatedAt!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AnimatedCard(
          color: hasArduinoData
              ? const Color(0xFFE2F2EC)
              : connected
              ? const Color(0xFFFFF7DD)
              : const Color(0xFFFFF0D7),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      connected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        status,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StateChip(
                      icon: Icons.bluetooth,
                      label: connected
                          ? strings.bleConnected
                          : strings.bleDisconnected,
                      active: connected,
                    ),
                    _StateChip(
                      icon: Icons.developer_board,
                      label: hasArduinoData
                          ? strings.arduinoData
                          : strings.waitingArduino,
                      active: hasArduinoData,
                    ),
                  ],
                ),
                if (connected && !hasArduinoData) ...[
                  const SizedBox(height: 12),
                  Text(
                    strings.arduinoHelp,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.thermostat,
                label: strings.temperature,
                value: snapshot.temperature == null
                    ? '-- °C'
                    : '${snapshot.temperature!.toStringAsFixed(1)} °C',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.water_drop,
                label: strings.humidity,
                value: snapshot.humidity == null
                    ? '-- %'
                    : '${snapshot.humidity!.toStringAsFixed(0)} %',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _AnimatedCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        strings.weatherForScreen,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: weatherCityController,
                  decoration: InputDecoration(labelText: strings.city),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSendWeather?.call(),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: isUpdatingWeather ? null : onSendWeather,
                      icon: Icon(
                        isUpdatingWeather ? Icons.hourglass_top : Icons.send,
                      ),
                      label: Text(strings.sendWeather),
                    ),
                    Text(weatherStatus),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _AnimatedCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.smart_toy),
                    const SizedBox(width: 8),
                    Text(
                      strings.tamagotchi,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ProgressLine(
                  label: strings.hunger,
                  value: snapshot.hungerPercent,
                ),
                const SizedBox(height: 10),
                _ProgressLine(
                  label: strings.mood,
                  value: snapshot.happinessPercent,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: onFeed,
                      icon: const Icon(Icons.restaurant),
                      label: Text(strings.feed),
                    ),
                    OutlinedButton.icon(
                      onPressed: onSyncTime,
                      icon: const Icon(Icons.schedule),
                      label: Text(strings.syncTime),
                    ),
                    OutlinedButton.icon(
                      onPressed: onPing,
                      icon: const Icon(Icons.network_ping),
                      label: const Text('PING Arduino'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _AnimatedCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.lastUpdate,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(updated),
                const SizedBox(height: 12),
                Text(
                  lastLine.isEmpty ? strings.waitingJson : lastLine,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({
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
    return Chip(
      avatar: Icon(
        icon,
        size: 18,
        color: active ? colors.onPrimaryContainer : colors.onSurfaceVariant,
      ),
      label: Text(label),
      backgroundColor: active
          ? colors.primaryContainer
          : colors.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _AnimatedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 12),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            FittedBox(
              alignment: Alignment.centerLeft,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    axis: Axis.horizontal,
                    child: child,
                  ),
                ),
                child: Text(
                  value,
                  key: ValueKey(value),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.label, required this.value});

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    final normalized = (value ?? 0).clamp(0, 100) / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(value == null ? '-- %' : '$value %'),
          ],
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value == null ? 0 : normalized),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          builder: (context, animatedValue, _) {
            return LinearProgressIndicator(
              minHeight: 10,
              borderRadius: BorderRadius.circular(4),
              value: value == null ? null : animatedValue,
            );
          },
        ),
      ],
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({
    required this.strings,
    required this.results,
    required this.isScanning,
    required this.isConnecting,
    required this.selectedId,
    required this.onScan,
    required this.onConnect,
  });

  final AppStrings strings;
  final List<ScanResult> results;
  final bool isScanning;
  final bool isConnecting;
  final String? selectedId;
  final VoidCallback onScan;
  final ValueChanged<ScanResult> onConnect;

  @override
  Widget build(BuildContext context) {
    return _AnimatedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.devices,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: strings.refresh,
                  onPressed: isScanning ? null : onScan,
                  icon: Icon(
                    isScanning ? Icons.bluetooth_searching : Icons.refresh,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isScanning) const LinearProgressIndicator(),
            if (!isScanning && results.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(strings.scanEmpty),
              ),
            ...results.map((result) {
              final device = result.device;
              final name = device.platformName.trim().isEmpty
                  ? strings.unnamedHm10
                  : device.platformName.trim();
              final selected = selectedId == device.remoteId.str;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(selected ? Icons.check_circle : Icons.bluetooth),
                title: Text(name),
                subtitle: Text('${device.remoteId.str} · RSSI ${result.rssi}'),
                trailing: FilledButton(
                  onPressed: isConnecting ? null : () => onConnect(result),
                  child: Text(selected ? strings.ready : strings.connect),
                ),
              );
            }),
          ],
        ),
      ),
    );
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
