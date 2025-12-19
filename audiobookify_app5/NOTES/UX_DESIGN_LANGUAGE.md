# Design Language and Interaction Notes

This document captures the current visual and interaction language so we
can return to it consistently across screens.

## Visual theme

- **Typography**: expressive display for headers, clean sans for body.
  Titles should feel editorial; metadata should be lighter and muted.
- **Color system**: warm, neutral base with accent colors seeded from
  app theme palettes. Use cover art as ambient context, not direct
  foreground color.
- **Backgrounds**: layered atmosphere (soft gradients + subtle glow or
  blur) rather than flat fills.
- **Depth**: gentle shadows with soft blur; use glass panels for raised
  surfaces (cards, nav).
- **Shape language**: rounded rectangles over circles; 12–20px radii for
  cards and buttons.
- **Visual hierarchy**: single primary CTA per screen; metadata grouped
  into chips; progress shown with thin bars or segmented minimaps.

## Core UI patterns

- **Book cards**: 2:3 aspect, cover‑first, spine effect, progress chip.
- **Hero layout**: cover art + title + author + metadata chips + CTA.
- **Chapter list**: row with index, title, status pill, and a minimap
  progress bar underneath.
- **Minimap progress**: bucketed segments; active buckets draw with
  overlap and rounded edges.

## Interaction language

- **Tap feedback**: subtle fade + slight scale (0.96–0.98) rather than
  ripple.
- **Haptics**: selection click for standard taps; medium impact for
  primary actions.
- **Motion**: short easing (120–180ms) for state transitions and toggles;
  minimal bounce.
- **Navigation**: rounded rectangle buttons for nav icons with an active
  highlight pill; glass background behind nav.
- **Playback**: active paragraph highlighted; auto‑scroll tracks current
  paragraph; settings open as modal overlay.

## Progress model (UX implications)

- **Bucketed progress**: store 64 buckets per chapter; used for minimap
  visuals and percent debug readouts.
- **Progress text**: shown only in debug mode; otherwise rely on visuals.

## Debug UX

- **Debug Mode toggle**: surfaced in Settings; reveals bucket percent
  labels in chapter list to verify progress updates.
