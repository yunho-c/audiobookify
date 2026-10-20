import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 25),
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final output = Directory(
      Platform.environment['MLSR_VALIDATION_OUTPUT'] ??
          '.mlsr/native-validation',
    );
    await output.create(recursive: true);
    final result = Map<String, dynamic>.from(data ?? {});
    final screenshot = result.remove('screenshot_png_base64') as String?;
    if (screenshot != null) {
      await File(
        '${output.path}/reader.png',
      ).writeAsBytes(base64Decode(screenshot));
    }
    await File(
      '${output.path}/summary.json',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(result));
  },
);
