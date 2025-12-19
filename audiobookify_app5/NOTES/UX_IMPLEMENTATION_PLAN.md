# UX Implementation Plan

This plan translates the UX critique into a concrete, file-level
implementation path. The work is grouped by category and ordered for
impact.

## Aesthetics

- `lib/core/app_theme.dart`: finalize typography pairing and spacing
  scale (title/display vs. body/meta).
- `lib/screens/book_detail_screen.dart`: build a cinematic hero header
  using cover art, title, narrator, and a primary CTA.
- `lib/screens/home_screen.dart`: standardize book cards, spacing, and
  section hierarchy.
- `lib/screens/player_screen.dart`: add ambient background, glass UI,
  and now-playing styling anchored to cover art.

## Interactivity

- `lib/screens/player_screen.dart`: animate play/pause transitions,
  add haptics for core actions, and introduce action chips.
- `lib/screens/book_detail_screen.dart`: add chapter progress state
  indicators and rich press feedback.
- `lib/screens/home_screen.dart`: add a "Continue Listening" CTA and
  polished list affordances.

## Premium Features

- `lib/screens/player_screen.dart`: ambient playback mode and focus
  layout around chapter timeline.
- `lib/core/providers.dart`: store last-played book/chapter and progress
  for "Continue Listening."
- `lib/services/tts_service.dart`: surface playback state transitions
  and settings for smoother UI animation.

## Shared UI (new widgets)

- `lib/widgets/book_card.dart`: unified book tile styling.
- `lib/widgets/chapter_row.dart`: reusable chapter rows with progress.
- `lib/widgets/player_controls.dart`: shared control cluster with
  animated icons and action chips.
