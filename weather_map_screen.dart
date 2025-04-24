import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:w_app/secreats.dart'; // Your OpenWeatherAPIKey

class WeatherMapScreen extends StatefulWidget {
  final String cityName;

  const WeatherMapScreen({super.key, required this.cityName});

  @override
  State<WeatherMapScreen> createState() => _WeatherMapScreenState();
}

class _WeatherMapScreenState extends State<WeatherMapScreen> {
  LatLng? _center;
  List<Widget> _layers = [];
  bool _showTemp = true;
  final MapController _mapController = MapController();
  double _currentZoom = 5.0;

  @override
  void initState() {
    super.initState();
    _fetchCoordinates();
  }

  Future<void> _fetchCoordinates() async {
    try {
      final geocodingRes = await http.get(
        Uri.parse(
          'http://api.openweathermap.org/geo/1.0/direct?q=${widget.cityName}&limit=1&appid=$OpenWeatherAPIKey',
        ),
      );
      if (geocodingRes.statusCode == 200) {
        final geocodingData = jsonDecode(geocodingRes.body);
        if (geocodingData.isNotEmpty) {
          final lat = geocodingData[0]['lat'] as double;
          final lon = geocodingData[0]['lon'] as double;
          setState(() {
            _center = LatLng(lat, lon);
            _fetchWeatherMapLayers();
          });
        }
      }
    } catch (e) {
      print('Error fetching coordinates: $e');
    }
  }

  Future<void> _fetchWeatherMapLayers() async {
    if (_center == null) return;

    final baseLayers = [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.example.w_app',
      ),
    ];

    final weatherLayers = [
      TileLayer(
        urlTemplate:
            'http://tile.openweathermap.org/map/${_showTemp ? 'temp_new' : 'precipitation_new'}/{z}/{x}/{y}.png?appid=$OpenWeatherAPIKey',
        maxZoom: 10,
        tileProvider: CancellableNetworkTileProvider(),
      ),
      TileLayer(
        urlTemplate:
            'http://tile.openweathermap.org/map/clouds_new/{z}/{x}/{y}.png?appid=$OpenWeatherAPIKey',
        maxZoom: 10,
        tileProvider: CancellableNetworkTileProvider(),
      ),
    ];

    setState(() {
      _layers = [...baseLayers, ...weatherLayers];
    });
  }

  void _zoomIn() {
    setState(() {
      _currentZoom = (_currentZoom + 1).clamp(3.0, 10.0);
      _mapController.move(_center!, _currentZoom);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_currentZoom - 1).clamp(3.0, 10.0);
      _mapController.move(_center!, _currentZoom);
    });
  }

  Widget _buildLegend() {
    return Positioned(
      left: 10,
      bottom: 10,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 160),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(10),
            width: 220,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.65),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _showTemp
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("🌡️ Temperature Legend", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      SizedBox(height: 6),
                      Text("🔵 Blue: Cold (< 10°C)", style: TextStyle(color: Colors.white)),
                      Text("🟡 Yellow: Mild (10–25°C)", style: TextStyle(color: Colors.white)),
                      Text("🔴 Red: Hot (> 25°C)", style: TextStyle(color: Colors.white)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("☔ Precipitation Legend", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      SizedBox(height: 6),
                      Text("⚪ Light: Drizzle / Light Rain", style: TextStyle(color: Colors.white)),
                      Text("🔵 Medium: Showers", style: TextStyle(color: Colors.white)),
                      Text("🟣 Heavy: Storms", style: TextStyle(color: Colors.white)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.cityName} Weather Map'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.thermostat),
            tooltip: 'Toggle Temperature / Precipitation',
            onPressed: () {
              setState(() {
                _showTemp = !_showTemp;
                _fetchWeatherMapLayers();
              });
            },
          ),
        ],
      ),
      body: _center == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center!,
                    initialZoom: _currentZoom,
                    minZoom: 3.0,
                    maxZoom: 10.0,
                  ),
                  children: _layers,
                ),
                // Zoom Buttons
                Positioned(
                  right: 10,
                  top: 80,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        mini: true,
                        heroTag: 'zoom_in',
                        onPressed: _zoomIn,
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        mini: true,
                        heroTag: 'zoom_out',
                        onPressed: _zoomOut,
                        child: const Icon(Icons.remove),
                      ),
                    ],
                  ),
                ),
                // Legend Box
                _buildLegend(),
              ],
            ),
    );
  }
}
