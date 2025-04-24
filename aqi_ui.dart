import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';

class AQIUI extends StatefulWidget {
  final int currentAQI;
  final double currentPM25;
  final double currentPM10;

  const AQIUI({
    super.key,
    required this.currentAQI,
    required this.currentPM25,
    required this.currentPM10,
  });

  @override
  State<AQIUI> createState() => _AQIUIState();
}

class _AQIUIState extends State<AQIUI> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Determine AQI color and health recommendation based on the 1-5 scale (OpenWeather)
  (Color, String) _getAQIInfo(int aqi) {
    switch (aqi) {
      case 1:
        return (Colors.green, 'Good - Enjoy outdoor activities!');
      case 2:
        return (Colors.yellow, 'Fair - Sensitive groups should limit prolonged exertion.');
      case 3:
        return (Colors.orange, 'Moderate - Unhealthy for sensitive groups; reduce outdoor time.');
      case 4:
        return (Colors.red, 'Poor - Avoid outdoor activities; seek indoor air quality.');
      case 5:
        return (Colors.purple, 'Very Poor - Stay indoors; use air purifiers if available.');
      default:
        return (Colors.grey, 'Unknown - Check data reliability.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (color, recommendation) = _getAQIInfo(widget.currentAQI);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.3), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Air Quality Index',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _animation.value + 0.9,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'AQI: ${widget.currentAQI}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'PM2.5: ${widget.currentPM25.toStringAsFixed(1)} µg/m³',
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  Text(
                    'PM10: ${widget.currentPM10.toStringAsFixed(1)} µg/m³',
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    recommendation,
                    style: TextStyle(fontSize: 14, color: Colors.black87.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}