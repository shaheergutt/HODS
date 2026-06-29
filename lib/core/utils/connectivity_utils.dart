import 'dart:io';
import 'app_logger.dart';

class ConnectivityUtils {
  static Future<bool> hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      AppLogger.w('Network connectivity check failed: SocketException');
      return false;
    } catch (e) {
      AppLogger.e('Error during network check', e);
      return false;
    }
  }
}
