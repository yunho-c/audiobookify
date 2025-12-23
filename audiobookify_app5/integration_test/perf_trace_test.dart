import 'dart:io';

import 'package:audiobookify/src/rust/api/epub.dart';
import 'package:audiobookify/src/rust/frb_generated.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Perf trace: open EPUB', (WidgetTester tester) async {
    await RustLib.init();

    final bytes = await rootBundle.load('test/assets/test_ebook.epub');
    final tempDir = await getTemporaryDirectory();
    final epubFile = File('${tempDir.path}/perf_test.epub');
    await epubFile.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Perf Trace')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await binding.traceAction(
      () async {
        await openEpub(path: epubFile.path);
      },
      reportKey: 'open_epub_timeline',
    );

    await binding.watchPerformance(
      () async {
        await tester.pump();
        await tester.runAsync(() async {
          await openEpub(path: epubFile.path);
        });
        await tester.pump();
      },
      reportKey: 'open_epub_frame_times',
    );
  });
}
