// Import the necessary Flutter packages
import 'package:flutter/material.dart';
import 'package:w_app/weather_screen.dart';
 // Import the WeatherScreen widget from the app

// The main function is the entry point of the Flutter application
void main() {
  runApp(const MyApp()); // Launch the application by running MyApp
}

// The root widget of the application
class MyApp extends StatelessWidget {
  const MyApp({super.key}); // Constructor with an optional key for widget identification

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Disable the debug banner on the app's top-right corner

      // Set the app's theme to a dark theme with Material 3 design language
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E2F), // Set the background color of the app
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E2F), // Set the app bar's background color
          foregroundColor: Colors.white, // Set the app bar's text color to white
        ),
        colorScheme: const ColorScheme.dark().copyWith(
          primary: const Color(0xFF1E1E2F), // Set the primary color of the app
        ),
      ),
      
      home: const WeatherScreen(), // Set WeatherScreen as the initial screen of the app
    );
  }
}
