# Audiobookify Code Review

**Date:** December 18, 2024

## Architecture Overview

Flutter-based audiobook player with Rust backend for EPUB parsing (via `flutter_rust_bridge`), ObjectBox for persistence, and `flutter_tts` for text-to-speech.

---

## ✅ Strengths

### 1. Clean Layer Separation
- Models, Services, Screens, and Widgets properly organized
- `BookService` cleanly abstracts ObjectBox operations
- `TtsService` properly encapsulates TTS functionality

### 2. Rust Integration
- Excellent `flutter_rust_bridge` usage for native EPUB parsing
- Well-documented `epub.rs` with proper error handling
- Loading chapter content upfront avoids FFI lifetime issues

### 3. Design System
- Well-structured `AppTheme` and `AppColors` with Tailwind-inspired palette
- Typography hierarchy with `Playfair Display` + `Inter`
- Consistent shadows and rounded corners

### 4. UI Polish
- Book cards with spine effects and cover overlays
- Sentence-level TTS highlighting
- Glassmorphism bottom nav

---

## ⚠️ Areas for Improvement

### 1. Global State Anti-Pattern (Medium)

**Location:** `main.dart:16-17`
```dart
late final Store objectboxStore;
late final BookService bookService;
```

**Issue:** Global mutable state makes testing difficult.

**Fix:** Use DI (`provider`, `riverpod`, or `get_it`).

---

### 2. Duplicate Widget Code (Low)

**Issue:** `_BookCardFromDb` in `home_screen.dart` duplicates `BookCard` in `book_card.dart` (~150 lines).

**Fix:** Unify into single `BookCard` widget.

---

### 3. Magic Numbers in Scrolling (Medium)

**Location:** `player_screen.dart:178`
```dart
final scrollPosition = index * 120.0;
```

**Issue:** Hardcoded scroll offset is brittle.

**Fix:** Use `GlobalKey` + `RenderBox` or `Scrollable.ensureVisible()`.

---

### 4. Incomplete Abbreviations List (Low)

**Location:** `tts_service.dart:57`

**Issue:** Sentence splitting misses `St.`, `Ave.`, `No.`, `Inc.`, `Ltd.`, etc.

**Fix:** Expand regex or use robust tokenizer.

---

### 5. Unused Reactive Stream (Medium)

**Issue:** `BookService.watchAllBooks()` implemented but unused. `HomeScreen` reloads manually.

**Fix:** Use `StreamBuilder` with `watchAllBooks()`.

---

### 6. Non-Functional Settings (Medium)

**Issue:** `SettingsWheel` and `SettingsScreen` are hardcoded/decorative.

**Fix:** Wire controls to `TtsService` and persist via `SharedPreferences`.

---

### 7. Raw Error Display (Low)

**Location:** `player_screen.dart:274`

**Issue:** Errors shown as raw strings without retry options.

**Fix:** Add user-friendly messages and retry buttons.

---

### 8. Memory Concern for Large EPUBs (Medium)

**Location:** `epub.rs:46`
```rust
pub chapter_contents: Vec<String>,
```

**Issue:** All chapters loaded into memory upfront.

**Fix:** Consider lazy loading or size warnings.

---

### 9. Minimal Test Coverage (High)

**Issue:** Only one integration test exists. No unit tests for services.

**Fix:** Add tests for:
- `TtsService._splitIntoSentences()`
- `BookService` CRUD operations
- Widget tests for key screens

---

### 10. Route Navigation Inconsistency (Low)

**Issue:** Mixing `.push()` and `.go()` causes unexpected back stack behavior.

**Fix:** Standardize approach or document conventions.

---

## 🔴 Critical Issues

### Duplicate Book Imports

**Location:** `book_service.dart:saveBook()`

**Issue:** No duplicate check. Same EPUB can be imported multiple times.

**Fix:** Check by `filePath` or `metadata.identifier` before insert.

---

## Performance Suggestions

1. Debounce scroll-to-paragraph animation
2. Cache Google Fonts for offline use
3. Use `const` constructors more aggressively

---

## Summary

| Category | Rating |
|----------|--------|
| Architecture | ⭐⭐⭐⭐ Good, needs DI |
| Code Quality | ⭐⭐⭐ Clean, some duplication |
| Functionality | ⭐⭐⭐ Core works, settings incomplete |
| Testing | ⭐ Minimal coverage |
| UI/UX | ⭐⭐⭐⭐ Polished design |

**Overall:** Well-crafted prototype with professional design. Main gaps: state management, testing, and completing settings functionality.
