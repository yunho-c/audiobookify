# TODOs

- Sentry: add DSN and confirm environment/release values for production builds.
- Android on-device QA: verify Open Library search/download works, playback persists in background, lock-screen controls appear, and Android 13+ notification permission prompt shows.
- Data pane UI: add an "App Data" section in Settings with storage usage, list of saved EPUBs, and a "Clear" flow.
- Delete-cleanup: when a book is deleted, remove its EPUB file from `library/` and delete associated progress buckets.
- Performance regression: add a profile-mode integration test using `IntegrationTestWidgetsFlutterBinding.traceAction` around opening a large EPUB and track frame build/raster times in CI.
