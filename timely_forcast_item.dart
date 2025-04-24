 // Import the Flutter Material package for UI components and styling
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart'; // Import Lottie for animation support

// HourlyForcastItem is a stateful widget to display a single hourly weather forecast
class HourlyForcastItem extends StatefulWidget {
  // Properties to hold the time, temperature, and weather animation (child)
  final String time; // The time of the forecast (e.g., "3 PM")
  final String temperature; // The temperature at that time (e.g., "25°C")
  final Widget child; // The child widget (e.g., Lottie animation) to represent the weather

  // Constructor with required parameters for time, temperature, and child
  const HourlyForcastItem({
    super.key, // Optional key for widget identification
    required this.time, // Time for the forecast
    required this.temperature, // Temperature
    required this.child, required IconData icon, // Child widget (Lottie animation) is required
  });

  @override
  // Creates the state for this widget, enabling state management and animations
  State<HourlyForcastItem> createState() => _HourlyForcastItemState();
}

// _HourlyForcastItemState manages the state of HourlyForcastItem, including animations
class _HourlyForcastItemState extends State<HourlyForcastItem>
    with SingleTickerProviderStateMixin {
  // Animation controller to manage the fade-in animation
  late AnimationController _controller;
  // Animation to control the opacity for the fade effect
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState(); // Calls the parent class's initState method
    // Initializes the animation controller with a 500ms duration
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500), // Animation lasts 500 milliseconds
      vsync: this, // Uses SingleTickerProviderStateMixin to sync animation with widget lifecycle
    );
    // Sets up a fade animation from 0 (invisible) to 1 (fully visible) with an ease-in curve
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn), // Ease-in curve for smooth start
    );
    // Starts the animation when the widget is first loaded
    _controller.forward();
  }

  @override
  void dispose() {
    // Disposes of the animation controller to free resources
    _controller.dispose();
    super.dispose(); // Calls the parent class's dispose method
  }

  @override
  Widget build(BuildContext context) {
    // Builds the UI for the hourly forecast item with a fade-in animation
    return FadeTransition(
      opacity: _fadeAnimation, // Applies the fade animation to the widget
      child: Tooltip(
        message: widget.time, // Shows the full time on long press (useful if truncated)
        child: Card(
          elevation: 10, // Adds shadow to the card for a raised effect
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Rounds the card corners
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.25, // Sets width to 25% of screen width
            height: 120, // Fixed height to prevent overflow (adjust as needed)
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12), // Matches the card's rounded corners
              gradient: const LinearGradient(
                colors: [Colors.blueAccent, Colors.white], // Gradient from blue to white
                begin: Alignment.topLeft, // Gradient starts at top-left
                end: Alignment.bottomRight, // Gradient ends at bottom-right
                stops: [0.2, 1.0], // Gradient color stops (20% blue, 100% white)
              ),
            ),
            padding: const EdgeInsets.all(8.0), // Adds padding inside the container
            child: SingleChildScrollView( // Allows scrolling if content overflows
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, // Centers content vertically
                mainAxisSize: MainAxisSize.min, // Minimizes the height of the column
                children: [
                  // Displays the forecast time (e.g., "3 PM")
                  Text(
                    widget.time,
                    style: const TextStyle(
                      fontSize: 18, // Text size for readability
                      fontWeight: FontWeight.bold, // Bold text for emphasis
                      color: Colors.black87, // Slightly transparent black for contrast
                    ),
                    maxLines: 1, // Limits text to one line
                    overflow: TextOverflow.ellipsis, // Adds ellipsis if text overflows
                  ),
                  const SizedBox(height: 5), // Adds vertical spacing between elements
                  // Displays the weather animation (Lottie child) with constrained size
                  SizedBox(
                    height: 40, // Constrain Lottie height to prevent overflow
                    child: widget.child,
                  ),
                  const SizedBox(height: 5), // Adds vertical spacing
                  // Displays the temperature (e.g., "25°C")
                  Text(
                    widget.temperature,
                    style: const TextStyle(
                      fontSize: 14.5, // Smaller text size for temperature
                      color: Colors.black87, // Slightly transparent black for contrast
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}