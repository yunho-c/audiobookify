# Two-Stage Migration Plan: `audiobookify` to `rbook-utils` Render IR

## Summary

- Migrate `audiobookify` off the removed `rbook_utils::runtime` API and onto `rbook_utils::render_ir`.
- Stage 1 is a compatibility migration: restore a working app quickly by adapting Render IR down to the current Flutter reader model and preserving existing user-visible behavior.
- Stage 2 is a capability migration: expose typed internal links and source mapping end-to-end, while explicitly deferring publisher/book-driven styling for now.
- Keep the current Dart-side sentence segmentation and highlight behavior during both stages unless a richer source-map-based path fully replaces it.

## Stage 1: Compatibility Migration

- Replace the app Rust bridge import from `rbook_utils::runtime` to `rbook_utils::render_ir`.
- Introduce FRB-facing Rust DTOs that map from `render_ir::BookRenderModel` but stay close to the app’s current `ParsedEpubBook` shape:
  - `ParsedEpubBook { metadata, cover_image, sections }`
  - `Section { id, title, start_href, start_fragment, end_href, end_fragment, spine_start, spine_end, anchors, document }`
  - `ReaderDocument { chapter_href, blocks }`
  - simplified `ReaderBlock` and `ReaderInline` enums/structs matching the current Flutter reader
- Map Render IR blocks into the current app block model:
  - `Paragraph`, `Heading`, `Quote`, `List`, `Table`, `Image`, `Rule`
  - `Code` is preserved in Rust as a DTO but degraded safely in Flutter for v1 of the migration
- Map Render IR inlines into the current app inline model:
  - `Text`, `Span`, `Link`, `Image`, `Break`
  - link targets are flattened to a stable display string for now
  - inline images are preserved in Rust, but Flutter may initially flatten or ignore them if needed for a minimal compile-safe rollout
- Synthesize `ReaderDocument.chapterHref` from `section.source.start_href`.
- Keep image/resource loading working by adapting `ResourceRef.href` back into the existing image resolver path, or by changing the resolver to accept a resource DTO while keeping the rest of Flutter unchanged.
- Remove all remaining assumptions in app code that the Rust side exposes the old runtime types.
- Regenerate FRB bindings after the Rust bridge rewrite.
- Update the Dart adapter so it converts the new bridge DTOs into the existing `reader_ir.dart` compatibility model.
- Keep `reader_segmentation.dart`, `reader_renderer.dart`, and the current TTS paragraph/sentence mapping logic intact in this stage.

### Acceptance Criteria for Stage 1

- app compiles
- `PlayerScreen` loads sections from the new Render IR bridge
- existing reader rendering still works
- current sentence highlighting and resume behavior still work
- image blocks still load

## Stage 2: Capability Migration

- Expand the Rust bridge DTOs to expose the Render IR semantics that the current compatibility layer flattens away:
  - typed link targets
  - source maps
  - resource refs
  - code blocks and inline images as first-class types
- Evolve the Flutter reader model instead of continuing to adapt everything into the older simplified IR:
  - add section source range metadata
  - add `SourceMap` on blocks and relevant inlines
  - replace `String href` links with a typed link target model
  - replace plain image `src` with a resource representation or a resolved resource handle
  - add code block support to the Flutter IR
- Update the renderer so links become actionable:
  - external links open externally
  - internal links navigate within the current book using `section_id`, `section_index`, and optional fragment
- Add source-map-aware reader capabilities:
  - stable internal navigation targets
  - source-based resume anchors
  - groundwork for future annotations/search/highlights
- Keep the current sentence segmentation pipeline, but attach its output to source-mapped nodes so sentence-level interaction can later be anchored to the book model rather than only paragraph indices.
- Do not implement publisher/book-driven styling in this stage.
  - ignore `stylesheets` except for carrying them through the bridge if useful for future work
  - do not plan CSS parsing or application
  - do not make Flutter rendering depend on publisher stylesheet fidelity

### Acceptance Criteria for Stage 2

- internal links work in reader UI
- source maps are available in Flutter for rendered content
- code blocks render distinctly
- inline images are preserved rather than flattened away
- current TTS highlighting still functions after the richer model is introduced

## Public API and Type Changes

- In `rbook-utils` consumption:
  - app stops calling `parse_epub_runtime` and instead uses `parse_epub_render_model`
  - app stops assuming `read_epub_resource_bytes(path, href)` and adapts to the `ResourceRef`-based resource API
- In the app Rust bridge:
  - Stage 1 keeps a compatibility-oriented `ParsedEpubBook` API for Flutter
  - Stage 2 introduces richer DTOs for links, source maps, code blocks, inline images, and resource refs
- In Flutter:
  - Stage 1 preserves the current `reader_ir.dart` surface as a compatibility target
  - Stage 2 replaces it with a richer reader model aligned to Render IR semantics
- The app should not reintroduce the removed raw TOC DTO as a required UI dependency; the chapter list continues to be section-driven

## Test Plan

- Rust-side app bridge tests:
  - bridge compiles against `rbook_utils::render_ir`
  - `open_epub` returns sections for known fixtures
  - cover image and image resource reads still work
  - internal link targets are bridged correctly in Stage 2
  - source maps are present and stable in Stage 2
- `rbook-utils` validation:
  - keep the existing `render_ir` test suite as the source-of-truth parser contract
- Flutter tests:
  - adapter tests for new Rust DTOs
  - reader renderer tests for paragraphs, headings, tables, images, code blocks, and inline images as they become supported
  - player/detail screen tests updated to the new DTO shapes
  - sentence segmentation/highlighting tests remain green through both stages
- Integration/smoke scenarios:
  - open a real EPUB with headings, images, internal anchors, and tables
  - tap chapter list entry and confirm correct section loads
  - verify image rendering
  - in Stage 2, tap an internal link and verify in-book navigation

## Assumptions and Defaults

- Stage 1 prioritizes compatibility and speed over exposing every new Render IR feature.
- Stage 2 will add internal links and source maps, but will not implement publisher/book-driven styling yet.
- The existing Flutter reader theme remains the source of visual styling during both stages.
- TTS segmentation stays in Dart for now; Rust remains responsible for parsing and structural IR, not sentence policy.
- The plan assumes `rbook-utils` Render IR remains the parser source of truth and `audiobookify` should adapt to it rather than maintaining a parallel parser model.
