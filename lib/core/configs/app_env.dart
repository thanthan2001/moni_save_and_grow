import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  static Future<void> init({String fileName = '.env'}) async {
    try {
      await dotenv.load(fileName: fileName);
    } catch (e) {
      // Nếu file .env không tồn tại, bỏ qua lỗi (dùng giá trị mặc định)
      print('Warning: .env file not found, using default values');
    }
  }

  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://api.example.com';
  static String get appEnv => dotenv.env['APP_ENV'] ?? 'development';
  static int get timeout =>
      int.tryParse(dotenv.env['TIMEOUT'] ?? '3000') ?? 3000;
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
}
