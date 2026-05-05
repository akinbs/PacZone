import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static bool useRealLocation = true;
  static String apiBaseUrl = '';

  static bool get useRealApi => apiBaseUrl.isNotEmpty;

  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
      apiBaseUrl = dotenv.env['API_BASE_URL'] ?? '';
    } catch (_) {
      apiBaseUrl = '';
    }
  }
}
