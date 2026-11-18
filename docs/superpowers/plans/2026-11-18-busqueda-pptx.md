# Búsqueda en PowerPoint (PPTX → PDF) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert imported PPTX files to a write-once PDF with WebKit and give presentations the same in-document search as PDFs (results list, jump, highlighting, "N de M" bar), plus speaker-notes matches.

**Architecture:** A `@MainActor` `PresentationPDFConverter` loads the `.pptx` into an off-screen `WKWebView` that lives in a hidden `UIWindow` attached to the active scene. It waits until the `div.slide` count equals the `PPTXParser` slide count, prints each slide rect with `webView.pdf(configuration:)`, and merges the pages into `Publications/<localFileName>.rendered.pdf`. A `PresentationRenderingService` (in `AppDependencies`) decides when to convert: after import, or when a presentation without a PDF is opened. It allows one attempt per publication per app session. `PresentationReaderView` uses its existing PDF route whenever a valid rendered PDF exists. That route gains progress saving and resume, plus a search sheet that reuses `PDFTextSearch` and `ReaderSearchNavigatorBar`.

**Tech Stack:**
- Swift 6 (strict concurrency), SwiftUI
- WebKit (`WKWebView.pdf(configuration:)`), PDFKit
- Swift Testing, run on device

**Spec:** `docs/superpowers/specs/2026-11-18-busqueda-global-pptx-estadisticas-design.md` §4.2 (and §2, §3, §8)

## Global Constraints

- iOS 18+, Swift 6 strict concurrency. No new third-party dependencies.
- Imported files live in `Application Support/Publications/<localFileName>`. The converted file is `<localFileName>.rendered.pdf`, next to the original. The original is never deleted.
- **Write-once.** A `.rendered.pdf` that `PDFDocument` can open with `pageCount > 0` is never regenerated. It is regenerated only when it is missing or cannot be opened.
- **On failure** (timeout ≈30 s, slide count mismatch, empty PDF): write nothing, log with `os.Logger`, and keep using QuickLook. Retry on the next open, at most once per app session.
- Importing must not get slower: conversion runs after the record is saved, in the background, and never delays "¡Documento importado!".
- An already-open presentation never switches view mid-reading. The PDF route is used from the **next** open.
- UI copy in Spanish via `String(localized:)`. Use the design system (`AppColor`, `AppTypography`, `AppSpacing`, `AppRadius`) with light, dark and sepia themes.
- Device-only testing. Use the commands in the project memory, and `-only-testing:LectoriaTests/<Suite>`.

## Review Focus

1. **User closes the presentation while conversion runs.** The conversion must finish (or time out) on its own and write a complete file or nothing. It must never leave a partial `.rendered.pdf` that would then be treated as valid and frozen.
2. **Two triggers at once.** The user opens a PPTX right after importing it, so import and open both ask to convert the same publication. Only one conversion may run and only one file is written.
3. **Legacy `.ppt` / `.key` / `.odp` files** (also `PublicationType.pptx`). They must keep opening with QuickLook exactly as today: no conversion attempt and no error shown.
4. **Resume index out of range.** Saved progress points to slide 12, but the rendered PDF has 10 pages (it was regenerated after corruption). The reader must clamp to the last slide, not crash.
5. **App backgrounded during conversion.** The hidden window/webview may stop painting. The conversion must time out cleanly (no file written) and be retried on the next app session.

Tests pin 1 (atomic write, Task 1), 2 (single in-flight, Task 2), 3 (extension gate, Task 2) and 4 (clamp, Task 2). Item 5 is covered by the timeout path test in Task 1 plus manual verification.

---

### Task 1: Rendered-PDF storage and WebKit converter

**Files:**
- Create: `Lectoria/Services/Presentation/RenderedPresentationStore.swift`
- Create: `Lectoria/Services/Presentation/PresentationPDFConverter.swift`
- Test: `LectoriaTests/PresentationRenderingTests.swift`

**Interfaces:**
- Produces:
  - `enum RenderedPresentationStore`, with:
    - `static func renderedURL(forLocalFileName: String, in directory: URL) -> URL`: `directory/<name>.rendered.pdf`.
    - `static func publicationsDirectory() -> URL?`: `Application Support/Publications`.
    - `static func validDocument(at url: URL) -> PDFDocument?`: returns `nil` if the file is missing, unreadable or has 0 pages.
    - `static func isConvertible(localFileName: String) -> Bool`: true only for the `pptx` extension, case-insensitive.
  - `@MainActor final class PresentationPDFConverter`, with:
    - `init(timeout: Duration = .seconds(30))`
    - `func convert(pptxURL: URL, expectedSlideCount: Int, destination: URL) async throws`
  - `enum PresentationConversionError: Error { case loadFailed, timedOut, slideCountMismatch(found: Int, expected: Int), emptyOutput, noWindowScene }`

- [ ] **Step 1: Write failing tests (store).** Add a `@MainActor struct PresentationRenderingTests` with:
  - `testRenderedURLAppendsSuffix`: `renderedURL(forLocalFileName: "ABC.pptx", in: URL(fileURLWithPath: "/x"))`, then `.path == "/x/ABC.pptx.rendered.pdf"`.
  - `testValidDocumentRejectsMissingAndGarbage`: a missing path gives `nil`; a file containing `Data("not a pdf".utf8)` gives `nil`.
  - `testValidDocumentAcceptsOnePagePDF`: write a one-page PDF made with `UIGraphicsPDFRenderer`; the result has `pageCount == 1`.
  - `testIsConvertibleOnlyPPTX`: `"a.pptx"` and `"A.PPTX"` are true; `"a.ppt"`, `"a.key"`, `"a.odp"` and `"a.pdf"` are false.
- [ ] **Step 2: Run, expect FAIL.** `-only-testing:LectoriaTests/PresentationRenderingTests`. Expected: the build fails because `RenderedPresentationStore` is undefined.
- [ ] **Step 3: Implement `RenderedPresentationStore`** as specified above.
- [ ] **Step 4: Run, expect PASS** (4 tests).
- [ ] **Step 5: Write failing tests (converter, integration on device).** The fixture comes from `SamplePPTXGenerator.createSamplePPTXData()`, written to a temp `.pptx`. `expected` is `PPTXParser.parse(url:).count`.
  - `testConvertWritesOnePagePerSlideWithSearchableText`: after `convert`, `validDocument(at: destination)?.pageCount == expected`. The document's `string` contains the first slide's `title`, compared case- and diacritic-insensitively.
  - `testConvertSlideCountMismatchWritesNothing`: use `PresentationPDFConverter(timeout: .seconds(5))` with `expectedSlideCount: expected + 3`. It throws, and `FileManager.default.fileExists(atPath: destination.path) == false`. This pins Review Focus 1 and 5: no partial file.
- [ ] **Step 6: Run, expect FAIL** (`PresentationPDFConverter` undefined).
- [ ] **Step 7: Implement `PresentationPDFConverter`.** It follows the spike's algorithm:
  1. Create a 1280×720 `WKWebView` inside a `UIWindow(windowScene:)` built from the first connected `UIWindowScene`. Throw `.noWindowScene` if there is none. Set `isHidden = false`, `alpha = 0.01` and `windowLevel = .normal - 1` so the user never sees it.
  2. `loadFileURL(pptxURL, allowingReadAccessTo: pptxURL.deletingLastPathComponent())` and await `didFinish` through a navigation delegate and continuation. Any fail callback throws `.loadFailed`.
  3. Poll every 0.5 s until the deadline. Read `document.querySelectorAll('div.slide').length`. While it is below `expectedSlideCount`, scroll `.loading-slide` (or the last `div.slide`) into view. Once it equals the expected count, wait 1 s to stabilize and continue. On deadline: throw `.timedOut` if fewer slides loaded, `.slideCountMismatch` if more.
  4. Scroll to the top, read the page-absolute rects of every `div.slide` as JSON, and for each one call `webView.pdf(configuration:)` with `rect` set to that rect. Insert page 0 of each result into one `PDFDocument`.
  5. If the page count is 0, or differs from expected, throw (`.emptyOutput` / `.slideCountMismatch`).
  6. Write to `destination` + `.partial`, then `FileManager.replaceItemAt` or `moveItem` it to `destination`. This is an atomic write, so a crash or kill never leaves a half file.
  7. Always remove the webview from its window and hide the window, using `defer`.

  The window must not interfere with the app's key window: never call `makeKeyAndVisible`.
- [ ] **Step 8: Run, expect PASS** (6 tests in the suite).

  If WebKit does not lay out `SamplePPTXGenerator`'s minimal file as `div.slide`, the integration test fails for a fixture reason, not a code reason. In that case add a tiny real `.pptx` (made by `python-pptx` in the scratchpad, 2 slides, with titles) under `LectoriaTests/Fixtures/`, load it via `Bundle(for:)`, and ledger a ruling.
- [ ] **Step 9: Commit.** `feat(pptx): convert PowerPoint to write-once searchable PDF with WebKit`

### Task 2: When to convert, and using the rendered PDF in the reader (with progress)

**Files:**
- Create: `Lectoria/Services/Presentation/PresentationRenderingService.swift`
- Create: `Lectoria/Features/Reader/PresentationProgress.swift`
- Modify:
  - `Lectoria/App/AppDependencies.swift`: add `presentationRenderingService`, and pass it to `ImportService`.
  - `Lectoria/Services/Import/ImportService.swift`: add an optional `presentationRenderer` init param. After `publicationRepository.save(record)`, if `RenderedPresentationStore.isConvertible(localFileName:)`, fire and forget `Task { @MainActor in await renderer.ensureRendered(...) }`.
  - `Lectoria/Features/Reader/PresentationReaderView.swift`: choose the route, load the rendered PDF, save and resume progress, pass a `progressProvider`.
- Test: `LectoriaTests/PresentationRenderingTests.swift` (extend), and `LectoriaTests/DesignSystemTests/ImportServiceTests.swift` (extend).

**Interfaces:**
- Consumes (from Task 1): `RenderedPresentationStore.*`, `PresentationPDFConverter.convert(...)`.
- Produces:
  - `protocol PresentationRendering: AnyObject, Sendable`, with `@MainActor func ensureRendered(localFileName: String, publicationID: UUID) async`
  - `@MainActor final class PresentationRenderingService: PresentationRendering`, with:
    - `init(directory: @escaping () -> URL? = RenderedPresentationStore.publicationsDirectory, convert: @escaping @MainActor (URL, Int, URL) async throws -> Void = { try await PresentationPDFConverter().convert(pptxURL: $0, expectedSlideCount: $1, destination: $2) }, slideCount: @escaping (URL) async throws -> Int = { try await PPTXParser.parse(url: $0).count })`
    - `private(set) var attempted: Set<UUID>` and `private(set) var inFlight: Set<UUID>`
  - `enum PresentationProgress`, with:
    - `static func percentage(slideIndex: Int, totalSlides: Int) -> Double`: `slideIndex / max(1, total-1)`, clamped to 0…1.
    - `static func resumeIndex(savedPageNumber: Int?, totalSlides: Int) -> Int`: `(page-1)` clamped to `0...max(0,total-1)`; `nil` gives 0.

- [ ] **Step 1: Write failing tests.** In `PresentationRenderingTests`, use a fake `convert` closure that counts calls and writes a one-page PDF, plus a temp directory:
  - `testEnsureRenderedSkipsWhenValidPDFExists`: a valid rendered file already exists, so the convert count stays 0.
  - `testEnsureRenderedConvertsOncePerSessionOnFailure`: `convert` throws. Calling `ensureRendered` twice gives a call count of 1.
  - `testConcurrentEnsureRenderedRunsOneConversion` (Review Focus 2): start two `ensureRendered` calls together with `async let`, where the fake convert suspends with `Task.sleep(for: .milliseconds(100))`. The call count is 1.
  - `testEnsureRenderedReplacesUnreadableFile`: a garbage `.rendered.pdf` exists, so the convert count becomes 1.
  - `testEnsureRenderedIgnoresLegacyFormats` (Review Focus 3): with `"x.ppt"` the convert count is 0.
  - `testResumeIndexClamps` (Review Focus 4):
    - `resumeIndex(savedPageNumber: 12, totalSlides: 10) == 9`
    - `resumeIndex(nil, 10) == 0`
    - `resumeIndex(0, 10) == 0`
    - `resumeIndex(3, 0) == 0`
  - `testPercentage`:
    - `percentage(0, 1) == 0`
    - `percentage(4, 5) == 1`
    - `percentage(2, 5) == 0.5`

  In `ImportServiceTests`:
  - `testImportPPTXRequestsRendering`: import a `.pptx` from `SamplePPTXGenerator` with a spy `PresentationRendering`. After a short yield, the spy received the record's `localFileName`.
  - `testImportEPUBDoesNotRequestRendering`: using an existing EPUB/TXT fixture from that suite, the spy is not called.
- [ ] **Step 2: Run both suites, expect FAIL** (undefined types / init param).
- [ ] **Step 3: Implement `PresentationProgress`, `PresentationRenderingService`, and the `ImportService` hook.**
  - `ensureRendered` returns early in any of these cases:
    - the file is not convertible;
    - a valid PDF already exists;
    - the id is in `inFlight` or `attempted`.
  - Otherwise it inserts the id into both sets, gets the slide count, and converts. It always removes the id from `inFlight` with `defer`. Errors are logged with `os.Logger` (category `"PresentationRendering"`) and swallowed.
  - Wire it in `AppDependencies`.
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Reader integration (`PresentationReaderView`).**
  - Route: in `init`, compute `usesPDFRoute` once and keep it in `@State` via `State(initialValue:)`. It is true when `localFileName` ends in `.pdf`, or when the rendered file exists (a cheap existence check; validity is checked in step b). `body` switches on it. The route never changes while the view is open.
  - b. `resolveAndPrepareFile()`:
    - `fileURL` stays the **original** file, so Share exports the original.
    - If the record is not a PDF, `pdfDocument = RenderedPresentationStore.validDocument(at: renderedURL)`. When that is `nil`, the existing "Ruta B" QuickLook branch shows.
    - Then, whenever `pdfDocument == nil` and the file is convertible, call `Task { await dependencies.presentationRenderingService.ensureRendered(...) }` with no view change.
  - Progress, PDF route only (`pdfDocument != nil`):
    - after load, read `readingProgressRepository.fetchProgress` and set `currentSlideIndex = PresentationProgress.resumeIndex(...)` **before** `startSession()`;
    - on `onChange(of: currentSlideIndex)`, save a `ReadingProgress` with `locatorJSON` `{"slideIndex":N}`, `percentage` from `PresentationProgress.percentage`, `pageNumber` N+1 and `chapterTitle` "Diapositiva N+1". Copy `deviceID`/`version` from `PDFReaderView.saveReadingProgress`.
  - Pass `progressProvider: { pdfDocument == nil ? nil : PresentationProgress.percentage(slideIndex: currentSlideIndex, totalSlides: totalSlides) }` to the `ReadingSessionCoordinator`.
- [ ] **Step 6: Build and run the full unit suite**, `-only-testing:LectoriaTests`. Expected: all pass.
- [ ] **Step 7: Commit.** `feat(pptx): convert after import or on first open and read presentations from the rendered PDF`

### Task 3: Search inside presentations (slides + speaker notes)

**Files:**
- Modify:
  - `Lectoria/Features/Reader/PDFPresentationPreviewWrapper.swift`: add `searchMatches: [PDFSearchMatch] = []` and `activeSearchIndex: Int? = nil`. `updateUIView` applies `PDFTextSearch.applyHighlights` only when the match ids or the active index changed (track the last applied signature in the coordinator), and `PDFTextSearch.clearHighlights` when the matches are empty.
  - `Lectoria/ReaderCore/Engines/Presentation/PresentationSearchEngine.swift`: make matching case- **and diacritic**-insensitive (`range(of:options: [.caseInsensitive, .diacriticInsensitive])`), for both the match test and the snippet.
  - `Lectoria/Features/Reader/PresentationReaderView.swift`: search button, sheet, navigator bar, and speaker-notes section.
  - `Lectoria/Features/Reader/PDFTextSearch.swift`: add `static func pageTitlePrefix` support, or a `pageTitle` override (see Step 3).
- Test: `LectoriaTests/PresentationSearchTests.swift` (extend)

**Interfaces:**
- Consumes:
  - `PDFTextSearch.search/applyHighlights/pageCount` (existing)
  - `ReaderSearchNavigatorBar` (existing)
  - `PresentationSearchEngine` (existing)
  - `PPTXParser.parse(url:)` (existing; `PPTXSlide.speakerNotes`)
- Produces:
  - `PDFTextSearch.search(_ query: String, in document: PDFDocument, pageLabel: (Int) -> String = default) -> [PDFSearchMatch]`. The default keeps today's "Página N". Presentations pass `{ "Diapositiva \($0 + 1)" }`.
  - `static func slideSummary(matchCount: Int, slideCount: Int) -> String` on a new `enum PresentationSearchText`. It returns "1 coincidencia en 1 diapositiva" or "N coincidencias en M diapositivas".

- [ ] **Step 1: Write failing tests** in `PresentationSearchTests`:
  - `testSearchEngineIgnoresAccents`: slide text "Análisis del presupuesto" with query "analisis" gives 1 result. Notes "REVISIÓN final" with query "revision" gives 1 presenter-note result.
  - `testPDFSearchUsesCustomPageLabel`: for a 2-page PDF made with `UIGraphicsPDFRenderer` and drawn text "hola" on page 2, `PDFTextSearch.search("hola", in: doc, pageLabel: { "Diapositiva \($0 + 1)" }).first?.pageTitle == "Diapositiva 2"`.
  - `testSlideSummaryPluralization`:
    - `slideSummary(1, 1) == "1 coincidencia en 1 diapositiva"`
    - `slideSummary(5, 3) == "5 coincidencias en 3 diapositivas"`
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** the engine change, the `pageLabel` parameter (the `PDFReaderView` call site stays unchanged through the default), and `PresentationSearchText`.
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: UI in `PresentationReaderView`, PDF route only.** Mirror the `PDFReaderView` search pattern (`PDFReaderView.swift` search sheet and logic):
  - **State:**
    - `showSearch`, `searchQuery`, `searchMatches`, `activeMatchIndex`, `pendingSearchJump`, `isSearching`, `searchTask`;
    - `noteMatches: [PresentationSearchResult]`;
    - `speakerNotes: [Int: String]`, loaded once in the background from `PPTXParser` when the original is `.pptx`.
  - **Top bar:** a magnifying-glass button (same 36 pt circle style), shown only when `pdfDocument != nil`.
  - **Search:** the sheet's search field fires on submit. Cancel the previous `searchTask`, then:
    - `PDFTextSearch.search(query, in: pdfDocument, pageLabel: { "Diapositiva \($0 + 1)" })`;
    - `PresentationSearchEngine(slideTexts: [:], presenterNotes: speakerNotes).search(query:)`, keeping only `isPresenterNote`.
  - **Sheet title:** "Buscar en la presentación".
  - **Sheet body:**
    - the summary from `PresentationSearchText.slideSummary`;
    - the slide results list (as in PDF);
    - then a section "En notas del presentador", with a "Diapositiva N" title and the snippet;
    - "No se encontraron resultados." only when both lists are empty.
  - **Slide result tap:**
    - set `pendingSearchJump`, then close the sheet;
    - on dismiss, set `activeMatchIndex` and `currentSlideIndex = match.pageIndex` (record `lastJumpOriginIndex`);
    - the wrapper highlights through its new params.
  - **Navigator bar:** `ReaderSearchNavigatorBar` floats at the bottom while `activeMatchIndex != nil && !showSearch`. Previous and next wrap around; list reopens the sheet; close clears the search.
  - **Presenter-note tap:** close the sheet, jump to that slide, and show the full note in the existing `inlineResponseBubble`, with title "Notas del presentador", body the note text, and no highlighting.

    Ruling: the spec said "abre el panel de notas existente", but that panel holds the user's own notes, not speaker notes. No speaker-notes panel exists, so the existing inline bubble is the closest existing surface.
  - Clear the highlights and the search when the view disappears.
- [ ] **Step 6: Build and run the full unit suite.** Expected: all pass.
- [ ] **Step 7: Install on the iPhone**, using the install command from the project memory.
- [ ] **Step 8: Commit.** `feat(pptx): search slides and speaker notes in presentations`
