# Audiobookify

Flutter EPUB reader with local MLSR speech and a System TTS fallback. The MLSR
integration targets **Apple Silicon, macOS 15+**. Use Flutter 3.41+ / Dart 3.11+,
Xcode, CocoaPods, and Rust 1.88+. The current MLSR build hook does not support
mobile builds; System TTS fallback does not change that packaging limitation.

## Development

Keep `MLSR` and `rbook-utils` beside the `audiobookify` checkout. The MLSR Dart
packages are local path dependencies. This integration was developed against
MLSR `14ff251`; its model catalog and native bindings must come from one checkout.

Prepare the verified model assets **before** resolving Flutter dependencies:

```sh
# From audiobookify/audiobookify_app5, with the model already prepared locally:
cargo run --manifest-path ../../MLSR/Cargo.toml --locked --release -p mlsr-cli -- \
  models prepare-flutter --config "$PWD/mlsr-models.yaml"
flutter pub get
flutter run -d macos
```

`mlsr-models.yaml` selects the FP16 T384 Supertonic3 bundle with ten preset voices.
Its source directory must contain the exact payloads pinned by the MLSR manifest.
See MLSR's `docs/model-delivery.md` for preparation. The CLI verifies and packages
the local files; it does not download models. Generated assets and evidence live
under ignored `.mlsr/`. They include the upstream model and preprocessing notices.
The app reads bundled model files directly, without another installed model copy.

The Flutter native-asset hook builds MLSR with Core ML and Apple output. The
existing Flutter Rust Bridge package independently supplies EPUB parsing.

Debug builds retain the existing ad-hoc signing setup. Sandboxed release builds
use the same development team as the iOS target (`3YWW337ZMW`) and the matching
ObjectBox semaphore group `3YWW337ZMW.abook`. For another signing team, update
the Runner release settings, `Release.entitlements`, and `library_store.dart`
together; ObjectBox limits that group ID to 19 characters. The database remains
at `<application documents>/objectbox`. Debug/Profile builds are unsandboxed and
use `~/Documents`; release builds use `Data/Documents` inside the app's macOS
sandbox container. Switching between them therefore shows separate libraries
and preferences; it does not delete the previous data. Existing development
libraries are not automatically copied into the sandbox.

Both entitlement files grant read-only access to user-selected files for EPUB
import. The importer copies each selected EPUB into its own documents/library
directory, so it does not need write access to the original or a persistent
security-scoped bookmark. The bundle audit checks the signed file-access
entitlement as well as the model assets and native libraries.

## Playback behavior

- MLSR loads lazily when speech or voice discovery is first requested. Opening the
  library does not load the model. A persistent engine is reused across sentences.
- Speed controls pitch-preserving playback rate; model speaking rate stays at its
  default. Pitch adjustment is unavailable for MLSR. The book's language is passed
  to MLSR with explicit same-language locale fallback; missing metadata uses English.
- Sentence highlighting, chapter navigation, and saved reading positions remain
  owned by Audiobookify. Pause/resume currently replays the selected sentence.
  Native mid-sentence pause and document-wide time seeking are future reader work.
- MLSR owns synthesis, bounded PCM buffering, native output, and cancellation.
  `speak` finishes after output drains. Completed sentence handles are released;
  audio retention is disabled for this sentence-based player.
- Retired Kokoro settings migrate to MLSR, clearing incompatible voice IDs.
  Explicit System selections, speed, and reading positions are preserved.
  Initialization failure visibly selects System speech for that run, with Retry.
  Synthesis errors stop at the selected sentence instead of silently skipping it.

## Validation

```sh
flutter test
flutter analyze
flutter drive -d macos --driver=test_driver/mlsr_integration_test.dart \
  --target=integration_test/mlsr_reader_test.dart \
  --dart-define=MLSR_TEST_FULL_CHAPTER=true
python3 tool/validate_mlsr_offline.py
# Restore the normal app after the release test target:
flutter build macos --release --target=lib/main.dart
python3 tool/verify_mlsr_app.py build/macos/Build/Products/Release/audiobookify_app5.app
```

The native integration test uses temporary library data, the bundled Alice EPUB,
and real Core ML/native output. It defaults to muted playback; add
`--dart-define=MLSR_TEST_AUDIBLE=true` for a listening run. A full chapter takes
several minutes at 2x playback. Its report and screenshot are written to
`.mlsr/native-validation/` (override with `MLSR_VALIDATION_OUTPUT`). Native handle
counts, sentence completion, navigation, and heartbeat timing are recorded separately
from listening quality. Existing skipped UI tests and unrelated analyzer findings
are not passing evidence.

The offline helper builds a short release reader test and creates an APFS clone
with App Sandbox still enabled and network entitlements removed. It verifies that
socket creation and reads from the source model cache are denied, then exercises
real bundled speech. Evidence is kept in `.mlsr/release-offline-*/`. This test-only
copy does not change the normal app's entitlements or the user's library data.

Local validation on 2026-10-19 (M4 Pro, macOS 27.0.1) passed 87 unit/widget
tests, with nine existing skips. A debug run completed all 72 sentences / 2,199
words of the Alice chapter with one model open; a sandboxed release run completed
the short reader test with network/cache denial and settings-driven voice changes.
Both returned the MLSR native handle count to zero. The new speech code passes
focused analysis; the full app still has 13 existing analyzer warnings.

First Play took 23–27 seconds in these processes, including model loading; the
engine is reused afterward. Preparation does not display a reader banner or
change the reading layout. These are single-run observations, without a
cold-cache or performance qualification.
The runs were muted, so listening quality remains unassessed.

The existing EPUB section mapping exposes some Alice chapter text under a
`Contents` label. The test selects its corpus by text and verifies navigation
against the returned section metadata. That parser issue remains separate from
speech integration.
