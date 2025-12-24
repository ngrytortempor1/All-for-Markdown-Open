/// Weather Plugin
/// 
/// Automatically records weather data for the day
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/plugin_interface.dart';
import '../../core/models/log_entry.dart';
import '../../core/plugin_data_service.dart';

class WeatherPlugin implements MarkdownLoggerPlugin {
  @override
  String get id => 'weather';
  
  @override
  String get name => 'Weather';
  
  @override
  IconData get icon => Icons.wb_sunny;
  
  @override
  String get description => '天気記録';

  final _dataService = PluginDataService('weather');

  @override
  Widget buildWidget(BuildContext context) => WeatherWidget(dataService: _dataService);

  @override
  Widget buildCompactWidget(BuildContext context) => const WeatherCompactWidget();

  @override
  Future<List<LogEntry>> getEntries(DateTime date) async {
    return _dataService.getEntriesForDate(date);
  }

  @override
  Future<void> saveEntry(LogEntry entry) async {
    await _dataService.createEntry(entry.data);
  }

  @override
  Future<void> deleteEntry(String id) async {
    await _dataService.deleteEntry(id);
  }
}

// Weather types with WMO weather codes mapping
const Map<int, Map<String, dynamic>> _wmoWeatherCodes = {
  0: {'id': 'sunny', 'name': '快晴', 'icon': '☀️', 'color': 0xFFFF9800},
  1: {'id': 'sunny', 'name': '晴れ', 'icon': '☀️', 'color': 0xFFFF9800},
  2: {'id': 'partly_cloudy', 'name': '晴れ時々曇り', 'icon': '⛅', 'color': 0xFFFFC107},
  3: {'id': 'cloudy', 'name': '曇り', 'icon': '☁️', 'color': 0xFF9E9E9E},
  45: {'id': 'foggy', 'name': '霧', 'icon': '🌫️', 'color': 0xFF607D8B},
  48: {'id': 'foggy', 'name': '霧氷', 'icon': '🌫️', 'color': 0xFF607D8B},
  51: {'id': 'rainy', 'name': '霧雨', 'icon': '🌧️', 'color': 0xFF2196F3},
  53: {'id': 'rainy', 'name': '霧雨', 'icon': '🌧️', 'color': 0xFF2196F3},
  55: {'id': 'rainy', 'name': '強い霧雨', 'icon': '🌧️', 'color': 0xFF2196F3},
  61: {'id': 'rainy', 'name': '小雨', 'icon': '🌧️', 'color': 0xFF2196F3},
  63: {'id': 'rainy', 'name': '雨', 'icon': '🌧️', 'color': 0xFF2196F3},
  65: {'id': 'rainy', 'name': '大雨', 'icon': '🌧️', 'color': 0xFF2196F3},
  71: {'id': 'snowy', 'name': '小雪', 'icon': '❄️', 'color': 0xFF00BCD4},
  73: {'id': 'snowy', 'name': '雪', 'icon': '❄️', 'color': 0xFF00BCD4},
  75: {'id': 'snowy', 'name': '大雪', 'icon': '❄️', 'color': 0xFF00BCD4},
  77: {'id': 'snowy', 'name': '雪粒', 'icon': '❄️', 'color': 0xFF00BCD4},
  80: {'id': 'rainy', 'name': 'にわか雨', 'icon': '🌧️', 'color': 0xFF2196F3},
  81: {'id': 'rainy', 'name': 'にわか雨', 'icon': '🌧️', 'color': 0xFF2196F3},
  82: {'id': 'rainy', 'name': '激しい雨', 'icon': '🌧️', 'color': 0xFF2196F3},
  85: {'id': 'snowy', 'name': 'にわか雪', 'icon': '❄️', 'color': 0xFF00BCD4},
  86: {'id': 'snowy', 'name': '激しい雪', 'icon': '❄️', 'color': 0xFF00BCD4},
  95: {'id': 'stormy', 'name': '雷雨', 'icon': '⛈️', 'color': 0xFF673AB7},
  96: {'id': 'stormy', 'name': '雷雨と雹', 'icon': '⛈️', 'color': 0xFF673AB7},
  99: {'id': 'stormy', 'name': '雷雨と大粒の雹', 'icon': '⛈️', 'color': 0xFF673AB7},
};

// Manual weather types for fallback
const List<Map<String, dynamic>> _weatherTypes = [
  {'id': 'sunny', 'name': '晴れ', 'icon': '☀️', 'color': 0xFFFF9800},
  {'id': 'cloudy', 'name': '曇り', 'icon': '☁️', 'color': 0xFF9E9E9E},
  {'id': 'rainy', 'name': '雨', 'icon': '🌧️', 'color': 0xFF2196F3},
  {'id': 'snowy', 'name': '雪', 'icon': '❄️', 'color': 0xFF00BCD4},
  {'id': 'stormy', 'name': '雷雨', 'icon': '⛈️', 'color': 0xFF673AB7},
  {'id': 'foggy', 'name': '霧', 'icon': '🌫️', 'color': 0xFF607D8B},
  {'id': 'windy', 'name': '強風', 'icon': '💨', 'color': 0xFF00BCD4},
  {'id': 'partly_cloudy', 'name': '晴れ時々曇り', 'icon': '⛅', 'color': 0xFFFFC107},
];

class WeatherWidget extends StatefulWidget {
  final PluginDataService dataService;
  
  const WeatherWidget({super.key, required this.dataService});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  String? _selectedWeather;
  String? _weatherName;
  String? _weatherIcon;
  int _temperature = 20;
  int _humidity = 50;
  List<LogEntry> _entries = [];
  bool _loading = true;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    
    final entries = await widget.dataService.getTodayEntries();
    
    if (entries.isNotEmpty) {
      final last = entries.last;
      setState(() {
        _selectedWeather = last.data['weather'] as String?;
        _weatherName = last.data['weatherName'] as String?;
        _weatherIcon = last.data['icon'] as String?;
        _temperature = last.data['temperature'] as int? ?? 20;
        _humidity = last.data['humidity'] as int? ?? 50;
      });
    } else {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _selectedWeather = prefs.getString('weather_last');
        _temperature = prefs.getInt('weather_temp') ?? 20;
        _humidity = prefs.getInt('weather_humidity') ?? 50;
      });
    }
    
    setState(() {
      _entries = entries.reversed.toList();
      _loading = false;
    });
  }

  /// Fetch weather from Open-Meteo API (free, no API key required)
  Future<void> _fetchWeatherFromAPI() async {
    setState(() => _fetching = true);
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw '位置情報サービスが無効です';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw '位置情報の許可が必要です';
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw '位置情報の許可が永久に拒否されています。設定から許可してください。';
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${position.latitude}'
        '&longitude=${position.longitude}'
        '&current=temperature_2m,relative_humidity_2m,weather_code'
        '&timezone=Asia/Tokyo'
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current'];
        
        final temp = (current['temperature_2m'] as num).round();
        final humidity = (current['relative_humidity_2m'] as num).round();
        final weatherCode = current['weather_code'] as int;
        
        final weatherData = _wmoWeatherCodes[weatherCode] ?? 
            {'id': 'cloudy', 'name': '曇り', 'icon': '☁️', 'color': 0xFF9E9E9E};

        setState(() {
          _temperature = temp;
          _humidity = humidity;
          _selectedWeather = weatherData['id'] as String;
          _weatherName = weatherData['name'] as String;
          _weatherIcon = weatherData['icon'] as String;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${weatherData['icon']} 現在の天気: ${weatherData['name']} $temp°C')),
          );
        }
      } else {
        throw 'APIエラー: ${response.statusCode}';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('天気取得エラー: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _fetching = false);
    }
  }

  Future<void> _recordWeather() async {
    if (_selectedWeather == null) return;

    final weatherData = _weatherTypes.firstWhere(
      (w) => w['id'] == _selectedWeather,
      orElse: () => {'id': _selectedWeather, 'name': _weatherName ?? '', 'icon': _weatherIcon ?? '☁️'},
    );

    await widget.dataService.createEntry({
      'weather': _selectedWeather,
      'weatherName': _weatherName ?? weatherData['name'],
      'icon': _weatherIcon ?? weatherData['icon'],
      'temperature': _temperature,
      'humidity': _humidity,
      'time': DateFormat('HH:mm').format(DateTime.now()),
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('weather_last', _selectedWeather!);
    await prefs.setInt('weather_temp', _temperature);
    await prefs.setInt('weather_humidity', _humidity);

    await _loadData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_weatherIcon ?? '☁️'} ${_weatherName ?? ''}を記録しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final selectedData = _selectedWeather != null
        ? _weatherTypes.firstWhere(
            (w) => w['id'] == _selectedWeather,
            orElse: () => {'id': _selectedWeather, 'name': _weatherName ?? '', 'icon': _weatherIcon ?? '☁️', 'color': 0xFF9E9E9E},
          )
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _fetching ? null : _fetchWeatherFromAPI,
              icon: _fetching 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.location_on),
              label: Text(_fetching ? '取得中...' : '📍 現在地の天気を自動取得'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: selectedData != null
                    ? [
                        Color(selectedData['color'] as int).withAlpha(80),
                        Color(selectedData['color'] as int).withAlpha(30),
                      ]
                    : [Colors.blue.withAlpha(50), Colors.blue.withAlpha(20)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Text(
                  _weatherIcon ?? selectedData?['icon'] ?? '🌤️',
                  style: const TextStyle(fontSize: 64),
                ),
                const SizedBox(height: 8),
                Text(
                  _weatherName ?? selectedData?['name'] ?? '天気を選択',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        const Text('🌡️', style: TextStyle(fontSize: 20)),
                        Text(
                          '$_temperature°C',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(width: 32),
                    Column(
                      children: [
                        const Text('💧', style: TextStyle(fontSize: 20)),
                        Text(
                          '$_humidity%',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          ExpansionTile(
            title: const Text('手動で選択', style: TextStyle(fontWeight: FontWeight.bold)),
            initiallyExpanded: false,
            children: [
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _weatherTypes.map((w) {
                  final isSelected = _selectedWeather == w['id'];
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedWeather = w['id'] as String;
                      _weatherName = w['name'] as String;
                      _weatherIcon = w['icon'] as String;
                    }),
                    child: Container(
                      width: 70,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Color(w['color'] as int).withAlpha(50)
                            : Colors.grey.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: Color(w['color'] as int), width: 2)
                            : null,
                      ),
                      child: Column(
                        children: [
                          Text(w['icon'] as String, style: const TextStyle(fontSize: 28)),
                          const SizedBox(height: 4),
                          Text(
                            w['name'] as String,
                            style: const TextStyle(fontSize: 10),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  const Text('🌡️ 気温'),
                  Expanded(
                    child: Slider(
                      value: _temperature.toDouble(),
                      min: -20,
                      max: 45,
                      divisions: 65,
                      label: '$_temperature°C',
                      onChanged: (v) => setState(() => _temperature = v.round()),
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text('$_temperature°C', textAlign: TextAlign.right),
                  ),
                ],
              ),

              Row(
                children: [
                  const Text('💧 湿度'),
                  Expanded(
                    child: Slider(
                      value: _humidity.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: '$_humidity%',
                      onChanged: (v) => setState(() => _humidity = v.round()),
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text('$_humidity%', textAlign: TextAlign.right),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),

          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _selectedWeather != null ? _recordWeather : null,
            icon: const Icon(Icons.save),
            label: const Text('記録'),
          ),

          const SizedBox(height: 24),

          if (_entries.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('今日の記録', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _entries.take(5).length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
                final icon = entry.data['icon'] as String? ?? '🌤️';
                final name = entry.data['weatherName'] as String? ?? '';
                final temp = entry.data['temperature'] as int? ?? 0;
                final humidity = entry.data['humidity'] as int? ?? 0;
                final time = entry.data['time'] as String? ?? '';

                return ListTile(
                  leading: Text(icon, style: const TextStyle(fontSize: 28)),
                  title: Text(name),
                  subtitle: Text('$temp°C / $humidity% - $time'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () async {
                      await widget.dataService.deleteEntry(entry.id);
                      await _loadData();
                    },
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class WeatherCompactWidget extends StatelessWidget {
  const WeatherCompactWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.wb_sunny, color: Colors.orange),
        title: Text('Weather'),
        subtitle: Text('天気記録'),
      ),
    );
  }
}
