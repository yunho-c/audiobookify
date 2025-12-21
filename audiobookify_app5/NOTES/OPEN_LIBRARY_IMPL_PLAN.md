# Open Library integration plan (Flutter)

## Goals
- Add a Discover flow for public-domain EPUBs using the Open Library Search API.
- Enable fast search + preview + download + import into ObjectBox library.
- Keep UI consistent with the existing design language (glass, palettes, book cards).

## Product scope
- Create screen gets a Discover tab/section next to Import EPUB.
- Search input with debounce + curated Explore chips.
- Results grid with “Public Domain” badge and Download CTA.
- Preview sheet with cover, author, year, description, and Download & Add.
- Download progress and queue feedback.

## API usage (from tutorial)
- Endpoint: `https://openlibrary.org/search.json`
- Params: `q`, `has_fulltext=true`, `fields=key,title,author_name,cover_i,ia,ebook_access,first_publish_year,language`, `limit=20`, `page`.
- Filter: `ebook_access == "public"` and `ia` present.
- Cover URL: `https://covers.openlibrary.org/b/id/{cover_i}-M.jpg`
- EPUB URL: `https://archive.org/download/{ia}/{ia}.epub`
- User-Agent header with contact info.

## Architecture
- Client-side only (no server needed).
- New service: `lib/services/open_library_service.dart`.
- Model: `PublicBook` (title, authors, year, coverUrl, epubUrl, key, iaId).
- Provider: `openLibraryServiceProvider` + `openLibrarySearchProvider` (async).
- Caching: in-memory per query + SharedPreferences (recent queries, last results).

## UI plan
1) Create screen
   - Add a segmented control: Import / Discover.
   - Discover tab includes search bar, chips, and results grid.
2) Results
   - Reuse visual language of `BookCard` with a compact “Public Domain” badge.
   - CTA buttons: Download, Preview.
3) Preview
   - Bottom sheet with metadata + Download & Add to Library.
4) Empty states
   - No results: suggest alternate keywords.
   - API error: retry button + short explanation.

## Download + import pipeline
- Use `dio` (or `http` + streams) to download EPUB to app docs:
  - Path: `${appDir}/downloads/{sanitizedTitle}-{iaId}.epub`.
- On completion:
  - `openEpub(path: ...)` -> `BookService.saveBook(...)`.
  - Navigate to library or detail screen.
- Track progress per item in UI (simple map state keyed by iaId).

## Edge cases
- ebook_access not public => hide download CTA.
- missing cover_i => render stylized placeholder.
- missing ia => skip result entirely.
- download failure => retry + remove partial file.
- EPUB parse error => show error and allow deletion.

## Performance
- Debounce search input (300-500ms).
- Limit fields in API query (already minimal).
- Optionally parse JSON off the main isolate if list gets large.

## Suggested file touches
- `lib/services/open_library_service.dart` (new)
- `lib/core/providers.dart` (new providers)
- `lib/screens/create_screen.dart` (Discover UI)
- `lib/widgets/book_card.dart` (optional variant)
- `lib/widgets/shared/state_scaffolds.dart` (new error/empty states if needed)

## Incremental rollout
1) Service + model + provider with console tests.
2) Basic Discover tab + results list.
3) Download + import integration.
4) Preview sheet + polish.
5) Cache + refinements.

