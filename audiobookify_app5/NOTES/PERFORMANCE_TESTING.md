# Performance Testing

## Prerequisites

- A device or emulator connected.
- Flutter SDK available via `flutter`.

## Run the perf trace integration test

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/perf_trace_test.dart \
  --profile
```

## Where results are saved

The integration test writes trace output to:

```
build/integration_response_data.json
```

Look for the `open_epub_timeline` and `open_epub_frame_times` entries.

## Notes

- The test uses the bundled EPUB asset (`test/assets/test_ebook.epub`).
- Profile mode is required for reliable timing data.
