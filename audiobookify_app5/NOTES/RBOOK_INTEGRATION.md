# rbook Integration with Flutter via flutter_rust_bridge

Documentation of integrating the `rbook` Rust EPUB parsing library into a Flutter app using `flutter_rust_bridge`.

## Overview

- **rbook**: Rust library for parsing EPUB 2/3 files
- **flutter_rust_bridge**: FFI bridge for calling Rust from Dart
- **Result**: Native-speed EPUB parsing with Dart-friendly API

## Setup Steps

### 1. Add flutter_rust_bridge to existing Flutter project

```bash
# Install codegen tool
cargo install flutter_rust_bridge_codegen

# Integrate into existing project (creates rust/ and rust_builder/ directories)
flutter_rust_bridge_codegen integrate

# Initialize Rust library
await RustLib.init();
```

### 2. Add rbook dependency

```toml
# rust/Cargo.toml
[dependencies]
rbook = "0.6.9"
flutter_rust_bridge = "2.11.1"
```

### 3. Configure nightly Rust toolchain

**Critical**: rbook 0.6.9 requires Rust Edition 2024, only available in nightly.

Create `rust/cargokit.yaml`:
```yaml
cargo:
  debug:
    toolchain: nightly
  release:
    toolchain: nightly
  profile:
    toolchain: nightly
```

## API Design

### Key Decision: Load All Data Upfront

To avoid complex lifetime management across FFI, all book data is loaded into a single struct:

```rust
pub struct EpubBook {
    pub metadata: EpubMetadata,
    pub chapters: Vec<ChapterInfo>,
    pub toc: Vec<TocEntry>,
    pub cover_image: Option<Vec<u8>>,
    pub chapter_contents: Vec<String>,  // All HTML loaded upfront
}
```

### API Functions

```rust
// Open from file path
pub fn open_epub(path: String) -> Result<EpubBook, EpubError>

// Open from bytes (for app bundles)
pub fn open_epub_bytes(bytes: Vec<u8>) -> Result<EpubBook, EpubError>

// Sync accessors (marked with frb(sync))
#[flutter_rust_bridge::frb(sync)]
pub fn get_chapter_count(book: &EpubBook) -> usize
```

## rbook API Gotchas

### 1. EpubToc iteration returns tuples

```rust
// Wrong
for entry in epub.toc() { ... }

// Correct - it's (TocKind, EpubTocEntry)
for (_kind, entry) in epub.toc() { ... }
```

### 2. TocEntry trait must be imported for children()

```rust
use rbook::ebook::toc::TocEntry;  // Required for entry.children()
```

### 3. href() returns Option<Href>

```rust
// Wrong
let href = entry.href().to_string();

// Correct
let href = entry.href().map(|h| h.to_string()).unwrap_or_default();
```

### 4. Use label() not title()

```rust
// Wrong - no title() method
let title = entry.title();

// Correct
let title = entry.label().to_string();
```

## macOS Entitlements

For debug testing, disable sandbox to allow file system access:

```xml
<!-- macos/Runner/DebugProfile.entitlements -->
<key>com.apple.security.app-sandbox</key>
<false/>
```

## Generating Dart Bindings

```bash
flutter_rust_bridge_codegen generate
```

Creates:
- `lib/src/rust/api/epub.dart` - Dart API
- `lib/src/rust/frb_generated.dart` - FFI glue

## Usage in Dart

```dart
import 'package:myapp/src/rust/api/epub.dart';
import 'package:myapp/src/rust/frb_generated.dart';

// Initialize once at app startup
await RustLib.init();

// Load EPUB
final book = await openEpub(path: '/path/to/book.epub');

// Access data
print('Title: ${book.metadata.title}');
print('Chapters: ${book.chapters.length}');

// Display cover
if (book.coverImage != null) {
  Image.memory(book.coverImage!);
}
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `Cargo.lock version 4` error | Delete `rust/Cargo.lock` and regenerate with `cargo generate-lockfile` |
| `edition2024` not supported | Create `cargokit.yaml` with `toolchain: nightly` |
| Can't find file on macOS | Disable sandbox or use absolute paths |
| `children()` method not found | Import `rbook::ebook::toc::TocEntry` trait |
