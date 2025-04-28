import 'dart:convert'; // Provides JSON encoding/decoding functions
import 'dart:io' show Platform; // Platform-specific utilities and Directory access
import 'package:flutter/material.dart'; // Core Flutter framework
import 'package:http/http.dart' as http; // Enables HTTP requests
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Manages notifications
import 'package:intl/intl.dart'; // Date and time formatting
import 'package:lottie/lottie.dart'; // Added for animations
import 'package:permission_handler/permission_handler.dart'; // Handles runtime permissions
import 'package:speech_to_text/speech_to_text.dart'; // Speech-to-text functionality
import 'package:geolocator/geolocator.dart'; // Geolocation services
import 'package:hive_flutter/hive_flutter.dart'; // Flutter integration for Hive
import 'package:path_provider/path_provider.dart'; // Provides access to app directories
import 'package:w_app/secreats.dart'; // API key (OpenWeatherAPIKey)
import 'package:w_app/additional_info_item.dart'; // Custom widget
import 'package:w_app/aqi_ui.dart'; // AQI UI component
import 'package:w_app/weather_map_screen.dart'; // New screen
import 'package:w_app/multi_day_forecast.dart'; // Multi-day forecast widget

// Global theme state using ValueNotifier for dark mode
final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier<bool>(false);

// Entry point of the application
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensures Flutter bindings are initialized
  final appDocumentDir = await getApplicationDocumentsDirectory(); // Gets app document directory
  await Hive.initFlutter(appDocumentDir.path); // Initializes Hive with the app directory
  runApp(const MyApp()); // Runs the app
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier, // Listens to dark mode changes
      builder: (context, isDarkMode, child) {
        return MaterialApp(
          title: 'Weather App',
          theme: isDarkMode
              ? ThemeData.dark().copyWith(
                  primaryColor: Colors.blue, // Sets primary color
                  scaffoldBackgroundColor: Colors.grey[900], // Dark mode background
                  cardColor: Colors.grey[800], // Dark mode card color
                  textTheme: const TextTheme(
                    bodyMedium: TextStyle(color: Colors.white70, fontFamily: 'Roboto'), // Text styling
                    titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Roboto'),
                  ),
                  appBarTheme: const AppBarTheme(backgroundColor: Colors.blueGrey), // App bar styling
                )
              : ThemeData(
                  primarySwatch: Colors.blue, // Light mode primary color
                  scaffoldBackgroundColor: Colors.white, // Light mode background
                  cardColor: Colors.white, // Light mode card color
                  textTheme: const TextTheme(
                    bodyMedium: TextStyle(color: Colors.black87, fontFamily: 'Roboto'), // Text styling
                    titleLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Roboto'),
                  ),
                  appBarTheme: const AppBarTheme(backgroundColor: Colors.blueGrey), // App bar styling
                ),
          home: const WeatherScreen(), // Sets the home screen
        );
      },
    );
  }
}

// Separate widget for the city search input
class CitySearchInput extends StatefulWidget {
  final Function(String) onSearch; // Callback for search action
  final String initialCity; // Initial city name
  final bool isDarkMode; // Dark mode flag
  final double fontSize; // Font size for text
  final bool isHiveInitialized; // Hive initialization status
  final Function() onMicTap; // Callback for microphone tap
  final bool isListening; // Speech recognition status

  const CitySearchInput({
    super.key,
    required this.onSearch,
    required this.initialCity,
    required this.isDarkMode,
    required this.fontSize,
    required this.isHiveInitialized,
    required this.onMicTap,
    required this.isListening,
  });

  @override
  State<CitySearchInput> createState() => _CitySearchInputState();
}

class _CitySearchInputState extends State<CitySearchInput> {
  late TextEditingController _controller; // Controller for the text field

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCity); // Initializes with initial city
  }

  @override
  void didUpdateWidget(covariant CitySearchInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCity != oldWidget.initialCity) {
      _controller.text = widget.initialCity; // Updates text when initial city changes
    }
  }

  @override
  void dispose() {
    _controller.dispose(); // Disposes of the controller
    super.dispose();
  }

  void _handleSearch() {
    final city = _controller.text.trim(); // Gets trimmed city name
    if (city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a city name'), // Shows error if city is empty
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    widget.onSearch(city); // Triggers search with the city name
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6, // Adds shadow to the card
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: _controller,
        style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black87, fontSize: widget.fontSize),
        decoration: InputDecoration(
          hintText: 'Enter city name (e.g., London)', // Placeholder text
          hintStyle: TextStyle(color: widget.isDarkMode ? Colors.white54 : Colors.grey, fontSize: widget.fontSize),
          prefixIcon: Icon(Icons.location_city, color: widget.isDarkMode ? Colors.lightBlueAccent : Colors.blueAccent),
          filled: true,
          fillColor: widget.isDarkMode ? Colors.grey[800] : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.search, color: widget.isDarkMode ? Colors.lightBlueAccent : Colors.blueAccent),
                onPressed: widget.isHiveInitialized ? _handleSearch : null,
              ),
              IconButton(
                icon: Icon(
                  widget.isListening ? Icons.mic_off : Icons.mic,
                  color: widget.isListening
                      ? Colors.red
                      : (widget.isDarkMode ? Colors.lightBlueAccent : Colors.blueAccent),
                ),
                onPressed: widget.onMicTap,
              ),
            ],
          ),
        ),
        onSubmitted: (_) => widget.isHiveInitialized ? _handleSearch() : null,
      ),
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
  String _cityName = 'Hyderabad'; // Default city
  bool _isWeatherVisible = false; // Visibility flag for weather data
  bool _isLoading = false; // Loading state flag
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin(); // Notification plugin
  bool _notificationsEnabled = true; // Notification enable flag
  bool _isWeatherValid = false; // Validity flag for weather data
  final SpeechToText _speechToText = SpeechToText(); // Speech-to-text instance
  bool _isListening = false; // Speech recognition status
  bool _hasSpeechPermission = false; // Microphone permission status
  bool _hasLocationPermission = false; // Location permission status
  Position? _currentPosition; // Current geolocation position
  bool _useGeolocation = true; // Geolocation usage flag
  late Box _weatherCacheBox; // Hive box for weather cache
  bool _isHiveInitialized = false; // Hive initialization status
  double _mainCardScale = 1.0; // Scale for main weather card animation
  double _forecastCardScale = 1.0; // Scale for forecast card animation
  final Map<int, double> _hourlyItemScales = {}; // Scales for hourly items
  final Map<int, bool> _hourlyItemExpanded = {}; // Expanded states for hourly items
  Map<String, dynamic>? _weatherData; // Stores fetched weather data

  @override
  void initState() {
    super.initState();
    isDarkModeNotifier.addListener(_updateTheme); // Listens to dark mode changes
    _initializeApp(); // Initializes the app
  }

  @override
  void dispose() {
    isDarkModeNotifier.removeListener(_updateTheme); // Removes dark mode listener
    super.dispose();
  }

  void _updateTheme() {
    setState(() {}); // Updates UI when theme changes
  }

  Future<void> _initializeApp() async {
    await _initializeHiveBox(); // Initializes Hive box
    setState(() {
      _isHiveInitialized = true; // Sets Hive initialization status
    });
    await _requestMicrophonePermission(); // Requests microphone permission
    await _requestLocationPermission(); // Requests location permission
    await _initializeNotifications(); // Initializes notifications
    if (_useGeolocation) {
      await _getCurrentLocationAndFetchWeather(); // Fetches weather using location
    } else {
      await _fetchWeatherAndUpdate(); // Fetches weather with default city
    }
  }

  Future<void> _initializeHiveBox() async {
    try {
      _weatherCacheBox = await Hive.openBox('weatherCache'); // Opens Hive box
    } catch (e) {
      print('Hive initialization error: $e'); // Logs error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize cache: $e')), // Shows error snackbar
      );
      final appDocumentDir = await getApplicationDocumentsDirectory(); // Gets app directory
      await Hive.initFlutter(appDocumentDir.path); // Reinitializes Hive
      _weatherCacheBox = await Hive.openBox('weatherCache'); // Reopens box
    }
  }

  Future<void> _requestMicrophonePermission() async {
    var status = await Permission.microphone.status; // Checks microphone permission
    if (!status.isGranted) {
      status = await Permission.microphone.request(); // Requests permission
    }
    setState(() {
      _hasSpeechPermission = status.isGranted; // Updates permission status
    });
    if (!_hasSpeechPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required for voice input.')), // Shows permission warning
      );
    }
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission(); // Checks location permission
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission(); // Requests permission
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied. Using default city.')), // Shows denial warning
        );
        setState(() {
          _hasLocationPermission = false; // Updates permission status
        });
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission permanently denied. Please enable in settings.'),
          action: SnackBarAction(label: 'Settings', onPressed: openAppSettings), // Opens settings
        ),
      );
      setState(() {
        _hasLocationPermission = false; // Updates permission status
      });
      return;
    }
    setState(() {
      _hasLocationPermission = true; // Updates permission status
    });
  }

  Future<void> _getCurrentLocationAndFetchWeather() async {
    if (!_hasLocationPermission || !_useGeolocation) {
      await _fetchWeatherAndUpdate(); // Falls back to default fetch
      return;
    }
    try {
      _currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high); // Gets current position
      final city = await _getCityFromCoordinates(_currentPosition!.latitude, _currentPosition!.longitude); // Gets city from coords
      setState(() {
        _cityName = city; // Updates city name
        _cityController.text = city; // Updates text field
      });
      await _fetchWeatherAndUpdate(); // Fetches weather
    } catch (e) {
      print('Location error: $e'); // Logs error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e. Using default city.')), // Shows error
      );
      await _fetchWeatherAndUpdate(); // Falls back to default fetch
    }
  }

  Future<String> _getCityFromCoordinates(double latitude, double longitude) async {
    try {
      final response = await http.get(
        Uri.parse('http://api.openweathermap.org/geo/1.0/reverse?lat=$latitude&lon=$longitude&limit=1&appid=$OpenWeatherAPIKey'),
      ); // Reverse geocoding request
      if (response.statusCode != 200) {
        throw 'Reverse geocoding failed with status ${response.statusCode}'; // Throws error on failure
      }
      final data = jsonDecode(response.body); // Decodes response
      if (data.isEmpty) {
        throw 'No city found for coordinates ($latitude, $longitude)'; // Throws error if no city
      }
      return data[0]['name'] as String; // Returns city name
    } catch (e) {
      throw 'Error getting city from coordinates: $e'; // Throws error
    }
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher'); // Android settings
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    ); // iOS settings
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings); // Combined settings
    await _notificationsPlugin.initialize(initSettings); // Initializes notifications

    if (Platform.isAndroid) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission(); // Requests Android permission
    }
  }

  Future<Map<String, dynamic>> _getCoordinates(String city) async {
    try {
      final geocodingRes = await http.get(
        Uri.parse('http://api.openweathermap.org/geo/1.0/direct?q=$city&limit=1&appid=$OpenWeatherAPIKey'),
      ); // Geocoding request
      if (geocodingRes.statusCode != 200) {
        throw 'Geocoding API request failed with status ${geocodingRes.statusCode}'; // Throws error on failure
      }
      final geocodingData = jsonDecode(geocodingRes.body); // Decodes response
      if (geocodingData.isEmpty) {
        throw 'City not found: $city'; // Throws error if no city
      }
      final lat = geocodingData[0]['lat']; // Extracts latitude
      final lon = geocodingData[0]['lon']; // Extracts longitude
      return {'lat': lat, 'lon': lon}; // Returns coordinates
    } catch (e) {
      throw e.toString(); // Throws error
    }
  }

  Future<Map<String, dynamic>> getCurrentWeather() async {
    if (_cityName.isEmpty || _cityName.trim().isEmpty) {
      throw 'City name cannot be empty'; // Throws error if city is empty
    }
    if (OpenWeatherAPIKey.isEmpty) {
      throw 'Invalid API key'; // Throws error if API key is invalid
    }
    final sanitizedCityName = Uri.encodeComponent(_cityName.trim()); // Sanitizes city name

    try {
      final currentRes = await http.get(
        Uri.parse('https://api.openweathermap.org/data/2.5/forecast?q=$sanitizedCityName&appid=$OpenWeatherAPIKey'),
      ); // Weather forecast request
      if (currentRes.statusCode != 200) {
        throw 'OpenWeather API request failed with status ${currentRes.statusCode}'; // Throws error on failure
      }
      final currentData = jsonDecode(currentRes.body); // Decodes response
      if (currentData['cod'] != '200') {
        throw 'City not found or an unexpected error occurred: ${currentData['message']}'; // Throws error on invalid response
      }

      final coords = await _getCoordinates(_cityName); // Gets coordinates
      final latitude = coords['lat']; // Extracts latitude
      final longitude = coords['lon']; // Extracts longitude

      final airQualityRes = await http.get(
        Uri.parse('http://api.openweathermap.org/data/2.5/air_pollution?lat=$latitude&lon=$longitude&appid=$OpenWeatherAPIKey'),
      ); // Air quality request
      if (airQualityRes.statusCode != 200) {
        throw 'Air Pollution API request failed with status ${airQualityRes.statusCode}'; // Throws error on failure
      }
      final airQualityData = jsonDecode(airQualityRes.body); // Decodes response

      return {
        'current': currentData['list'][0], // Current weather data
        'airQuality': airQualityData['list'][0], // Air quality data
        'forecastList': currentData['list'], // Forecast list
      };
    } catch (e) {
      throw e.toString(); // Throws error
    }
  }

  Future<void> _fetchWeatherAndUpdate() async {
    setState(() {
      _isLoading = true; // Sets loading state
      _isWeatherVisible = false; // Hides weather data
    });

    if (!_isHiveInitialized) {
      print('Waiting for Hive initialization...'); // Logs initialization wait
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 100)); // Waits for initialization
        return !_isHiveInitialized; // Continues until initialized
      });
    }

    try {
      final data = await getCurrentWeather(); // Fetches weather data
      await _weatherCacheBox.put('weatherData', {
        'data': data, // Stores weather data
        'timestamp': DateTime.now().toIso8601String(), // Stores timestamp
      });
      setState(() {
        _weatherData = data; // Updates weather data
        _isWeatherVisible = true; // Shows weather data
        _isWeatherValid = true; // Marks data as valid
        _isLoading = false; // Clears loading state
      });
      _checkWeatherAndNotify(data['current']); // Checks and sends notifications
    } catch (e) {
      print('Fetch error: $e'); // Logs error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch weather: $e')), // Shows error
      );
      try {
        final cachedData = _weatherCacheBox.get('weatherData'); // Gets cached data
        if (cachedData != null && DateTime.now().difference(DateTime.parse(cachedData['timestamp'])).inHours < 24) {
          setState(() {
            _weatherData = cachedData['data']; // Uses cached data
            _isWeatherVisible = true; // Shows weather data
            _isWeatherValid = true; // Marks data as valid
            _isLoading = false; // Clears loading state
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Showing cached data (last updated: ${cachedData['timestamp']})')), // Shows cache info
          );
        } else {
          setState(() {
            _isWeatherValid = false; // Marks data as invalid
            _isLoading = false; // Clears loading state
          });
        }
      } catch (cacheError) {
        print('Cache error: $cacheError'); // Logs cache error
        setState(() {
          _isWeatherValid = false; // Marks data as invalid
          _isLoading = false; // Clears loading state
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to access cached data')), // Shows cache error
        );
      }
    }
  }

  Future<void> _checkWeatherAndNotify(Map<String, dynamic> currentData) async {
    if (!_notificationsEnabled) return; // Exits if notifications are disabled
    try {
      final currentSky = currentData['weather'][0]['main']; // Gets current sky condition
      final currentTemp = (currentData['main']['temp'] - 273.15).round(); // Converts temp to Celsius

      String title = 'Weather Alert'; // Notification title
      String? body; // Notification body

      if (currentSky == 'Rain') {
        body = 'Take an umbrella, it’s rainy out there!'; // Rain alert
      } else if (currentSky == 'Clear' && currentTemp > 25) {
        body = 'Wear light clothes today—it’s sunny!'; // Sunny alert
      } else if (currentTemp < 10) {
        body = 'It’s cold—grab a jacket!'; // Cold alert
      } else {
        return; // Exits if no alert condition met
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
      ); // Shows notification
    } catch (e) {
      print('Error sending notification: $e'); // Logs error
    }
  }

  void _updateCityWeather(String city) {
    setState(() {
      _cityName = city.isEmpty ? 'Hyderabad' : city; // Updates city name
      _isWeatherVisible = false; // Hides weather data
    });
    _fetchWeatherAndUpdate(); // Fetches new weather data
  }

  Future<void> _startListening() async {
    if (!_hasSpeechPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission denied. Please enable it in settings.'),
          action: SnackBarAction(label: 'Settings', onPressed: openAppSettings), // Opens settings
        ),
      );
      return;
    }

    if (!_isListening) {
      bool available = await _speechToText.initialize(
        onStatus: (status) => print('Speech status: $status'), // Logs status
        onError: (error) => print('Speech error: ${error.errorMsg} [Permanent: ${error.permanent}]'), // Logs error
      );
      if (available) {
        setState(() => _isListening = true); // Starts listening
        try {
          await _speechToText.listen(
            onResult: (result) {
              setState(() {
                _cityController.text = result.recognizedWords
                    .replaceAll(RegExp(r'show weather for|weather for', caseSensitive: false), '')
                    .trim(); // Processes speech result
                _isListening = false; // Stops listening
              });
              if (_cityController.text.isNotEmpty) {
                _updateCityWeather(_cityController.text); // Updates weather with recognized city
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No city recognized. Please try again.')), // Shows error
                );
              }
            },
            localeId: 'en_US', // Sets language
            listenFor: const Duration(seconds: 10), // Listening duration
            cancelOnError: true, // Cancels on error
            partialResults: true, // Allows partial results
          );
        } catch (e) {
          print('Listening error: $e'); // Logs error
          setState(() => _isListening = false); // Stops listening
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start listening: $e')), // Shows error
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available on this device.')), // Shows unavailability
        );
      }
    } else {
      setState(() => _isListening = false); // Stops listening
      _speechToText.stop(); // Stops speech recognition
    }
  }

  void _showWeatherDetailsDialog({
    required String cityName,
    required double temperature,
    required String sky,
    required String prediction,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDarkModeNotifier.value ? Colors.grey[800] : Colors.white, // Sets background color
        title: Text(
          '$cityName Weather Details',
          style: Theme.of(context).textTheme.titleLarge!.copyWith(color: isDarkModeNotifier.value ? Colors.white : Colors.black87),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Temperature: ${temperature.round()}°C',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: isDarkModeNotifier.value ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              'Condition: $sky',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: isDarkModeNotifier.value ? Colors.white70 : Colors.black87),
            ),
            if (prediction.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Prediction: $prediction',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: isDarkModeNotifier.value ? Colors.white70 : Colors.black87),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Closes dialog
            child: Text(
              'Close',
              style: TextStyle(color: isDarkModeNotifier.value ? Colors.lightBlueAccent : Colors.blueAccent),
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getWeatherGradient(String sky) {
    switch (sky.toLowerCase()) {
      case 'clouds':
      case 'partlycloudy':
        return isDarkModeNotifier.value
            ? [Colors.grey[900]!, Colors.blueGrey[700]!] // Dark mode gradient
            : [Colors.grey[300]!, Colors.blue[200]!]; // Light mode gradient
      case 'clear':
        return isDarkModeNotifier.value
            ? [Colors.red[900]!, Colors.indigo[700]!] // Dark mode gradient
            : [Colors.red[400]!, Colors.blue[300]!]; // Light mode gradient
      case 'rain':
      case 'drizzle':
        return isDarkModeNotifier.value
            ? [Colors.blue[900]!, Colors.grey[700]!] // Dark mode gradient
            : [Colors.blue[300]!, Colors.grey[200]!]; // Light mode gradient
      default:
        return isDarkModeNotifier.value
            ? [Colors.grey[800]!, Colors.blueGrey[600]!] // Dark mode default
            : [Colors.grey[400]!, Colors.blue[100]!]; // Light mode default
    }
  }

  List<Color> _getForecastItemGradient(String sky) {
    switch (sky.toLowerCase()) {
      case 'clouds':
      case 'partlycloudy':
        return isDarkModeNotifier.value
            ? [Colors.grey[800]!.withOpacity(0.6), Colors.blueGrey[600]!.withOpacity(0.6)] // Dark mode gradient
            : [Colors.grey[300]!.withOpacity(0.6), Colors.blue[200]!.withOpacity(0.6)]; // Light mode gradient
      case 'clear':
        return isDarkModeNotifier.value
            ? [Colors.red[800]!.withOpacity(0.6), Colors.indigo[600]!.withOpacity(0.6)] // Dark mode gradient
            : [Colors.red[400]!.withOpacity(0.6), Colors.blue[300]!.withOpacity(0.6)]; // Light mode gradient
      case 'rain':
      case 'drizzle':
        return isDarkModeNotifier.value
            ? [Colors.blue[800]!.withOpacity(0.6), Colors.grey[600]!.withOpacity(0.6)] // Dark mode gradient
            : [Colors.blue[300]!.withOpacity(0.6), Colors.grey[200]!.withOpacity(0.6)]; // Light mode gradient
      default:
        return isDarkModeNotifier.value
            ? [Colors.grey[700]!.withOpacity(0.6), Colors.blueGrey[500]!.withOpacity(0.6)] // Dark mode default
            : [Colors.grey[350]!.withOpacity(0.6), Colors.blue[150]!.withOpacity(0.6)]; // Light mode default
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width; // Gets screen width
    final isDesktop = screenWidth > 800; // Determines if desktop layout
    const maxWidth = 1200.0; // Maximum width constraint

    final padding = isDesktop ? 32.0 : 16.0; // Padding based on screen size
    final titleFontSize = isDesktop ? 28.0 : 22.0; // Title font size
    final tempFontSize = isDesktop ? 64.0 : 48.0; // Temperature font size
    final conditionFontSize = isDesktop ? 32.0 : 24.0; // Condition font size
    final bodyFontSize = isDesktop ? 18.0 : 16.0; // Body font size
    final animationSize = isDesktop ? 150.0 : 120.0; // Animation size
    final hourlyAnimationSize = isDesktop ? 70.0 : 40.0; // Hourly animation size
    final hourlyListHeight = isDesktop ? 200.0 : 180.0; // Hourly list height
    final hourlyItemWidth = isDesktop ? 200.0 : 140.0; // Hourly item width

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
        elevation: 4, // Adds shadow to app bar
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isHiveInitialized
                ? () {
                    setState(() {
                      _isWeatherVisible = false; // Hides weather data
                    });
                    if (_useGeolocation) {
                      _getCurrentLocationAndFetchWeather(); // Refreshes with location
                    } else {
                      _fetchWeatherAndUpdate(); // Refreshes with current city
                    }
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.map, color: Colors.white),
            onPressed: _isHiveInitialized
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => WeatherMapScreen(cityName: _cityName)), // Navigates to map
                    );
                  }
                : null,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings, color: Colors.white),
            onSelected: (String result) {
              setState(() {
                if (result == 'notifications') _notificationsEnabled = !_notificationsEnabled; // Toggles notifications
                if (result == 'location') _useGeolocation = !_useGeolocation; // Toggles geolocation
                if (result == 'darkMode') isDarkModeNotifier.value = !isDarkModeNotifier.value; // Toggles dark mode
                if (_useGeolocation && _hasLocationPermission && result == 'location') {
                  _getCurrentLocationAndFetchWeather(); // Updates with location
                } else if (result == 'location') {
                  _cityName = 'Hyderabad'; // Resets to default city
                  _cityController.text = ''; // Clears text field
                  _fetchWeatherAndUpdate(); // Fetches weather
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
                checked: isDarkModeNotifier.value,
                child: const Text('Dark Mode'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDarkModeNotifier.value ? [Colors.grey[900]!, Colors.grey[700]!] : [Colors.grey[400]!, Colors.blue[100]!],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent)),
              ),
            )
          : !_isWeatherVisible || _weatherData == null
              ? Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDarkModeNotifier.value ? [Colors.grey[900]!, Colors.grey[700]!] : [Colors.grey[400]!, Colors.blue[100]!],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'No weather data available',
                      style: TextStyle(color: Colors.redAccent, fontSize: 18),
                    ),
                  ),
                )
              : Builder(
                  builder: (context) {
                    final data = _weatherData!; // Gets weather data
                    final currentWeatherData = data['current']; // Gets current weather
                    final currentTemp = (currentWeatherData['main']['temp'] as num? ?? 0.0).toDouble() - 273.15; // Converts temp
                    final currentSky = currentWeatherData['weather'][0]['main'] ?? 'Unknown'; // Gets sky condition
                    final currentPressure = (currentWeatherData['main']['pressure'] as num? ?? 0.0).toDouble(); // Gets pressure
                    final currentWindSpeed = (currentWeatherData['wind']['speed'] as num? ?? 0.0).toDouble(); // Gets wind speed
                    final currentHumidity = currentWeatherData['main']['humidity'] as int? ?? 0; // Gets humidity
                    final airQualityData = data['airQuality']; // Gets air quality
                    final rawAQI = airQualityData['main']['aqi']; // Gets raw AQI
                    final currentAQI = rawAQI != null
                        ? (rawAQI is num ? rawAQI.toInt() : int.tryParse(rawAQI.toString()) ?? 1)
                        : 1; // Calculates AQI
                    final currentPM25 = (airQualityData['components']['pm2_5'] as num? ?? 0.0).toDouble(); // Gets PM2.5
                    final currentPM10 = (airQualityData['components']['pm10'] as num? ?? 0.0).toDouble(); // Gets PM10
                    final forecastList = data['forecastList'] as List<dynamic>; // Gets forecast list
                    final prediction = _getWeatherPrediction(forecastList); // Gets prediction

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

                    final gradientColors = _getWeatherGradient(currentSky); // Gets gradient colors

                    // Precompute forecast group data
                    final forecastGroups = <Map<String, dynamic>>[];
                    final groupCount = (forecastList.length > 16 ? 16 : forecastList.length) ~/ 3;
                    for (int groupIndex = 0; groupIndex < groupCount; groupIndex++) {
                      final startIndex = groupIndex * 3 + 1;
                      if (startIndex >= forecastList.length) break;
                      final endIndex = (startIndex + 2 < forecastList.length) ? startIndex + 2 : forecastList.length - 1;
                      final group = forecastList.sublist(startIndex, endIndex + 1);

                      final times = group.map((f) => DateTime.parse(f['dt_txt'])).toList(); // Gets times
                      final temps = group.map((f) => (f['main']['temp'] - 273.15).round()).toList(); // Gets temperatures
                      final skies = group.map((f) => f['weather'][0]['main'] as String?).toList(); // Gets skies
                      final windSpeeds = group.map((f) => (f['wind']['speed'] as num? ?? 0.0).toDouble()).toList(); // Gets wind speeds
                      final humidities = group.map((f) => f['main']['humidity'] as int? ?? 0).toList(); // Gets humidities

                      final avgTemp = temps.reduce((a, b) => a + b) / temps.length; // Calculates average temp
                      final dominantSky = _getDominantCondition(skies); // Gets dominant sky
                      final avgWindSpeed = windSpeeds.reduce((a, b) => a + b) / windSpeeds.length; // Calculates average wind
                      final avgHumidity = humidities.reduce((a, b) => a + b) / humidities.length; // Calculates average humidity
                      final startTime = DateFormat('h a').format(times.first); // Formats start time
                      final endTime = DateFormat('h a').format(times.last); // Formats end time

                      String animationPath;
                      switch (dominantSky.toLowerCase()) {
                        case 'thunderstorm':
                          animationPath = 'assets/animations/thunderstorm.json';
                          break;
                        case 'rain':
                        case 'drizzle':
                          animationPath = 'assets/animations/rain.json';
                          break;
                        case 'clouds':
                        case 'partly cloudy':
                          animationPath = 'assets/animations/cloudy.json';
                          break;
                        case 'clear':
                          animationPath = 'assets/animations/sunny.json';
                          break;
                        default:
                          animationPath = 'assets/animations/unknown.json';
                      }

                      final itemGradient = _getForecastItemGradient(dominantSky); // Gets item gradient

                      forecastGroups.add({
                        'startTime': startTime,
                        'endTime': endTime,
                        'avgTemp': avgTemp,
                        'dominantSky': dominantSky,
                        'avgWindSpeed': avgWindSpeed,
                        'avgHumidity': avgHumidity,
                        'animationPath': animationPath,
                        'itemGradient': itemGradient,
                      });

                      _hourlyItemScales.putIfAbsent(groupIndex, () => 1.0); // Initializes scale
                      _hourlyItemExpanded.putIfAbsent(groupIndex, () => false); // Initializes expanded state
                    }

                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: maxWidth),
                          child: Padding(
                            padding: EdgeInsets.all(padding),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CitySearchInput(
                                  onSearch: _updateCityWeather,
                                  initialCity: _cityName,
                                  isDarkMode: isDarkModeNotifier.value,
                                  fontSize: bodyFontSize,
                                  isHiveInitialized: _isHiveInitialized,
                                  onMicTap: _startListening,
                                  isListening: _isListening,
                                ),
                                const SizedBox(height: 20),
                                Expanded(
                                  child: AnimatedOpacity(
                                    opacity: _isWeatherVisible ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 500),
                                    child: _isWeatherValid
                                        ? Builder(
                                            builder: (context) {
                                              final mainWeatherCard = Hero(
                                                tag: 'weatherCard',
                                                child: GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      _mainCardScale = 1.05; // Scales up on tap
                                                    });
                                                    Future.delayed(const Duration(milliseconds: 200), () {
                                                      setState(() {
                                                        _mainCardScale = 1.0; // Resets scale
                                                      });
                                                      _showWeatherDetailsDialog(
                                                        cityName: _cityName,
                                                        temperature: currentTemp,
                                                        sky: currentSky,
                                                        prediction: prediction,
                                                      ); // Shows details
                                                    });
                                                  },
                                                  onDoubleTap: () {
                                                    setState(() {
                                                      _mainCardScale = 1.1; // Scales up on double tap
                                                    });
                                                    Future.delayed(const Duration(milliseconds: 500), () {
                                                      setState(() {
                                                        _mainCardScale = 1.0; // Resets scale
                                                      });
                                                    });
                                                  },
                                                  child: AnimatedContainer(
                                                    duration: const Duration(milliseconds: 200),
                                                    transform: Matrix4.identity()..scale(_mainCardScale),
                                                    child: Card(
                                                      elevation: 8,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                      color: isDarkModeNotifier.value ? Colors.grey[800] : Colors.white,
                                                      child: Padding(
                                                        padding: EdgeInsets.all(padding),
                                                        child: Column(
                                                          children: [
                                                            Text(
                                                              _cityName.toUpperCase(),
                                                              style: Theme.of(context)
                                                                  .textTheme
                                                                  .titleLarge!
                                                                  .copyWith(
                                                                      color: isDarkModeNotifier.value
                                                                          ? Colors.lightBlueAccent
                                                                          : Colors.blueAccent,
                                                                      fontSize: titleFontSize),
                                                            ),
                                                            const SizedBox(height: 15),
                                                            Text(
                                                              '${currentTemp.round()}°C',
                                                              style: Theme.of(context)
                                                                  .textTheme
                                                                  .titleLarge!
                                                                  .copyWith(
                                                                      fontSize: tempFontSize,
                                                                      color: isDarkModeNotifier.value
                                                                          ? Colors.white
                                                                          : Colors.black87),
                                                            ),
                                                            const SizedBox(height: 15),
                                                            Lottie.asset(
                                                              currentAnimationPath,
                                                              width: animationSize,
                                                              height: animationSize,
                                                              fit: BoxFit.contain,
                                                            ),
                                                            const SizedBox(height: 15),
                                                            Text(
                                                              currentSky,
                                                              style: Theme.of(context)
                                                                  .textTheme
                                                                  .titleLarge!
                                                                  .copyWith(
                                                                      fontSize: conditionFontSize,
                                                                      color: isDarkModeNotifier.value
                                                                          ? Colors.white
                                                                          : Colors.black87),
                                                            ),
                                                            if (prediction.isNotEmpty)
                                                              Padding(
                                                                padding: const EdgeInsets.only(top: 15),
                                                                child: Text(
                                                                  'Prediction: $prediction',
                                                                  style: Theme.of(context)
                                                                      .textTheme
                                                                      .bodyMedium!
                                                                      .copyWith(
                                                                          color: isDarkModeNotifier.value
                                                                              ? Colors.white70
                                                                              : Colors.grey,
                                                                          fontSize: bodyFontSize),
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );

                                              final forecastCard = GestureDetector(
                                                onLongPressStart: (_) {
                                                  setState(() {
                                                    _forecastCardScale = 1.05; // Scales up on long press
                                                  });
                                                },
                                                onLongPressEnd: (_) {
                                                  setState(() {
                                                    _forecastCardScale = 1.0; // Resets scale
                                                  });
                                                },
                                                child: AnimatedContainer(
                                                  duration: const Duration(milliseconds: 200),
                                                  transform: Matrix4.identity()..scale(_forecastCardScale),
                                                  child: Card(
                                                    elevation: 6,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(12),
                                                      side: BorderSide(
                                                        color: isDarkModeNotifier.value
                                                            ? Colors.white.withOpacity(0.2)
                                                            : Colors.black.withOpacity(0.1),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    color: isDarkModeNotifier.value
                                                        ? Colors.grey[800]!.withOpacity(0.7)
                                                        : Colors.white.withOpacity(0.7),
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        borderRadius: BorderRadius.circular(12),
                                                        gradient: LinearGradient(
                                                          colors: [
                                                            Colors.white
                                                                .withOpacity(isDarkModeNotifier.value ? 0.1 : 0.3),
                                                            Colors.white
                                                                .withOpacity(isDarkModeNotifier.value ? 0.05 : 0.15),
                                                          ],
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        ),
                                                      ),
                                                      child: Padding(
                                                        padding: EdgeInsets.all(padding),
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              "Weather Forecast (Next 48 Hours)",
                                                              style: Theme.of(context)
                                                                  .textTheme
                                                                  .titleLarge!
                                                                  .copyWith(
                                                                      color: isDarkModeNotifier.value
                                                                          ? Colors.white
                                                                          : Colors.black87,
                                                                      fontSize: titleFontSize),
                                                            ),
                                                            const SizedBox(height: 12),
                                                            SizedBox(
                                                              height: hourlyListHeight,
                                                              child: ListView.builder(
                                                                itemCount: forecastGroups.length,
                                                                scrollDirection: Axis.horizontal,
                                                                itemBuilder: (context, groupIndex) {
                                                                  final group = forecastGroups[groupIndex];
                                                                  final startTime = group['startTime'] as String;
                                                                  final endTime = group['endTime'] as String;
                                                                  final avgTemp = group['avgTemp'] as double;
                                                                  final dominantSky = group['dominantSky'] as String;
                                                                  final avgWindSpeed = group['avgWindSpeed'] as double;
                                                                  final avgHumidity = group['avgHumidity'] as double;
                                                                  final animationPath = group['animationPath'] as String;
                                                                  final itemGradient = group['itemGradient'] as List<Color>;

                                                                  return GestureDetector(
                                                                    onTap: () {
                                                                      setState(() {
                                                                        _hourlyItemExpanded[groupIndex] =
                                                                            !_hourlyItemExpanded[groupIndex]!;
                                                                        _hourlyItemScales[groupIndex] =
                                                                            _hourlyItemExpanded[groupIndex]! ? 1.1 : 1.05;
                                                                      });
                                                                      Future.delayed(const Duration(milliseconds: 200),
                                                                          () {
                                                                        if (!_hourlyItemExpanded[groupIndex]!) {
                                                                          setState(() {
                                                                            _hourlyItemScales[groupIndex] = 1.0;
                                                                          });
                                                                        }
                                                                      });
                                                                    },
                                                                    onDoubleTap: () {
                                                                      setState(() {
                                                                        _hourlyItemScales[groupIndex] = 1.2;
                                                                      });
                                                                      Future.delayed(const Duration(milliseconds: 500),
                                                                          () {
                                                                        setState(() {
                                                                          _hourlyItemScales[groupIndex] = 1.0;
                                                                        });
                                                                      });
                                                                    },
                                                                    onLongPressStart: (_) {
                                                                      setState(() {
                                                                        _hourlyItemScales[groupIndex] = 1.05;
                                                                      });
                                                                    },
                                                                    onLongPressEnd: (_) {
                                                                      setState(() {
                                                                        _hourlyItemScales[groupIndex] = 1.0;
                                                                      });
                                                                    },
                                                                    child: AnimatedContainer(
                                                                      duration: const Duration(milliseconds: 200),
                                                                      width: hourlyItemWidth,
                                                                      transform: Matrix4.identity()
                                                                        ..scale(_hourlyItemScales[groupIndex]!),
                                                                      child: Card(
                                                                        elevation: 4,
                                                                        shape: RoundedRectangleBorder(
                                                                            borderRadius: BorderRadius.circular(12)),
                                                                        child: Container(
                                                                          decoration: BoxDecoration(
                                                                            borderRadius: BorderRadius.circular(12),
                                                                            gradient: LinearGradient(
                                                                              colors: itemGradient,
                                                                              begin: Alignment.topLeft,
                                                                              end: Alignment.bottomRight,
                                                                            ),
                                                                          ),
                                                                          child: Padding(
                                                                            padding: const EdgeInsets.all(8.0),
                                                                            child: SingleChildScrollView(
                                                                              physics: const NeverScrollableScrollPhysics(),
                                                                              child: Column(
                                                                                mainAxisSize: MainAxisSize.min,
                                                                                children: [
                                                                                  Row(
                                                                                    mainAxisAlignment:
                                                                                        MainAxisAlignment.spaceBetween,
                                                                                    children: [
                                                                                      Flexible(
                                                                                        child: Text(
                                                                                          '$startTime - $endTime',
                                                                                          style: Theme.of(context)
                                                                                              .textTheme
                                                                                              .titleLarge!
                                                                                              .copyWith(
                                                                                                fontSize: bodyFontSize,
                                                                                                color: isDarkModeNotifier.value
                                                                                                    ? Colors.white
                                                                                                    : Colors.black87,
                                                                                              ),
                                                                                          overflow: TextOverflow.ellipsis,
                                                                                        ),
                                                                                      ),
                                                                                      const SizedBox(width: 8),
                                                                                      Flexible(
                                                                                        child: Text(
                                                                                          '${avgTemp.round()}°C',
                                                                                          style: Theme.of(context)
                                                                                              .textTheme
                                                                                              .titleLarge!
                                                                                              .copyWith(
                                                                                                fontSize: bodyFontSize,
                                                                                                color: isDarkModeNotifier.value
                                                                                                    ? Colors.white
                                                                                                    : Colors.black87,
                                                                                              ),
                                                                                          overflow: TextOverflow.ellipsis,
                                                                                        ),
                                                                                      ),
                                                                                    ],
                                                                                  ),
                                                                                  Lottie.asset(
                                                                                    animationPath,
                                                                                    width: hourlyAnimationSize,
                                                                                    height: hourlyAnimationSize,
                                                                                    fit: BoxFit.contain,
                                                                                  ),
                                                                                  if (_hourlyItemExpanded[groupIndex]!) ...[
                                                                                    const SizedBox(height: 8),
                                                                                    Text(
                                                                                      'Condition: $dominantSky',
                                                                                      style: Theme.of(context)
                                                                                          .textTheme
                                                                                          .bodyMedium!
                                                                                          .copyWith(
                                                                                            fontSize: bodyFontSize - 2,
                                                                                            color: isDarkModeNotifier.value
                                                                                                ? Colors.white70
                                                                                                : Colors.black54,
                                                                                          ),
                                                                                    ),
                                                                                    Text(
                                                                                      'Wind: ${avgWindSpeed.toStringAsFixed(1)} m/s',
                                                                                      style: Theme.of(context)
                                                                                          .textTheme
                                                                                          .bodyMedium!
                                                                                          .copyWith(
                                                                                            fontSize: bodyFontSize - 2,
                                                                                            color: isDarkModeNotifier.value
                                                                                                ? Colors.white70
                                                                                                : Colors.black54,
                                                                                          ),
                                                                                    ),
                                                                                    Text(
                                                                                      'Humidity: ${avgHumidity.round()}%',
                                                                                      style: Theme.of(context)
                                                                                          .textTheme
                                                                                          .bodyMedium!
                                                                                          .copyWith(
                                                                                            fontSize: bodyFontSize - 2,
                                                                                            color: isDarkModeNotifier.value
                                                                                                ? Colors.white70
                                                                                                : Colors.black54,
                                                                                          ),
                                                                                    ),
                                                                                  ],
                                                                                ],
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  );
                                                                },
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );

                                              final multiDayForecastCard = MultiDayForecast(
                                                forecastList: forecastList,
                                                isDarkMode: isDarkModeNotifier.value,
                                                titleFontSize: titleFontSize,
                                                bodyFontSize: bodyFontSize,
                                              );

                                              final aqiCard = Card(
                                                elevation: 6,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                color: isDarkModeNotifier.value ? Colors.grey[800] : Colors.white,
                                                child: Padding(
                                                  padding: EdgeInsets.all(padding),
                                                  child: AQIUI(
                                                    currentAQI: currentAQI,
                                                    currentPM25: currentPM25,
                                                    currentPM10: currentPM10,
                                                  ),
                                                ),
                                              );

                                              final additionalInfoCard = Card(
                                                elevation: 6,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                color: isDarkModeNotifier.value ? Colors.grey[800] : Colors.white,
                                                child: Padding(
                                                  padding: EdgeInsets.all(padding),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        "Additional Information",
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleLarge!
                                                            .copyWith(
                                                                color: isDarkModeNotifier.value
                                                                    ? Colors.white
                                                                    : Colors.black87,
                                                                fontSize: titleFontSize),
                                                      ),
                                                      const SizedBox(height: 16),
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Expanded(
                                                            child: AdditionalInfoItems(
                                                              icon: Icons.water_drop,
                                                              label: 'Humidity',
                                                              value: '$currentHumidity%',
                                                            ),
                                                          ),
                                                          Expanded(
                                                            child: AdditionalInfoItems(
                                                              icon: Icons.air,
                                                              label: 'Wind Speed',
                                                              value: '${currentWindSpeed}m/s',
                                                            ),
                                                          ),
                                                          Expanded(
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
                                              );

                                              if (isDesktop) {
                                                return Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      flex: 2,
                                                      child: SingleChildScrollView(
                                                        child: ConstrainedBox(
                                                          constraints: BoxConstraints(maxWidth: maxWidth * 0.66),
                                                          child: Column(
                                                            children: [
                                                              mainWeatherCard,
                                                              const SizedBox(height: 20),
                                                              forecastCard,
                                                              const SizedBox(height: 20),
                                                              SingleChildScrollView(
                                                                scrollDirection: Axis.horizontal,
                                                                child: ConstrainedBox(
                                                                  constraints: BoxConstraints(maxWidth: maxWidth * 0.66),
                                                                  child: multiDayForecastCard,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 20),
                                                    Expanded(
                                                      flex: 1,
                                                      child: SingleChildScrollView(
                                                        child: ConstrainedBox(
                                                          constraints: BoxConstraints(maxWidth: maxWidth * 0.33),
                                                          child: Column(
                                                            children: [
                                                              aqiCard,
                                                              const SizedBox(height: 20),
                                                              additionalInfoCard,
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              } else {
                                                return ListView(
                                                  padding: const EdgeInsets.only(bottom: 16),
                                                  children: [
                                                    mainWeatherCard,
                                                    const SizedBox(height: 20),
                                                    forecastCard,
                                                    const SizedBox(height: 20),
                                                    SingleChildScrollView(
                                                      scrollDirection: Axis.horizontal,
                                                      child: ConstrainedBox(
                                                        constraints:
                                                            BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
                                                        child: multiDayForecastCard,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 20),
                                                    aqiCard,
                                                    const SizedBox(height: 20),
                                                    additionalInfoCard,
                                                  ],
                                                );
                                              }
                                            },
                                          )
                                        : const Center(
                                            child: Text(
                                              'Error fetching weather',
                                              style: TextStyle(color: Colors.redAccent, fontSize: 18),
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String _getWeatherPrediction(List<dynamic> forecastList) {
    if (forecastList.length < 24) return 'Insufficient data for prediction'; // Checks data sufficiency
    final next24Hours = forecastList.sublist(1, 25); // Gets next 24 hours
    final temperatures = next24Hours.map((f) => (f['main']['temp'] as num? ?? 0.0).toDouble() - 273.15).toList(); // Gets temperatures
    final conditions = next24Hours.map((f) => f['weather'][0]['main'] as String?).toList(); // Gets conditions

    final avgTemp = temperatures.reduce((a, b) => a + b) / temperatures.length; // Calculates average temp
    final dominantCondition = _getDominantCondition(conditions); // Gets dominant condition

    // Fixed condition logic to match actual weather conditions
    if (avgTemp > 25 && dominantCondition == 'Clear') {
      return 'Sunny and warm tomorrow!'; // Sunny prediction
    } else if (avgTemp < 10) {
      return 'Cold weather expected tomorrow.'; // Cold prediction
    } else if (dominantCondition == 'Rain') {
      return 'Rain likely tomorrow, bring an umbrella.'; // Rain prediction
    }
    return 'Stable weather expected tomorrow.'; // Default prediction
  }

  Color _getIconColor(String sky) {
    switch (sky.toLowerCase()) {
      case 'thunderstorm':
        return Colors.indigo; // Sets icon color
      case 'rain':
      case 'drizzle':
        return Colors.blueGrey; // Sets icon color
      case 'clouds':
      case 'partly cloudy':
        return Colors.grey; // Sets icon color
      case 'clear':
        return Colors.orange; // Sets icon color
      default:
        return Colors.black; // Default color
    }
  }

  String _getDominantCondition(List<dynamic> conditions) {
    if (conditions.isEmpty) return 'Unknown'; // Returns unknown if empty
    final counts = <String, int>{}; // Counts conditions
    for (var condition in conditions) {
      if (condition is String) {
        counts[condition] = (counts[condition] ?? 0) + 1; // Increments count
      }
    }
    if (counts.isEmpty) return 'Unknown'; // Returns unknown if no counts
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key; // Returns dominant condition
  }
}
