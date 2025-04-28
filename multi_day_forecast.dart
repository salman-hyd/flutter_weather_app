// Importing necessary Flutter and third-party packages for building the widget and handling date formatting and animations.
import 'package:flutter/material.dart'; // Core Flutter framework for building UI
import 'package:intl/intl.dart'; // For formatting dates and times
import 'package:lottie/lottie.dart'; // For displaying Lottie animations

// Defines a stateless widget for displaying a 5-day weather forecast.
class MultiDayForecast extends StatelessWidget {
  final List<dynamic> forecastList; // List of forecast data fetched from the API
  final bool isDarkMode; // Dark mode toggle to adjust UI theme
  final double titleFontSize; // Font size for the title text
  final double bodyFontSize; // Font size for the body text

  // Constructor with required parameters
  const MultiDayForecast({
    super.key,
    required this.forecastList, // Forecast data passed from parent widget
    required this.isDarkMode, // Dark mode flag passed from parent widget
    required this.titleFontSize, // Title font size passed from parent widget
    required this.bodyFontSize, // Body font size passed from parent widget
  });

  @override
  Widget build(BuildContext context) {
    // Step 1: Process the raw forecast data into daily aggregates
    final Map<String, Map<String, dynamic>> dailyForecasts = {};

    // Loop through each forecast entry to group data by day
    for (var forecast in forecastList) {
      final dateTime = DateTime.parse(forecast['dt_txt']); // Parse the timestamp of the forecast
      final dayKey = DateFormat('yyyy-MM-dd').format(dateTime); // Format date as 'yyyy-MM-dd' for grouping

      // Initialize the day's data if not already present in the map
      if (!dailyForecasts.containsKey(dayKey)) {
        dailyForecasts[dayKey] = {
          'temps': <double>[], // List to store temperatures
          'pop': <double>[], // List to store precipitation probabilities
          'conditions': <String>[], // List to store weather conditions
          'date': dateTime, // Store the date for later use
        };
      }

      // Add temperature (converted from Kelvin to Celsius), precipitation probability, and condition to the day's data
      dailyForecasts[dayKey]!['temps']
          .add((forecast['main']['temp'] as num? ?? 0.0).toDouble() - 273.15);
      dailyForecasts[dayKey]!['pop']
          .add((forecast['pop'] as num? ?? 0.0).toDouble() * 100);
      dailyForecasts[dayKey]!['conditions']
          .add(forecast['weather'][0]['main'] as String? ?? 'Unknown');
    }

    // Step 2: Aggregate data for each day to compute high/low temps, avg precipitation, and dominant condition
    final List<Map<String, dynamic>> dailyData = [];
    dailyForecasts.forEach((day, data) {
      final temps = data['temps'] as List<double>; // List of temperatures for the day
      final pop = data['pop'] as List<double>; // List of precipitation probabilities
      final conditions = data['conditions'] as List<String>; // List of weather conditions

      // Calculate the highest and lowest temperatures of the day
      final highTemp = temps.reduce((a, b) => a > b ? a : b);
      final lowTemp = temps.reduce((a, b) => a < b ? a : b);
      // Calculate the average precipitation probability
      final avgPop = pop.reduce((a, b) => a + b) / pop.length;
      // Determine the dominant weather condition for the day
      final dominantCondition = _getDominantCondition(conditions);

      // Add the aggregated data to the list
      dailyData.add({
        'date': data['date'], // Date of the forecast
        'highTemp': highTemp, // Highest temperature
        'lowTemp': lowTemp, // Lowest temperature
        'pop': avgPop, // Average precipitation probability
        'condition': dominantCondition, // Dominant weather condition
      });
    });

    // Step 3: Limit the forecast to 5 days
    final limitedDailyData =
        dailyData.length > 5 ? dailyData.sublist(0, 5) : dailyData;

    // Step 4: Build the UI for the 5-day forecast
    return Card(
      elevation: 6, // Adds shadow to the card
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Rounds card corners
      color: isDarkMode ? Colors.grey[850] : Colors.grey[900], // Sets card background color based on theme
      child: Padding(
        padding: const EdgeInsets.all(16.0), // Adds padding inside the card
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Aligns children to the start
          children: [
            // Title of the forecast section
            Text(
              "5-Day Forecast",
              style: TextStyle(
                color: Colors.white, // White text for visibility
                fontSize: titleFontSize, // Dynamic title font size
                fontWeight: FontWeight.bold, // Bold title
                fontFamily: 'Roboto', // Uses Roboto font
              ),
            ),
            const SizedBox(height: 12), // Adds spacing below the title
            // Maps the limited daily data into a list of forecast rows
            ...limitedDailyData.map((dayData) {
              final date = dayData['date'] as DateTime; // Date of the forecast
              final highTemp = dayData['highTemp'] as double; // High temperature
              final lowTemp = dayData['lowTemp'] as double; // Low temperature
              final pop = dayData['pop'] as double; // Precipitation probability
              final condition = dayData['condition'] as String; // Weather condition

              // Determine if the forecast is for today
              final now = DateTime.now();
              final isToday = date.day == now.day &&
                  date.month == now.month &&
                  date.year == now.year;
              // Set the day label ("Today" or formatted date)
              final dayLabel =
                  isToday ? "Today" : DateFormat('EEEE, MMM d').format(date);

              // Select the appropriate animation based on the weather condition
              String animationPath;
              switch (condition.toLowerCase()) {
                case 'thunderstorm':
                  animationPath = 'assets/animations/thunderstorm.json';
                  break;
                case 'rain':
                case 'drizzle':
                  animationPath = 'assets/animations/rain.json';
                  break;
                case 'clouds':
                case 'partlycloudy':
                  animationPath = 'assets/animations/cloudy.json';
                  break;
                case 'clear':
                  animationPath = 'assets/animations/sunny.json';
                  break;
                default:
                  animationPath = 'assets/animations/unknown.json';
              }

              // Build a row for each day's forecast
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0), // Adds vertical padding between rows
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal, // Allows horizontal scrolling
                  child: Row(
                    children: [
                      // Day label (e.g., "Today", "Monday, Oct 30")
                      SizedBox(
                        width: 120, // Fixed width for day label
                        child: Text(
                          dayLabel,
                          style: TextStyle(
                            color: Colors.white, // White text for visibility
                            fontSize: bodyFontSize, // Dynamic body font size
                            fontFamily: 'Roboto', // Uses Roboto font
                          ),
                          overflow: TextOverflow.ellipsis, // Ellipsis for overflow
                        ),
                      ),
                      const SizedBox(width: 10), // Adds spacing
                      // Precipitation probability with icon
                      Row(
                        children: [
                          const Icon(
                            Icons.water_drop, // Water drop icon for precipitation
                            color: Colors.blue, // Blue color for icon
                            size: 16, // Icon size
                          ),
                          const SizedBox(width: 4), // Adds spacing
                          Text(
                            '${pop.round()}%', // Displays rounded precipitation probability
                            style: TextStyle(
                              color: Colors.white, // White text
                              fontSize: bodyFontSize, // Dynamic font size
                              fontFamily: 'Roboto', // Uses Roboto font
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10), // Adds spacing
                      // Weather animation
                      SizedBox(
                        width: bodyFontSize * 2, // Dynamic width based on font size
                        height: bodyFontSize * 2, // Dynamic height based on font size
                        child: Lottie.asset(
                          animationPath, // Path to the Lottie animation
                          fit: BoxFit.contain, // Fits animation within bounds
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback UI if animation fails to load
                            return Container(
                              width: bodyFontSize * 2,
                              height: bodyFontSize * 2,
                              color: Colors.grey, // Grey background for error
                              child: const Center(child: Text('Error')), // Error text
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10), // Adds spacing
                      // High and low temperatures
                      SizedBox(
                        width: 60, // Fixed width for temperature display
                        child: Text(
                          '${highTemp.round()}°/${lowTemp.round()}°', // Displays high/low temps
                          style: TextStyle(
                            color: Colors.white, // White text
                            fontSize: bodyFontSize, // Dynamic font size
                            fontFamily: 'Roboto', // Uses Roboto font
                          ),
                          overflow: TextOverflow.ellipsis, // Ellipsis for overflow
                          textAlign: TextAlign.center, // Centers text
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // Helper method to determine the dominant weather condition for a day.
  String _getDominantCondition(List<String> conditions) {
    if (conditions.isEmpty) return 'Unknown'; // Returns 'Unknown' if no conditions
    final counts = <String, int>{}; // Map to count occurrences of each condition
    for (var condition in conditions) {
      counts[condition] = (counts[condition] ?? 0) + 1; // Increments count for each condition
    }
    // Returns the condition with the highest count
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}
