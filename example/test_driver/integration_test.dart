import 'package:integration_test/integration_test_driver.dart';

/// Runs `integration_test/app_test.dart` with `flutter drive`, which can
/// build the app ahead of time (`--profile`), as it ships.
Future<void> main() => integrationDriver();
