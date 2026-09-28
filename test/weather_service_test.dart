import 'package:flutter_test/flutter_test.dart';
import 'package:expnz/services/weather_service.dart';

void main() {
  group('WeatherService Tests', () {
    final weatherService = WeatherService();

    test('formatTime properly formats 24h into 12h AM/PM format', () {
      expect(WeatherService.formatTime(0), '12:00 AM');
      expect(WeatherService.formatTime(9), '9:00 AM');
      expect(WeatherService.formatTime(12), '12:00 PM');
      expect(WeatherService.formatTime(14), '2:00 PM');
      expect(WeatherService.formatTime(23), '11:00 PM');
    });

    test('generateSummary correctly generates no-rain summary and temperatures', () {
      final mockHours = [
        {
          'displayDateTime': {'hours': 9},
          'temperature': {'degrees': 28.0},
          'precipitation': {
            'probability': {'percent': 0, 'type': 'RAIN'}
          },
          'weatherCondition': {
            'description': {'text': 'Sunny'}
          }
        },
        {
          'displayDateTime': {'hours': 14},
          'temperature': {'degrees': 34.5},
          'precipitation': {
            'probability': {'percent': 10, 'type': 'RAIN'}
          },
          'weatherCondition': {
            'description': {'text': 'Sunny'}
          }
        },
        {
          'displayDateTime': {'hours': 21},
          'temperature': {'degrees': 26.0},
          'precipitation': {
            'probability': {'percent': 0, 'type': 'RAIN'}
          },
          'weatherCondition': {
            'description': {'text': 'Clear'}
          }
        }
      ];

      final summary = weatherService.generateSummary(mockHours);

      expect(summary.hasRain, isFalse);
      expect(summary.minTemp, 26);
      expect(summary.maxTemp, 35);
      expect(summary.peakHour, 14);
      expect(summary.body, contains('No rain expected today'));
      expect(summary.body, contains('26°C - 35°C'));
      expect(summary.body, contains('Peak 35°C at 2:00 PM'));
    });

    test('generateSummary correctly detects rain probabilities and timings', () {
      final mockHours = [
        {
          'displayDateTime': {'hours': 9},
          'temperature': {'degrees': 27.0},
          'precipitation': {
            'probability': {'percent': 15, 'type': 'RAIN'}
          },
          'weatherCondition': {
            'description': {'text': 'Partly cloudy'}
          }
        },
        {
          'displayDateTime': {'hours': 13},
          'temperature': {'degrees': 32.0},
          'precipitation': {
            'probability': {'percent': 65, 'type': 'RAIN'}
          },
          'weatherCondition': {
            'description': {'text': 'Thunderstorms'}
          }
        },
        {
          'displayDateTime': {'hours': 17},
          'temperature': {'degrees': 29.0},
          'precipitation': {
            'probability': {'percent': 40, 'type': 'RAIN'}
          },
          'weatherCondition': {
            'description': {'text': 'Light rain showers'}
          }
        }
      ];

      final summary = weatherService.generateSummary(mockHours);

      expect(summary.hasRain, isTrue);
      expect(summary.rainSlots.length, 2);
      expect(summary.body, contains('Rain expected around'));
      expect(summary.body, contains('up to 65% at 1:00 PM'));
      expect(summary.body, contains('27°C - 32°C'));
    });
  });
}
