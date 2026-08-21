import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot:
        (String name, List<int> bytes, [Map<String, Object?>? args]) async {
          final output = File('build/ios-simulator/screenshots/$name.png');
          await output.parent.create(recursive: true);
          await output.writeAsBytes(bytes, flush: true);
          return true;
        },
  );
}
