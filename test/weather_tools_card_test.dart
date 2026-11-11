import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expnz/services/weather_service.dart';
import 'package:expnz/widgets/weather_tools_card.dart';

void main() {
  testWidgets('WeatherToolsCard loads from local storage without showing loading spinner', (tester) async {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Mock local storage containing today's morning weather forecast
    SharedPreferences.setMockInitialValues({
      'expnz_weather_cache_date_v1': todayStr,
      'expnz_weather_cache_data_v1': '''[
        {
          "displayDateTime": {"hours": 10},
          "temperature": {"degrees": 28.0},
          "precipitation": {"probability": {"percent": 0, "type": "RAIN"}},
          "weatherCondition": {"description": {"text": "Sunny"}}
        },
        {
          "displayDateTime": {"hours": 14},
          "temperature": {"degrees": 33.0},
          "precipitation": {"probability": {"percent": 0, "type": "RAIN"}},
          "weatherCondition": {"description": {"text": "Sunny"}}
        }
      ]''',
      'expnz_weather_enabled_v1': true,
    });

    final weatherService = WeatherService();
    // Preload from local storage (like app does at launch / morning notification)
    await weatherService.initFromLocalStorage();

    expect(weatherService.hasWeatherForToday, isTrue);

    // Build the WeatherToolsCard
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WeatherToolsCard(),
        ),
      ),
    );

    // Initial frame should ALREADY have the weather without showing CircularProgressIndicator
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('28°C'), findsOneWidget);
    expect(find.text('Sunny'), findsOneWidget);
    expect(find.text('Weather Forecast'), findsOneWidget);
    expect(find.text('9 AM ON'), findsOneWidget);

    await tester.pumpAndSettle();

    // Still no CircularProgressIndicator and same data
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('28°C'), findsOneWidget);
  });
}

