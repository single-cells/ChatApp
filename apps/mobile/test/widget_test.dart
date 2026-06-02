import 'package:flutter_test/flutter_test.dart';
import 'package:chat_mobile/config/app_config.dart';

void main() {
  test('AppConfig has defaults', () {
    expect(AppConfig.apiBaseUrl, isNotEmpty);
  });
}
