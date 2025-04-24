import 'dart:convert'; // Provides JSON encoding/decoding functions (jsonDecode)
import 'dart:io' show Platform; // Allows platform-specific checks
import 'package:flutter/material.dart'; // Core Flutter framework
import 'package:http/http.dart' as http; // Enables HTTP requests
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Manages notifications
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart'; // Added for animations
import 'package:permission_handler/permission_handler.dart'; // Added for permission management
import 'package:speech_to_text/speech_to_text.dart'; // Added for speech recognition
import 'package:w_app/secreats.dart'; // API key (OpenWeatherAPIKey)
import 'package:w_app/timely_forcast_item.dart'; // Custom widget
import 'package:w_app/additional_info_item.dart'; // Custom widget
import 'package:w_app/aqi_ui.dart'; // AQI UI component
import 'package:w_app/weather_map_screen.dart'; // New screen

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black),
          titleLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        scaffoldBackgroundColor: Colors.transparent,
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

  @override
  void initState() {
    super.initState();
    _requestMicrophonePermission(); // Request permission on app start
    _initializeNotifications();
    _fetchWeatherAndUpdate();
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
    try {
      final currentRes = await http.get(
        Uri.parse(
          'https://api.openweathermap.org/data/2.5/forecast?q=$_cityName&appid=$OpenWeatherAPIKey',
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
    try {
      final data = await getCurrentWeather();
      setState(() {
        _isWeatherVisible = true;
      });
      _checkWeatherAndNotify(data['current']);
    } catch (e) {
      print('Fetch error: $e');
      setState(() {
        _isWeatherValid = false;
      });
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

  // Enhanced method to handle voice input with permission checks and error handling
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
            localeId: 'en_US', // Set to English (US)
            listenFor: const Duration(seconds: 10), // Increased to 10 seconds
            cancelOnError: true,
            partialResults: true, // Enable partial results for better feedback
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
          'WEATHER APP',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _isWeatherVisible = false;
              });
              _fetchWeatherAndUpdate();
            },
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WeatherMapScreen(cityName: _cityName),
                ),
              );
            },
            icon: const Icon(Icons.map, color: Colors.white),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueGrey, Colors.blueAccent, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Weather Alerts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Switch(
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                    },
                    activeColor: const Color.fromARGB(255, 252, 59, 255),
                    inactiveThumbColor: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _cityController,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: 'Enter city name (e.g., London)',
                  hintStyle: const TextStyle(color: Colors.black54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.search, color: Colors.blueAccent),
                        onPressed: _updateCityWeather,
                      ),
                      IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic_off : Icons.mic,
                          color: _isListening ? Colors.red : Colors.blueAccent,
                        ),
                        onPressed: _startListening,
                      ),
                    ],
                  ),
                ),
                onSubmitted: (_) => _updateCityWeather(),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: getCurrentWeather(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              snapshot.error.toString(),
                              style: const TextStyle(color: Colors.white),
                            ),
                            backgroundColor: Colors.redAccent,
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
                    print('Raw AQI value: $rawAQI, Type: ${rawAQI.runtimeType}');
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

                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          AnimatedOpacity(
                            opacity: _isWeatherVisible ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 500),
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.9,
                              child: Card(
                                elevation: 10,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                // ignore: deprecated_member_use
                                color: Colors.white.withOpacity(0.9),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    children: [
                                      Text(
                                        _cityName.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        '${currentTemp.round()}°C',
                                        style: const TextStyle(
                                          fontSize: 40,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Lottie.asset(
                                        currentAnimationPath,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.contain,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        currentSky,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      if (prediction.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 10),
                                          child: Text(
                                            'Prediction: $prediction',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Weather Forecast",
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
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
                                  icon: Icons.wb_sunny, // Replace with an appropriate icon
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
                          const SizedBox(height: 20),
                          AQIUI(
                            currentAQI: currentAQI,
                            currentPM25: currentPM25,
                            currentPM10: currentPM10,
                          ),
                          const SizedBox(height: 20),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Additional Information",
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              AdditionalInfoItems(
                                icon: Icons.water_drop,
                                label: 'Humidity',
                                value: '$currentHumidity%',
                              ),
                              AdditionalInfoItems(
                                icon: Icons.air,
                                label: 'Wind Speed',
                                value: '${currentWindSpeed}m/s',
                              ),
                              AdditionalInfoItems(
                                icon: Icons.beach_access,
                                label: 'Pressure',
                                value: '${currentPressure}hPa',
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
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
    return 'Stable weather expected tomorrow.';
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