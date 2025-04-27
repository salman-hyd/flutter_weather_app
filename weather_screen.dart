import 'dart:convert'; // Provides JSON encoding/decoding functions (jsonDecode)
import 'dart:io' show Platform, Directory; // Allows platform-specific checks and directory access
import 'package:flutter/material.dart'; // Core Flutter framework
import 'package:http/http.dart' as http; // Enables HTTP requests
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Manages notifications
import 'package:intl/intl.dart'; // Provides date and time formatting
import 'package:lottie/lottie.dart'; // Added for animations
import 'package:permission_handler/permission_handler.dart'; // Added for permission management
import 'package:speech_to_text/speech_to_text.dart'; // Added for speech recognition
import 'package:geolocator/geolocator.dart'; // Added for geolocation
import 'package:hive/hive.dart'; // Added for offline caching
import 'package:hive_flutter/hive_flutter.dart'; // Added for offline caching
import 'package:path_provider/path_provider.dart'; // Added to get app directory
import 'package:w_app/secreats.dart'; // API key (OpenWeatherAPIKey)
import 'package:w_app/timely_forcast_item.dart'; // Custom widget for hourly forecast
import 'package:w_app/additional_info_item.dart'; // Custom widget for additional info
import 'package:w_app/aqi_ui.dart'; // AQI UI component
import 'package:w_app/weather_map_screen.dart'; // New screen for weather map

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter bindings are initialized
  // Initialize Hive with a valid path
  final appDocumentDir = await getApplicationDocumentsDirectory(); // Get app documents directory
  await Hive.initFlutter(appDocumentDir.path); // Explicitly set the storage path for Hive
  runApp(const MyApp()); // Start the app
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App', // Set app title
      theme: _WeatherScreenState()._isDarkMode // Determine theme based on dark mode setting
          ? ThemeData.dark().copyWith(
              primaryColor: Colors.blue, // Primary color for dark theme
              scaffoldBackgroundColor: Colors.grey[900], // Background color
              cardColor: Colors.grey[800], // Card background color
              textTheme: const TextTheme(
                bodyMedium: TextStyle(color: Colors.white70, fontFamily: 'Roboto'), // Text style for body
                titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Roboto'), // Title style
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.blueGrey, // App bar color
              ),
            )
          : ThemeData(
              primarySwatch: Colors.blue, // Primary color for light theme
              scaffoldBackgroundColor: Colors.white, // Background color
              cardColor: Colors.white, // Card background color
              textTheme: const TextTheme(
                bodyMedium: TextStyle(color: Colors.black87, fontFamily: 'Roboto'), // Text style for body
                titleLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Roboto'), // Title style
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.blueGrey, // App bar color
              ),
            ),
      home: const WeatherScreen(), // Set the home screen
    );
  }
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final TextEditingController _cityController = TextEditingController(); // Controller for city input
  String _cityName = 'Hyderabad'; // Default city name
  bool _isWeatherVisible = false; // Control visibility of weather data
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin(); // Notification plugin
  bool _notificationsEnabled = true; // Toggle for notifications
  bool _isWeatherValid = false; // Track weather data validity
  final SpeechToText _speechToText = SpeechToText(); // Speech recognition instance
  bool _isListening = false; // Track microphone state
  bool _hasSpeechPermission = false; // Track microphone permission status
  bool _hasLocationPermission = false; // Track location permission status
  Position? _currentPosition; // Store current position (lat, lon)
  bool _useGeolocation = true; // Toggle for geolocation usage
  bool _isDarkMode = false; // Toggle for dark mode
  late Box _weatherCacheBox; // Store the Hive box for caching
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
      _weatherCacheBox = await Hive.openBox('weatherCache'); // Open the weather cache box
    } catch (e) {
      print('Hive initialization error: $e'); // Log the error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize cache: $e')), // Show error to user
      );
      // Fallback: Retry with explicit path if needed
      final appDocumentDir = await getApplicationDocumentsDirectory(); // Get app documents directory
      await Hive.initFlutter(appDocumentDir.path); // Reinitialize with path
      _weatherCacheBox = await Hive.openBox('weatherCache'); // Retry opening the box
    }
  }

  // Request microphone permission
  Future<void> _requestMicrophonePermission() async {
    var status = await Permission.microphone.status; // Check current permission status
    if (!status.isGranted) {
      status = await Permission.microphone.request(); // Request permission if not granted
    }
    setState(() {
      _hasSpeechPermission = status.isGranted; // Update permission status
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
    LocationPermission permission = await Geolocator.checkPermission(); // Check current location permission
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission(); // Request permission if denied
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission denied. Using default city.'),
          ),
        );
        setState(() {
          _hasLocationPermission = false; // Update permission status
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
            onPressed: openAppSettings, // Open settings for permission
          ),
        ),
      );
      setState(() {
        _hasLocationPermission = false; // Update permission status
      });
      return;
    }
    setState(() {
      _hasLocationPermission = true; // Update permission status
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
        desiredAccuracy: LocationAccuracy.high, // High accuracy for location
      );
      final city = await _getCityFromCoordinates(_currentPosition!.latitude, _currentPosition!.longitude);
      setState(() {
        _cityName = city; // Update city name
        _cityController.text = city; // Update text field
      });
      await _fetchWeatherAndUpdate();
    } catch (e) {
      print('Location error: $e'); // Log location error
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
        throw 'Reverse geocoding failed with status ${response.statusCode}'; // Throw error if request fails
      }
      final data = jsonDecode(response.body);
      if (data.isEmpty) {
        throw 'No city found for coordinates ($latitude, $longitude)'; // Throw error if no city found
      }
      return data[0]['name'] as String; // Return the city name
    } catch (e) {
      throw 'Error getting city from coordinates: $e'; // Throw error with details
    }
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Android notification settings
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    ); // iOS notification settings
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    ); // Combined settings
    await _notificationsPlugin.initialize(initSettings); // Initialize notifications

    if (Platform.isAndroid) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission(); // Request permission on Android
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
        throw 'Geocoding API request failed with status ${geocodingRes.statusCode}'; // Throw error if request fails
      }
      final geocodingData = jsonDecode(geocodingRes.body);
      if (geocodingData.isEmpty) {
        throw 'City not found: $city'; // Throw error if no city found
      }
      final lat = geocodingData[0]['lat']; // Get latitude
      final lon = geocodingData[0]['lon']; // Get longitude
      return {'lat': lat, 'lon': lon}; // Return coordinates
    } catch (e) {
      throw e.toString(); // Throw error as string
    }
  }

  Future<Map<String, dynamic>> getCurrentWeather() async {
    // Validate city name
    if (_cityName.isEmpty || _cityName.trim().isEmpty) {
      throw 'City name cannot be empty'; // Throw error if city name is invalid
    }

    // Validate API key
    if (OpenWeatherAPIKey == null || OpenWeatherAPIKey.isEmpty) {
      throw 'Invalid API key'; // Throw error if API key is invalid
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
        throw 'OpenWeather API request failed with status ${currentRes.statusCode}'; // Throw error if request fails
      }
      final currentData = jsonDecode(currentRes.body);
      if (currentData['cod'] != '200') {
        throw 'City not found or an unexpected error occurred: ${currentData['message']}'; // Throw error if city not found
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
        throw 'Air Pollution API request failed with status ${airQualityRes.statusCode}'; // Throw error if request fails
      }
      final airQualityData = jsonDecode(airQualityRes.body);

      return {
        'current': currentData['list'][0], // Current weather data
        'airQuality': airQualityData['list'][0], // Current air quality data
        'forecastList': currentData['list'], // Full forecast list
      };
    } catch (e) {
      throw e.toString(); // Throw error as string
    }
  }

  Future<void> _fetchWeatherAndUpdate() async {
    // Wait for Hive initialization if not ready
    if (!_isHiveInitialized) {
      print('Waiting for Hive initialization...'); // Log initialization wait
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 100)); // Wait briefly
        return !_isHiveInitialized; // Continue until initialized
      });
    }

    try {
      final data = await getCurrentWeather(); // Fetch weather data
      await _weatherCacheBox.put('weatherData', {
        'data': data, // Store weather data
        'timestamp': DateTime.now().toIso8601String(), // Store timestamp
      });
      setState(() {
        _isWeatherVisible = true; // Show weather
        _isWeatherValid = true; // Mark as valid
      });
      _checkWeatherAndNotify(data['current']); // Check and send notifications
    } catch (e) {
      print('Fetch error: $e'); // Log fetch error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch weather: $e')), // Show error to user
      );
      try {
        final cachedData = _weatherCacheBox.get('weatherData'); // Get cached data
        if (cachedData != null && DateTime.now().difference(DateTime.parse(cachedData['timestamp'])).inHours < 24) {
          setState(() {
            _isWeatherVisible = true; // Show cached weather
            _isWeatherValid = true; // Mark as valid
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Showing cached data (last updated: ${cachedData['timestamp']})')),
          );
        } else {
          setState(() {
            _isWeatherValid = false; // Mark as invalid if cache is old
          });
        }
      } catch (cacheError) {
        print('Cache error: $cacheError'); // Log cache error
        setState(() {
          _isWeatherValid = false; // Mark as invalid
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to access cached data')),
        );
      }
    }
  }

  Future<void> _checkWeatherAndNotify(Map<String, dynamic> currentData) async {
    if (!_notificationsEnabled) return; // Exit if notifications are disabled
    try {
      final currentSky = currentData['weather'][0]['main']; // Get current sky condition
      final currentTemp = (currentData['main']['temp'] - 273.15).round(); // Convert temperature to Celsius

      String title = 'Weather Alert'; // Notification title
      String? body; // Notification body

      if (currentSky == 'Rain') {
        body = 'Take an umbrella, it’s rainy out there!'; // Rain alert
      } else if (currentSky == 'Clear' && currentTemp > 25) {
        body = 'Light clothes today—it’s sunny!'; // Sunny and warm alert
      } else if (currentTemp < 10) {
        body = 'Bundle up, it’s cold—grab a jacket!'; // Cold alert
      } else {
        return; // No notification if conditions not met
      }

      await _notificationsPlugin.show(
        0, // Notification ID
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
      print('Error sending notification: $e'); // Log notification error
    }
  }

  void _updateCityWeather() {
    setState(() {
      _cityName = _cityController.text.isEmpty ? 'Hyderabad' : _cityController.text; // Update city name
      _isWeatherVisible = false; // Hide weather until updated
    });
    _fetchWeatherAndUpdate(); // Fetch and update weather
  }

  Future<void> _startListening() async {
    if (!_hasSpeechPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission denied. Please enable it in settings.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: openAppSettings, // Open settings for permission
          ),
        ),
      );
      return;
    }

    if (!_isListening) {
      bool available = await _speechToText.initialize(
        onStatus: (status) => print('Speech status: $status'), // Log speech status
        onError: (error) => print('Speech error: ${error.errorMsg} [Permanent: ${error.permanent}]'), // Log speech error
      );
      if (available) {
        setState(() => _isListening = true); // Start listening
        try {
          await _speechToText.listen(
            onResult: (result) {
              setState(() {
                _cityController.text = result.recognizedWords
                    .replaceAll(RegExp(r'show weather for|weather for', caseSensitive: false), '')
                    .trim(); // Process speech input
                _isListening = false; // Stop listening
              });
              if (_cityController.text.isNotEmpty) {
                _updateCityWeather(); // Update weather with recognized city
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No city recognized. Please try again.')),
                );
              }
            },
            localeId: 'en_US', // Set language
            listenFor: const Duration(seconds: 10), // Listen for 10 seconds
            cancelOnError: true, // Cancel on error
            partialResults: true, // Allow partial results
          );
        } catch (e) {
          print('Listening error: $e'); // Log listening error
          setState(() => _isListening = false); // Stop listening
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
      setState(() => _isListening = false); // Stop listening
      _speechToText.stop(); // Stop speech recognition
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Weather App',
          style: TextStyle(
            fontWeight: FontWeight.bold, // Bold title
            color: Colors.white, // White text
            letterSpacing: 1.2, // Letter spacing
            fontFamily: 'Roboto', // Font family
          ),
        ),
        centerTitle: true, // Center the title
        elevation: 4, // App bar elevation
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white), // Refresh button
            onPressed: _isHiveInitialized
                ? () {
                    setState(() {
                      _isWeatherVisible = false; // Hide weather during refresh
                    });
                    if (_useGeolocation) {
                      _getCurrentLocationAndFetchWeather(); // Refresh with location
                    } else {
                      _fetchWeatherAndUpdate(); // Refresh without location
                    }
                  }
                : null, // Disable until Hive is initialized
          ),
          IconButton(
            icon: const Icon(Icons.map, color: Colors.white), // Map button
            onPressed: _isHiveInitialized
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WeatherMapScreen(cityName: _cityName), // Navigate to map screen
                      ),
                    );
                  }
                : null, // Disable until Hive is initialized
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings, color: Colors.white), // Settings menu
            onSelected: (String result) {
              setState(() {
                if (result == 'notifications') _notificationsEnabled = !_notificationsEnabled; // Toggle notifications
                if (result == 'location') _useGeolocation = !_useGeolocation; // Toggle geolocation
                if (result == 'darkMode') _isDarkMode = !_isDarkMode; // Toggle dark mode
                if (_useGeolocation && _hasLocationPermission && result == 'location') {
                  _getCurrentLocationAndFetchWeather(); // Update with location
                } else if (result == 'location') {
                  _cityName = 'Hyderabad'; // Reset to default city
                  _cityController.text = ''; // Clear text field
                  _fetchWeatherAndUpdate(); // Update weather
                }
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              CheckedPopupMenuItem<String>(
                value: 'notifications',
                checked: _notificationsEnabled,
                child: const Text('Weather Alerts'), // Notifications option
              ),
              CheckedPopupMenuItem<String>(
                value: 'location',
                checked: _useGeolocation,
                child: const Text('Use Location'), // Location option
              ),
              CheckedPopupMenuItem<String>(
                value: 'darkMode',
                checked: _isDarkMode,
                child: const Text('Dark Mode'), // Dark mode option
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: _isDarkMode
              ? LinearGradient(
                  colors: [Colors.grey[900]!, Colors.grey[700]!], // Dark mode gradient
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : LinearGradient(
                  colors: [Colors.blue[100]!, Colors.white], // Light mode gradient
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0), // Padding around content
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // Align children to start
            children: [
              Card(
                elevation: 6, // Card elevation
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Card shape
                child: TextField(
                  controller: _cityController, // Text field controller
                  style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87), // Text color based on theme
                  decoration: InputDecoration(
                    hintText: 'Enter city name (e.g., London)', // Placeholder text
                    hintStyle: TextStyle(color: _isDarkMode ? Colors.white54 : Colors.grey), // Hint text color
                    prefixIcon: Icon(Icons.location_city, color: _isDarkMode ? Colors.lightBlueAccent : Colors.blueAccent), // Prefix icon
                    filled: true, // Fill background
                    fillColor: _isDarkMode ? Colors.grey[800] : Colors.white, // Fill color based on theme
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), // Border radius
                      borderSide: BorderSide.none, // No border
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min, // Minimize row size
                      children: [
                        IconButton(
                          icon: Icon(Icons.search, color: _isDarkMode ? Colors.lightBlueAccent : Colors.blueAccent), // Search button
                          onPressed: _isHiveInitialized ? _updateCityWeather : null, // Enable only if Hive initialized
                        ),
                        IconButton(
                          icon: Icon(
                            _isListening ? Icons.mic_off : Icons.mic, // Microphone or mic off icon
                            color: _isListening ? Colors.red : (_isDarkMode ? Colors.lightBlueAccent : Colors.blueAccent), // Icon color
                          ),
                          onPressed: _startListening, // Start/stop listening
                        ),
                      ],
                    ),
                  ),
                  onSubmitted: (_) => _isHiveInitialized ? _updateCityWeather() : null, // Update on submit if Hive initialized
                ),
              ),
              const SizedBox(height: 20), // Spacer
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500), // Transition duration
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(opacity: animation, child: child); // Fade transition
                  },
                  child: _isWeatherVisible
                      ? FutureBuilder<Map<String, dynamic>>(
                          future: getCurrentWeather(), // Fetch weather data
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent), // Loading indicator
                                ),
                              );
                            }
                            if (snapshot.hasError || !_isWeatherValid) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      snapshot.error?.toString() ?? 'Invalid weather data', // Error message
                                      style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87),
                                    ),
                                    backgroundColor: _isDarkMode ? Colors.red[700] : Colors.redAccent, // Error color
                                  ),
                                );
                              });
                              return const Center(
                                child: Text(
                                  'Error fetching weather', // Error display
                                  style: TextStyle(color: Colors.redAccent, fontSize: 18),
                                ),
                              );
                            }

                            final data = snapshot.data!;
                            final currentWeatherData = data['current'];
                            final currentTemp = (currentWeatherData['main']['temp'] as num? ?? 0.0).toDouble() - 273.15; // Convert temperature
                            final currentSky = currentWeatherData['weather'][0]['main'] ?? 'Unknown'; // Current sky condition
                            final currentPressure = (currentWeatherData['main']['pressure'] as num? ?? 0.0).toDouble(); // Pressure
                            final currentWindSpeed = (currentWeatherData['wind']['speed'] as num? ?? 0.0).toDouble(); // Wind speed
                            final currentHumidity = currentWeatherData['main']['humidity'] as int? ?? 0; // Humidity
                            final airQualityData = data['airQuality'];
                            final rawAQI = airQualityData['main']['aqi'];
                            final currentAQI = rawAQI != null
                                ? (rawAQI is num ? rawAQI.toInt() : int.tryParse(rawAQI.toString()) ?? 1)
                                : 1; // Air quality index
                            final currentPM25 = (airQualityData['components']['pm2_5'] as num? ?? 0.0).toDouble(); // PM2.5
                            final currentPM10 = (airQualityData['components']['pm10'] as num? ?? 0.0).toDouble(); // PM10
                            final forecastList = data['forecastList'] as List<dynamic>; // Forecast list
                            final prediction = _getWeatherPrediction(forecastList); // Weather prediction

                            String currentAnimationPath;
                            switch (currentSky.toLowerCase()) {
                              case 'thunderstorm':
                                currentAnimationPath = 'assets/animations/thunderstorm.json'; // Thunderstorm animation
                                break;
                              case 'rain':
                                currentAnimationPath = 'assets/animations/rain.json'; // Rain animation
                                break;
                              case 'clouds':
                              case 'partlycloudy':
                                currentAnimationPath = 'assets/animations/cloudy.json'; // Cloudy animation
                                break;
                              case 'clear':
                                currentAnimationPath = 'assets/animations/sunny.json'; // Sunny animation
                                break;
                              default:
                                currentAnimationPath = 'assets/animations/unknown.json'; // Default animation
                            }

                            return ListView(
                              padding: const EdgeInsets.only(bottom: 16), // Bottom padding
                              children: [
                                Card(
                                  elevation: 8, // Card elevation
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Card shape
                                  color: _isDarkMode ? Colors.grey[800] : Colors.white, // Card color based on theme
                                  child: Padding(
                                    padding: const EdgeInsets.all(20), // Padding inside card
                                    child: Column(
                                      children: [
                                        Text(
                                          _cityName.toUpperCase(), // Display city name
                                          style: Theme.of(context).textTheme.titleLarge!.copyWith(
                                                color: _isDarkMode ? Colors.lightBlueAccent : Colors.blueAccent,
                                              ),
                                        ),
                                        const SizedBox(height: 15), // Spacer
                                        Text(
                                          '${currentTemp.round()}°C', // Display temperature
                                          style: Theme.of(context).textTheme.titleLarge!.copyWith(
                                                fontSize: 48, // Large font size
                                                color: _isDarkMode ? Colors.white : Colors.black87,
                                              ),
                                        ),
                                        const SizedBox(height: 15), // Spacer
                                        Lottie.asset(
                                          currentAnimationPath, // Display weather animation
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.contain,
                                        ),
                                        const SizedBox(height: 15), // Spacer
                                        Text(
                                          currentSky, // Display sky condition
                                          style: Theme.of(context).textTheme.titleLarge!.copyWith(
                                                fontSize: 24, // Medium font size
                                                color: _isDarkMode ? Colors.white : Colors.black87,
                                              ),
                                        ),
                                        if (prediction.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 15), // Top padding
                                            child: Text(
                                              'Prediction: $prediction', // Display prediction
                                              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                    color: _isDarkMode ? Colors.white70 : Colors.grey,
                                                  ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20), // Spacer
                                Card(
                                  elevation: 6, // Card elevation
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Card shape
                                  color: _isDarkMode ? Colors.grey[800] : Colors.white, // Card color based on theme
                                  child: Padding(
                                    padding: const EdgeInsets.all(16), // Padding inside card
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start, // Align to start
                                      children: [
                                        Text(
                                          "Weather Forecast", // Forecast section title
                                          style: Theme.of(context).textTheme.titleLarge!.copyWith(
                                                color: _isDarkMode ? Colors.white : Colors.black87,
                                              ),
                                        ),
                                        const SizedBox(height: 12), // Spacer
                                        SizedBox(
                                          height: 120, // Fixed height for horizontal list
                                          child: ListView.builder(
                                            itemCount: forecastList.length > 30 ? 30 : forecastList.length - 1, // Limit to 30 items
                                            scrollDirection: Axis.horizontal, // Horizontal scroll
                                            itemBuilder: (context, index) {
                                              final hourlyForecast = forecastList[index + 1]; // Get next forecast
                                              final hourlySky = hourlyForecast['weather'][0]['main'] ?? 'Unknown'; // Hourly sky condition
                                              final time = DateTime.parse(hourlyForecast['dt_txt']); // Parse time
                                              String hourlyAnimationPath;
                                              switch (hourlySky.toLowerCase()) {
                                                case 'thunderstorm':
                                                  hourlyAnimationPath = 'assets/animations/thunderstorm.json'; // Thunderstorm animation
                                                  break;
                                                case 'rain':
                                                case 'drizzle':
                                                  hourlyAnimationPath = 'assets/animations/rain.json'; // Rain animation
                                                  break;
                                                case 'clouds':
                                                case 'partly cloudy':
                                                  hourlyAnimationPath = 'assets/animations/cloudy.json'; // Cloudy animation
                                                  break;
                                                case 'clear':
                                                  hourlyAnimationPath = 'assets/animations/sunny.json'; // Sunny animation
                                                  break;
                                                default:
                                                  hourlyAnimationPath = 'assets/animations/unknown.json'; // Default animation
                                              }
                                              return HourlyForcastItem(
                                                time: DateFormat.j().format(time), // Format time
                                                temperature: '${(hourlyForecast['main']['temp'] - 273.15).round()}°C', // Format temperature
                                                icon: Icons.wb_sunny, // Icon placeholder
                                                child: Lottie.asset(
                                                  hourlyAnimationPath, // Display hourly animation
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
                                const SizedBox(height: 20), // Spacer
                                Card(
                                  elevation: 6, // Card elevation
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Card shape
                                  color: _isDarkMode ? Colors.grey[800] : Colors.white, // Card color based on theme
                                  child: Padding(
                                    padding: const EdgeInsets.all(16), // Padding inside card
                                    child: AQIUI(
                                      currentAQI: currentAQI, // Pass AQI
                                      currentPM25: currentPM25, // Pass PM2.5
                                      currentPM10: currentPM10, // Pass PM10
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20), // Spacer
                                Card(
                                  elevation: 6, // Card elevation
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Card shape
                                  color: _isDarkMode ? Colors.grey[800] : Colors.white, // Card color based on theme
                                  child: Padding(
                                    padding: const EdgeInsets.all(16), // Padding inside card
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start, // Align to start
                                      children: [
                                        Text(
                                          "Additional Information", // Additional info section title
                                          style: Theme.of(context).textTheme.titleLarge!.copyWith(
                                                color: _isDarkMode ? Colors.white : Colors.black87,
                                              ),
                                        ),
                                        const SizedBox(height: 16), // Spacer
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space between items
                                          children: [
                                            SizedBox(
                                              width: MediaQuery.of(context).size.width * 0.3 - 16, // Adjusted width
                                              child: AdditionalInfoItems(
                                                icon: Icons.water_drop, // Humidity icon
                                                label: 'Humidity', // Label
                                                value: '$currentHumidity%', // Value
                                              ),
                                            ),
                                            SizedBox(
                                              width: MediaQuery.of(context).size.width * 0.3 - 16, // Adjusted width
                                              child: AdditionalInfoItems(
                                                icon: Icons.air, // Wind speed icon
                                                label: 'Wind Speed', // Label
                                                value: '${currentWindSpeed}m/s', // Value
                                              ),
                                            ),
                                            SizedBox(
                                              width: MediaQuery.of(context).size.width * 0.3 - 16, // Adjusted width
                                              child: AdditionalInfoItems(
                                                icon: Icons.beach_access, // Pressure icon
                                                label: 'Pressure', // Label
                                                value: '${currentPressure}hPa', // Value
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
                      : const SizedBox.shrink(), // Hide if no weather data
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getWeatherPrediction(List<dynamic> forecastList) {
    if (forecastList.length < 24) return 'Insufficient data for prediction'; // Check if enough data
    final next24Hours = forecastList.sublist(1, 25); // Next 24 hours of forecast
    final temperatures = next24Hours.map((f) => (f['main']['temp'] as num? ?? 0.0).toDouble() - 273.15).toList(); // Convert temperatures
    final conditions = next24Hours.map((f) => f['weather'][0]['main'] as String?).toList(); // Get conditions

    final avgTemp = temperatures.reduce((a, b) => a + b) / temperatures.length; // Calculate average temperature
    final dominantCondition = conditions.where((c) => c != null).reduce((a, b) => 
      conditions.where((c) => c == a).length >= conditions.where((c) => c == b).length ? a! : b!); // Find dominant condition

    if (avgTemp > 25 && dominantCondition == 'Clear') {
      return 'Sunny and warm tomorrow!'; // Prediction for sunny weather
    } else if (avgTemp < 10) {
      return 'Cold weather expected tomorrow.'; // Prediction for cold weather
    } else if (dominantCondition == 'Rain') {
      return 'Rain likely tomorrow, bring an umbrella.'; // Prediction for rain
    }
    return 'Stable weather expected tomorrow'; // Default prediction
  }

  Color _getIconColor(String sky) {
    switch (sky.toLowerCase()) {
      case 'thunderstorm':
        return Colors.indigo; // Color for thunderstorm
      case 'rain':
      case 'drizzle':
        return Colors.blueGrey; // Color for rain/drizzle
      case 'clouds':
      case 'partly cloudy':
        return Colors.grey; // Color for cloudy/partly cloudy
      case 'clear':
        return Colors.orange; // Color for clear
      default:
        return Colors.black; // Default color
    }
  }
}
