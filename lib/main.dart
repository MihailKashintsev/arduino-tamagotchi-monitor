import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const TamagotchiMonitorApp());
}

class TamagotchiMonitorApp extends StatelessWidget {
  const TamagotchiMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0A7C78),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Arduino Pet Link',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F7F1),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      home: const MonitorPage(),
    );
  }
}

class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key});

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
  String _status = 'Не подключено';
  String _weatherStatus = 'Город можно изменить перед отправкой.';
  String _lastLine = '';
  DeviceSnapshot _snapshot = DeviceSnapshot.empty();

  @override
  void initState() {
    super.initState();
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
      _status = 'Сканирование Bluetooth LE...';
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _status = _device == null ? 'Выберите HM-10 из списка' : _status;
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
      _status = 'Подключение к ${_deviceName(result.device)}...';
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
            _status = 'Соединение разорвано';
            _device = null;
            _uart = null;
          });
        }
      });

      setState(() {
        _device = device;
        _uart = characteristic;
        _status = 'Подключено к ${_deviceName(device)}, жду данные Arduino';
      });

      try {
        await _sendCommand('TIME:${DateTime.now().toIso8601String()}');
      } catch (error) {
        setState(() => _status = 'Подключено, но время не отправлено: $error');
      }
    } catch (error) {
      setState(() => _status = 'Ошибка подключения: $error');
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
          _status = 'Получаю данные от ${_deviceName(_device!)}';
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
      setState(() => _status = 'Сначала подключитесь к HM-10');
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
      setState(() => _weatherStatus = 'Введите город.');
      return;
    }

    setState(() {
      _isUpdatingWeather = true;
      _weatherStatus = 'Получаю погоду для $cityQuery...';
    });

    try {
      final weather = await _fetchCurrentWeather(cityQuery);
      final displayCity = _asciiForLcd(weather.city);
      await _sendCommand(
        'WEATHER:$displayCity,${weather.temperatureC.toStringAsFixed(1)}',
      );

      if (mounted) {
        setState(() {
          _weatherStatus =
              'Отправлено: $displayCity ${weather.temperatureC.toStringAsFixed(1)} °C';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _weatherStatus = 'Не удалось получить погоду: $error');
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
      throw Exception('город не найден');
    }

    final place = results.first as Map<String, dynamic>;
    final latitude = place['latitude'];
    final longitude = place['longitude'];
    if (latitude is! num || longitude is! num) {
      throw Exception('нет координат города');
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
      throw Exception('нет текущей температуры');
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

  @override
  Widget build(BuildContext context) {
    final connected = _device != null && _uart != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arduino Pet Link'),
        actions: [
          IconButton(
            tooltip: 'Сканировать',
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
                    child: _StatusPanel(
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
                      weatherCityController: _weatherCityController,
                      weatherStatus: _weatherStatus,
                      isUpdatingWeather: _isUpdatingWeather,
                      onSendWeather: connected ? _sendWeatherFromPhone : null,
                    ),
                  ),
                  SizedBox(width: wide ? 16 : 0, height: wide ? 0 : 16),
                  Flexible(
                    fit: wide ? FlexFit.tight : FlexFit.loose,
                    child: _DeviceList(
                      results: _scanResults,
                      isScanning: _isScanning,
                      isConnecting: _isConnecting,
                      selectedId: _device?.remoteId.str,
                      onScan: _startScan,
                      onConnect: _connect,
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

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.status,
    required this.connected,
    required this.hasArduinoData,
    required this.snapshot,
    required this.lastLine,
    required this.onFeed,
    required this.onSyncTime,
    required this.weatherCityController,
    required this.weatherStatus,
    required this.isUpdatingWeather,
    required this.onSendWeather,
  });

  final String status;
  final bool connected;
  final bool hasArduinoData;
  final DeviceSnapshot snapshot;
  final String lastLine;
  final VoidCallback? onFeed;
  final VoidCallback? onSyncTime;
  final TextEditingController weatherCityController;
  final String weatherStatus;
  final bool isUpdatingWeather;
  final VoidCallback? onSendWeather;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm:ss');
    final updated = snapshot.updatedAt == null
        ? 'Данных ещё нет'
        : formatter.format(snapshot.updatedAt!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
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
                          ? 'BLE модуль подключен'
                          : 'BLE отключен',
                      active: connected,
                    ),
                    _StateChip(
                      icon: Icons.developer_board,
                      label: hasArduinoData
                          ? 'Arduino присылает данные'
                          : 'Жду JSON от Arduino',
                      active: hasArduinoData,
                    ),
                  ],
                ),
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
                label: 'Температура',
                value: snapshot.temperature == null
                    ? '-- °C'
                    : '${snapshot.temperature!.toStringAsFixed(1)} °C',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.water_drop,
                label: 'Влажность',
                value: snapshot.humidity == null
                    ? '-- %'
                    : '${snapshot.humidity!.toStringAsFixed(0)} %',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
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
                        'Погода для экрана',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: weatherCityController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Город',
                  ),
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
                      label: const Text('Отправить погоду'),
                    ),
                    Text(weatherStatus),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
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
                      'Тамагочи',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ProgressLine(label: 'Сытость', value: snapshot.hungerPercent),
                const SizedBox(height: 10),
                _ProgressLine(
                  label: 'Настроение',
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
                      label: const Text('Покормить'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onSyncTime,
                      icon: const Icon(Icons.schedule),
                      label: const Text('Синхронизировать время'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Последнее обновление',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(updated),
                const SizedBox(height: 12),
                Text(
                  lastLine.isEmpty
                      ? 'Ожидание строки JSON от Arduino'
                      : lastLine,
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
    return Card(
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
              child: Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium,
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
        LinearProgressIndicator(
          minHeight: 10,
          borderRadius: BorderRadius.circular(4),
          value: value == null ? null : normalized,
        ),
      ],
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({
    required this.results,
    required this.isScanning,
    required this.isConnecting,
    required this.selectedId,
    required this.onScan,
    required this.onConnect,
  });

  final List<ScanResult> results;
  final bool isScanning;
  final bool isConnecting;
  final String? selectedId;
  final VoidCallback onScan;
  final ValueChanged<ScanResult> onConnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'HM-10 устройства',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Обновить',
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Нажмите поиск и включите питание Arduino с HM-10 рядом.',
                ),
              ),
            ...results.map((result) {
              final device = result.device;
              final name = device.platformName.trim().isEmpty
                  ? 'HM-10 без имени'
                  : device.platformName.trim();
              final selected = selectedId == device.remoteId.str;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(selected ? Icons.check_circle : Icons.bluetooth),
                title: Text(name),
                subtitle: Text('${device.remoteId.str} · RSSI ${result.rssi}'),
                trailing: FilledButton(
                  onPressed: isConnecting ? null : () => onConnect(result),
                  child: Text(selected ? 'Готово' : 'Подключить'),
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
