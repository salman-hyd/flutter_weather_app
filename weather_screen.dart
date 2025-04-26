import 'dart:convert'; // Provides JSON encoding/decoding functions (jsonDecode)
import 'dart:io' show Platform, Directory; // Allows platform-specific checks and directory access
import 'package:flutter/material.dart'; // Core Flutter framework
import 'package:http/http.dart' as http; // Enables HTTP requests
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Manages notifications
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart'; // Added for animations
import 'package:permission_handler/permission_handler.dart'; // Added for permission management
import 'package:speech_to_text/speech_to_text.dart'; // Added for speech recognition
import 'package:geolocator/geolocator.dart'; // Added for geolocation
import 'package:hive/hive.dart'; // Added for offline caching
import 'package:hive_flutter/hive_flutter.dart'; // Added for offline caching
import 'package:path_provider/path_provider.dart'; // Added to get app directory
import 'package:w_app/secreats.dart'; // API key (OpenWeatherAPIKey)
import 'package:w_app/timely_forcast_item.dart'; // Custom widget
import 'package:w_app/additional_info_item.dart'; // Custom widget
import 'package:w_app/aqi_ui.dart'; // AQI UI component
import 'package:w_app/weather_map_screen.dart'; // New screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter bindings are initialized
  // Initialize Hive with a valid path
  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path); // Explicitly set the storage path
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App',
      theme: _WeatherScreenState()._isDarkMode
          ? ThemeData.dark().copyWith(
              primaryColor: Colors.blue,
              scaffoldBackgroundColor: Colors.grey[900],
              cardColor: Colors.grey[800],
              textTheme: const TextTheme(
                bodyMedium: TextStyle(color: Colors.white70, fontFamily: 'Roboto'),
                titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Roboto'),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.blueGrey,
              ),
            )
          : ThemeData(
              primarySwatch: Colors.blue,
              scaffoldBackgroundColor: Colors.white,
              cardColor: Colors.white,
              textTheme: const TextTheme(
                bodyMedium: TextStyle(color: Colors.black87, fontFamily: 'Roboto'),
                titleLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Roboto'),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.blueGrey,
              ),
            ),
      home: const WeatherScreen(),
    );
  }
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final TextEditingController _cityController = TextEditingController();
  String _cityName = 'Hyderabad';
  bool _isWeatherVisible = false;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _notificationsEnabled = true;
  bool _isWeatherValid = false; // Track weather validity
  final SpeechToText _speechToText = SpeechToText(); // Speech recognition instance
  bool _isListening = false; // Track microphone state
  bool _hasSpeechPermission = false; // Track microphone permission status
  bool _hasLocationPermission = false; // Track location permission status
  Position? _currentPosition; // Store current position (lat, lon)
  bool _useGeolocation = true; // Toggle for geolocation usage
  bool _isDarkMode = false; // Toggle for dark mode
  late Box _weatherCacheBox; // Store the Hive box
  bool _isHiveInitialized = false; // Track Hive initialization status

  @override
  void initState() {
    super.initState();
    _initializeApp(); // Initialize app components
  }

  // Initialize Hive, permissions, and notifications
  Future<void> _initializeApp() async {
    // Initialize Hive
    await _initializeHiveBox();
    setState(() {
      _isHiveInitialized = true; // Mark Hive as initialized
    });

    // Request permissions and initialize notifications
    await _requestMicrophonePermission();
    await _requestLocationPermission();
    await _initializeNotifications();

    // Fetch weather after everything is ready
    if (_useGeolocation) {
      await _getCurrentLocationAndFetchWeather();
    } else {
      await _fetchWeatherAndUpdate();
    }
  }

  // Initialize Hive box
  Future<void> _initializeHiveBox() async {
    try {
      _weatherCacheBox = await Hive.openBox('weatherCache');
    } catch (e) {
      print('Hive initialization error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize cache: $e')),
      );
      // Fallback: Retry with explicit path if needed
      final appDocumentDir = await getApplicationDocumentsDirectory();
      await Hive.initFlutter(appDocumentDir.path); // Reinitialize with path
      _weatherCacheBox = await Hive.openBox('weatherCache');
    }
  }

  // Request microphone permission
  Future<void> _requestMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
    setState(() {
      _hasSpeechPermission = status.isGranted;
    });
    if (!_hasSpeechPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required for voice input.'),
        ),
      );
    }
  }

  // Request location permission
  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission denied. Using default city.'),
          ),
        );
        setState(() {
          _hasLocationPermission = false;
        });
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission permanently denied. Please enable in settings.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: openAppSettings,
          ),
        ),
      );
      setState(() {
        _hasLocationPermission = false;
      });
      return;
    }
    setState(() {
      _hasLocationPermission = true;
    });
  }

  // Fetch current location and update weather
  Future<void> _getCurrentLocationAndFetchWeather() async {
    if (!_hasLocationPermission || !_useGeolocation) {
      await _fetchWeatherAndUpdate(); // Fallback to default city if no permission or geolocation disabled
      return;
    }
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final city = await _getCityFromCoordinates(_currentPosition!.latitude, _currentPosition!.longitude);
      setState(() {
        _cityName = city;
        _cityController.text = city;
      });
      await _fetchWeatherAndUpdate();
    } catch (e) {
      print('Location error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e. Using default city.')),
      );
      await _fetchWeatherAndUpdate(); // Fallback to default city
    }
  }

  // Reverse geocoding to get city from coordinates
  Future<String> _getCityFromCoordinates(double latitude, double longitude) async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://api.openweathermap.org/geo/1.0/reverse?lat=$latitude&lon=$longitude&limit=1&appid=$OpenWeatherAPIKey',
        ),
      );
      if (response.statusCode != 200) {
        throw 'Reverse geocoding failed with status ${response.statusCode}';
      }
      final data = jsonDecode(response.body);
      if (data.isEmpty) {
        throw 'No city found for coordinates ($latitude, $longitude)';
      }
      return data[0]['name'] as String;
    } catch (e) {
      throw 'Error getting city from coordinates: $e';
    }
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _notificationsPlugin.initialize(initSettings);

    if (Platform.isAndroid) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  Future<Map<String, dynamic>> _getCoordinates(String city) async {
    try {
      final geocodingRes = await http.get(
        Uri.parse(
          'http://api.openweathermap.org/geo/1.0/direct?q=$city&limit=1&appid=$OpenWeatherAPIKey',
        ),
      );
      if (geocodingRes.statusCode != 200) {
        throw 'Geocoding API request failed with status ${geocodingRes.statusCode}';
      }
      final geocodingData = jsonDecode(geocodingRes.body);
      if (geocodingData.isEmpty) {
        throw 'City not found: $city';
      }
      final lat = geocodingData[0]['lat'];
      final lon = geocodingData[0]['lon'];
      return {'lat': lat, 'lon': lon};
    } catch (e) {
      throw e.toString();
    }
  }

  Future<Map<String, dynamic>> getCurrentWeather() async {
    // Validate city name
    if (_cityName.isEmpty || _cityName.trim().isEmpty) {
      throw 'City name cannot be empty';
    }

    // Validate API key
    if (OpenWeatherAPIKey == null || OpenWeatherAPIKey.isEmpty) {
      throw 'Invalid API key';
    }

    // Sanitize city name for URL
    final sanitizedCityName = Uri.encodeComponent(_cityName.trim());

    try {
      final currentRes = await http.get(
        Uri.parse(
          'https://api.openweathermap.org/data/2.5/forecast?q=$sanitizedCityName&appid=$OpenWeatherAPIKey',
        ),
      );
      if (currentRes.statusCode != 200) {
        throw 'OpenWeather API request failed with status ${currentRes.statusCode}';
      }
      final currentData = jsonDecode(currentRes.body);
      if (currentData['cod'] != '200') {
        throw 'City not found or an unexpected error occurred: ${currentData['message']}';
      }

      final coords = await _getCoordinates(_cityName);
      final latitude = coords['lat'];
      final longitude = coords['lon'];

      final airQualityRes = await http.get(
        Uri.parse(
          'http://api.openweathermap.org/data/2.5/air_pollution?lat=$latitude&lon=$longitude&appid=$OpenWeatherAPIKey',
        ),
      );
      if (airQualityRes.statusCode != 200) {
        throw 'Air Pollution API request failed with status ${airQualityRes.statusCode}';
      }
      final airQualityData = jsonDecode(airQualityRes.body);

      return {
        'current': currentData['list'][0], // Current weather data
        'airQuality': airQualityData['list'][0], // Current air quality data
        'forecastList': currentData['list'], // Full forecast list
      };
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> _fetchWeatherAndUpdate() async {
    // Wait for Hive initialization if not ready
    if (!_isHiveInitialized) {
      print('Waiting for Hive initialization...');
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return !_isHiveInitialized;
      });
    }

    try {
      final data = await getCurrentWeather();
      await _weatherCacheBox.put('weatherData', {
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
      setState(() {
        _isWeatherVisible = true;
        _isWeatherValid = true;
      });
      _checkWeatherAndNotify(data['current']);
    } catch (e) {
      print('Fetch error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch weather: $e')),
      );
      try {
        final cachedData = _weatherCacheBox.get('weatherData');
        if (cachedData != null && DateTime.now().difference(DateTime.parse(cachedData['timestamp'])).inHours < 24) {
          setState(() {
            _isWeatherVisible = true;
            _isWeatherValid = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Showing cached data (last updated: ${cachedData['timestamp']})')),
          );
        } else {
          setState(() {
            _isWeatherValid = false;
          });
        }
      } catch (cacheError) {
        print('Cache error: $cacheError');
        setState(() {
          _isWeatherValid = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to access cached data')),
        );
      }
    }
  }

  Future<void> _checkWeatherAndNotify(Map<String, dynamic> currentData) async {
    if (!_notificationsEnabled) return;
    try {
      final currentSky = currentData['weather'][0]['main'];
      final currentTemp = (currentData['main']['temp'] - 273.15).round();

      String title = 'Weather Alert';
      String? body;

      if (currentSky == 'Rain') {
        body = 'Take an umbrella, it’s rainy out there!';
      } else if (currentSky == 'Clear' && currentTemp > 25) {
        body = 'Light clothes today—it’s sunny!';
      } else if (currentTemp < 10) {
        body = 'Bundle up, it’s cold—grab a jacket!';
      } else {
        return;
      }

      await _notificationsPlugin.show(
        0,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'weather_channel',
            'Weather Updates',
            channelDescription: 'Notifications for weather conditions',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  void _updateCityWeather() {
    setState(() {
      _cityName = _cityController.text.isEmpty ? 'Hyderabad' : _cityController.text;
      _isWeatherVisible = false;
    });
    _fetchWeatherAndUpdate();
  }

  Future<void> _startListening() async {
    if (!_hasSpeechPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission denied. Please enable it in settings.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: openAppSettings,
          ),
        ),
      );
      return;
    }

    if (!_isListening) {
      bool available = await _speechToText.initialize(
        onStatus: (status) => print('Speech status: $status'),
        onError: (error) => print('Speech error: ${error.errorMsg} [Permanent: ${error.permanent}]'),
      );
      if (available) {
        setState(() => _isListening = true);
        try {
          await _speechToText.listen(
            onResult: (result) {
              setState(() {
                _cityController.text = result.recognizedWords
                    .replaceAll(RegExp(r'show weather for|weather for', caseSensitive: false), '')
                    .trim();
                _isListening = false;
              });
              if (_cityController.text.isNotEmpty) {
                _updateCityWeather();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No city recognized. Please try again.')),
                );
              }
            },
            localeId: 'en_US',
            listenFor: const Duration(seconds: 10),
            cancelOnError: true,
            partialResults: true,
          );
        } catch (e) {
          print('Listening error: $e');
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start listening: $e')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available on this device.')),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speechToText.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Weather App',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
            fontFamily: 'Roboto',
          ),
        ),
        centerTitle: true,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isHiveInitialized
                ? () {
                    setState(() {
                      _isWeatherVisible = false;
                    });
                    if (_useGeolocation) {
                      _getCurrentLocationAndFetchWeather();
                    } else {
                      _fetchWeatherAndUpdate();
                    }
                  }
                : null, // Disable button until Hive is initialized
          ),
          IconButton(
            icon: const Icon(Icons.map, color: Colors.white),
            onPressed: _isHiveInitialized
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WeatherMapScreen(cityName: _cityName),
                      ),
                    );
                  }
                : null, // Disable button until Hive is initialized
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings, color: Colors.white),
            onSelected: (String result) {
              setState(() {
                if (result == 'notifications') _notificationsEnabled = !_notificationsEnabled;
                if (result == 'location') _useGeolocation = !_useGeolocation;
                if (result == 'darkMode') _isDarkMode = !_isDarkMode;
                if (_useGeolocation && _hasLocationPermission && result == 'location') {
                  _getCurrentLocationAndFetchWeather();
                } else if (result == 'location') {
                  _cityName = 'Hyderabad';
                  _cityController.text = '';
                  _fetchWeatherAndUpdate();
                }
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              CheckedPopupMenuItem<String>(
                value: 'notifications',
                checked: _notificationsEnabled,
                child: const Text('Weather Alerts'),
              ),
              CheckedPopupMenuItem<String>(
                value: 'location',
                checked: _useGeolocation,
                child: const Text('Use Location'),
              ),
              CheckedPopupMenuItem<String>(
                value: 'darkMode',
                checked: _isDarkMode,
                child: const Text('Dark Mode'),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: _isDarkMode
              ? LinearGradient(
                  colors: [Colors.grey[900]!, Colors.grey[700]!],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : LinearGradient(
                  colors: [Colors.blue[100]!, Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: TextField(
                  controller: _cityController,
                  style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Enter city name (e.g., London)',
                    hintStyle: TextStyle(color: _isDarkMode ? Colors.white54 : Colors.grey),
                    prefixIcon: Icon(Icons.location_city, color: _isDarkMode ? Colors.lightBlueAccent : Colors.blueAccent),
                    filled: true,
                    fillColor: _isDarkMode ? Colors.grey[800] : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.search, color: _isDarkMode ? Colors.lightBlueAccent : Colors.blueAccent),
                          onPressed: _isHiveInitialized ? _updateCityWeather : null, // Disable until Hive is initialized
                        ),
                        IconButton(
                          icon: Icon(
                            _isListening ? Icons.mic_off : Icons.mic,
                            color: _isListening ? Colors.red : (_isDarkMode ? Colors.lightBlueAccent : Colors.blueAccent),
                          ),
                          onPressed: _startListening,
                        ),
                      ],
                    ),
                  ),
                  onSubmitted: (_) => _isHiveInitialized ? _updateCityWeather() : null,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: _isWeatherVisible
                      ? FutureBuilder<Map<String, dynamic>>(
                          future: getCurrentWeather(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                                ),
                              );
                            }
                            if (snapshot.hasError || !_isWeatherValid) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      snapshot.error?.toString() ?? 'Invalid weather data',
                                      style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87),
                                    ),
                                    backgroundColor: _isDarkMode ? Colors.red[700] : Colors.redAccent,
                                  ),
                                );
                              });
                              return const Center(
                                child: Text(
                                  'Error fetching weather',
                                  style: TextStyle(color: Colors.redAccent, fontSize: 18),
                                ),
                              );
                            }

                            final data = snapshot.data!;
                            final currentWeatherData = data['current'];
                            final currentTemp = (currentWeatherData['main']['temp'] as num? ?? 0.0).toDouble() - 273.15;
                            final currentSky = currentWeatherData['weather'][0]['main'] ?? 'Unknown';
                            final currentPressure = (currentWeatherData['main']['pressure'] as num? ?? 0.0).toDouble();
                            final currentWindSpeed = (currentWeatherData['wind']['speed'] as num? ?? 0.0).toDouble();
                            final currentHumidity = currentWeatherData['main']['humidity'] as int? ?? 0;
                            final airQualityData = data['airQuality'];
                            final rawAQI = airQualityData['main']['aqi'];
                            final currentAQI = rawAQI != null
                                ? (rawAQI is num ? rawAQI.toInt() : int.tryParse(rawAQI.toString()) ?? 1)
                                : 1;
                            final currentPM25 = (airQualityData['components']['pm2_5'] as num? ?? 0.0).toDouble();
                            final currentPM10 = (airQualityData['components']['pm10'] as num? ?? 0.0).toDouble();
                            final forecastList = data['forecastList'] as List<dynamic>;
                            final prediction = _getWeatherPrediction(forecastList);

                            String currentAnimationPath;
                            switch (currentSky.toLowerCase()) {
                              case 'thunderstorm':
                                currentAnimationPath = 'assets/animations/thunderstorm.json';
                                break;
                              case 'rain':
                                currentAnimationPath = 'assets/animations/rain.json';
                                break;
                              case 'clouds':
                              case 'partlycloudy':
                                currentAnimationPath = 'assets/animations/cloudy.json';
                                break;
                              case 'clear':
                                currentAnimationPath = 'assets/animations/sunny.json';
                                break;
                              default:
                                currentAnimationPath = 'assets/animations/unknown.json';
                            }

                            return ListView(
                              padding: const EdgeInsets.only(bottom: 16),
                              children: [
                                Card(
                                  elevation: 8,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  color: _isDarkMode ? Colors.grey[800] : Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      children: [
                                        Text(
                                          _cityName.toUpperCase(),
                                          style: Theme.of(context).textTheme.titleLarge!.copyWith(
                                                color: _isDarkMode ? Colors.lightBlueAccent : Colors.blueAccent,
                                              ),
                                        ),
                                        const SizedBox(height: 15),
                                        Text(
                                          '${currentTemp.round()}°C',
                                          style: Theme.of(context).textTheme.titleLarge!.copyWith(
                                                fontSize: 48,
                                                color: _isDarkMode ? Colors.white : Colors.black87,
                                              ),
                                        ),
                                        const SizedBox(height: 15),
                                        Lottie.asset(
                                          currentAnimationPath,
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.contain,
                                        ),
                                        const SizedBox(height: 15),
                                        Text(
                                          currentSky,
                                          style: Theme.of(context).textTheme.titleLarge!.copyWith(
                                                fontSize: 24,
                                                color: _isDarkMode ? Colors.white : Colors.black87,
                                              ),
                                        ),
                                        if (prediction.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 15),
                                            child: Text(
                                              'Prediction: $prediction',
                                              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                    color: _isDarkMode ? Colors.white70 : Colors.grey,
                                                  ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Card(
                                  elevation: 6,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  color: _isDarkMode ? Colors.grey[800] : Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Weather Forecast",
                                          style: Theme.of(context).textTheme.titleLarge!.copyWith(
                                                color: _isDarkMode ? Colors.white : Colors.black87,
                                              ),
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          height: 120,
                                          child: ListView.builder(
                                            itemCount: forecastList.length > 30 ? 30 : forecastList.length - 1,
                                            scrollDirection: Axis.horizontal,
                                            itemBuilder: (context, index) {
                                              final hourlyForecast = forecastList[index + 1];
                                              final hourlySky = hourlyForecast['weather'][0]['main'] ?? 'Unknown';
                                              final time = DateTime.parse(hourlyForecast['dt_txt']);
                                              String hourlyAnimationPath;
                                              switch (hourlySky.toLowerCase()) {
                                                case 'thunderstorm':
                                                  hourlyAnimationPath = 'assets/animations/thunderstorm.json';
                                                  break;
                                                case 'rain':
                                                case 'drizzle':
                                                  hourlyAnimationPath = 'assets/animations/rain.json';
                                                  break;
                                                case 'clouds':
                                                case 'partly cloudy':
                                                  hourlyAnimationPath = 'assets/animations/cloudy.json';
                                                  break;
                                                case 'clear':
                                                  hourlyAnimationPath = 'assets/animations/sunny.json';
                                                  break;
                                                default:
                                                  hourlyAnimationPath = 'assets/animations/unknown.json';
                                              }
                                              return HourlyForcastItem(
                                                time: DateFormat.j().format(time),
                                                temperature: '${(hourlyForecast['main']['temp'] - 273.15).round()}°C',
                                                icon: Icons.wb_sunny,
                                                child: Lottie.asset(
                                                  hourlyAnimationPath,
                                                  width: 50,
                                                  height: 50,
                                                  fit: BoxFit.contain,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Card(
                                  elevation: 6,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  color: _isDarkMode ? Colors.grey[800] : Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: AQIUI(
                                      currentAQI: currentAQI,
                                      currentPM25: currentPM25,
                                      currentPM10: currentPM10,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Card(
                                  elevation: 6,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  color: _isDarkMode ? Colors.grey[800] : Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Additional Information",
                                          style: Theme.of(context).textTheme.titleLarge!.copyWith(
                                                color: _isDarkMode ? Colors.white : Colors.black87,
                                              ),
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            SizedBox(
                                              width: MediaQuery.of(context).size.width * 0.3 - 16, // Adjusted for padding
                                              child: AdditionalInfoItems(
                                                icon: Icons.water_drop,
                                                label: 'Humidity',
                                                value: '$currentHumidity%',
                                              ),
                                            ),
                                            SizedBox(
                                              width: MediaQuery.of(context).size.width * 0.3 - 16,
                                              child: AdditionalInfoItems(
                                                icon: Icons.air,
                                                label: 'Wind Speed',
                                                value: '${currentWindSpeed}m/s',
                                              ),
                                            ),
                                            SizedBox(
                                              width: MediaQuery.of(context).size.width * 0.3 - 16,
                                              child: AdditionalInfoItems(
                                                icon: Icons.beach_access,
                                                label: 'Pressure',
                                                value: '${currentPressure}hPa',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getWeatherPrediction(List<dynamic> forecastList) {
    if (forecastList.length < 24) return 'Insufficient data for prediction';
    final next24Hours = forecastList.sublist(1, 25); // Next 24 hours
    final temperatures = next24Hours.map((f) => (f['main']['temp'] as num? ?? 0.0).toDouble() - 273.15).toList();
    final conditions = next24Hours.map((f) => f['weather'][0]['main'] as String?).toList();

    final avgTemp = temperatures.reduce((a, b) => a + b) / temperatures.length;
    final dominantCondition = conditions.where((c) => c != null).reduce((a, b) => 
      conditions.where((c) => c == a).length >= conditions.where((c) => c == b).length ? a! : b!);

    if (avgTemp > 25 && dominantCondition == 'Clear') {
      return 'Sunny and warm tomorrow!';
    } else if (avgTemp < 10) {
      return 'Cold weather expected tomorrow.';
    } else if (dominantCondition == 'Rain') {
      return 'Rain likely tomorrow, bring an umbrella.';
    }
    return 'Stable weather expected tomorrow';
  }

  Color _getIconColor(String sky) {
    switch (sky.toLowerCase()) {
      case 'thunderstorm':
        return Colors.indigo;
      case 'rain':
      case 'drizzle':
        return Colors.blueGrey;
      case 'clouds':
      case 'partly cloudy':
        return Colors.grey;
      case 'clear':
        return Colors.orange;
      default:
        return Colors.black;
    }
  }
}
