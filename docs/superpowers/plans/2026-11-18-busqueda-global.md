# Búsqueda global en la biblioteca Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Searching from the Library finds titles and authors, text inside every document, and notes and highlights. Tapping a content result opens the reader at that match with its own search already active.

**Architecture:**
- **Index.** A separate SQLite FTS5 database (`SearchIndexStore`, an actor) holds one row per chunk of document text.
- **Chunking.** `ContentChunker` produces chunks per format.
- **Indexing.** `SearchIndexingService` indexes after import, backfills `pending`/`failed` documents at launch, removes chunks on delete and keeps `indexingStatus` up to date.
- **Search.** `GlobalSearchService` merges three sources: the title/author filter, FTS hits grouped per document, and notes/highlights queried in SwiftData.
- **Library UI.** The Library's existing `.searchable` shows the grouped results.
- **Opening a result.** The readers accept an `initialSearch` (query + scope). They run their existing in-document search and land on the first match inside that page, chapter or block.

**Tech Stack:**
- Swift 6 (strict concurrency), SwiftUI, SwiftData
- `SQLite3` (SDK), PDFKit, Readium (`publication.content()`)
- Swift Testing, run on device

**Spec:** `docs/superpowers/specs/2026-11-18-busqueda-global-pptx-estadisticas-design.md` §4.3 (and §2, §3, §8)

**Product change since the spec:** PowerPoint files are now converted to PDF and opened in `PDFReaderView` through `PresentationOpenerView` (merged in PR #2). The presentation-specific search and its speaker-notes panel were removed at the user's request. Therefore:
- PPTX chunks come from the rendered PDF when it exists, else from `PPTXParser.visibleSlides`. The text is title + body only, because the PDF reader cannot show speaker notes.
- `locator` is the slide index, which equals the PDF page index.
- Opening a PPTX hit goes through `PresentationOpenerView`. It already shows "Convirtiendo la presentación a PDF…" and falls back to QuickLook.

## Global Constraints

- iOS 18+, Swift 6 strict concurrency. No third-party dependencies: `SQLite3` and Apple frameworks only.
- The index lives at `Application Support/SearchIndex.sqlite`. It is rebuildable from files at any time. If the database is corrupt, delete it and mark every publication `pending`.
- FTS5 table: `CREATE VIRTUAL TABLE chunks USING fts5(publication_id UNINDEXED, locator UNINDEXED, label UNINDEXED, text, tokenize='unicode61 remove_diacritics 2');`
- Chunks are about 4,000 characters. Results show at most 5 fragments per document. Snippets come from FTS5 `snippet()` with about 12 words of context.
- User queries are escaped: each word is wrapped in double quotes (inner `"` doubled), and the last word gets a prefix `*`. FTS5 operators typed by the user (`*`, `"`, `-`, `OR`, `NEAR`, `(`, `:`) can never produce a syntax error.
- Indexing never blocks import or the UI. "¡Documento importado!" appears exactly as today.
- Archived (Free plan) documents are indexed and listed. Tapping one shows the existing archived alert.
- UI copy is in Spanish via `String(localized:)`. Use the design system with light, dark and sepia themes.
- Device-only testing: `-only-testing:LectoriaTests/<Suite>`.

## Review Focus

1. **Typing fast in the Library search field** (each keystroke restarts the search). Only the latest query's results may appear; stale results must never overwrite newer ones. There is a 300 ms debounce, and the previous task is cancelled.
2. **A document deleted while it is being indexed.** No chunks for it may remain in the index, and no crash may occur when its status is updated.
3. **Query of only punctuation or FTS syntax** (`"`, `*`, `-`, `NEAR(`, `a OR`). The result is empty or valid, never an SQLite error shown to the user.
4. **A hit whose chunk location no longer contains the word** (for example, a PDF page text extracted differently). The reader falls back to the first match in the whole document. It never opens with an empty "0 de 0" bar.
5. **App killed mid-indexing.** The document stays `indexing` forever unless the launch backfill also picks up `indexing`. Treat `indexing` found at launch as `pending`.

Tests pin:
- 3 and the escaping in Task 1;
- 2 and 5 in Task 2;
- 1 in Task 3 (the service-level "latest wins");
- 4 in Task 4 (the scope-fallback helper).

---

### Task 1: `SearchIndexStore` (SQLite FTS5)

**Files:**
- Create: `Lectoria/Services/Search/SearchIndexStore.swift`
- Create: `Lectoria/Services/Search/SearchQuery.swift`
- Test: `LectoriaTests/SearchIndexStoreTests.swift`

**Interfaces:**
- Produces:
  - `struct IndexChunk: Sendable, Equatable { let locator: String; let label: String; let text: String }`
  - `struct ContentHit: Sendable, Equatable { let publicationID: UUID; let locator: String; let label: String; let snippet: String }`. In the snippet, the match is wrapped in `[[` `]]` (the FTS5 `snippet()` markers).
  - `struct DocumentHits: Sendable, Equatable { let publicationID: UUID; let totalMatches: Int; let hits: [ContentHit] }`. `hits` holds at most 5, in document order of rowid.
  - `actor SearchIndexStore`, with:
    - `init(url: URL) throws`: opens or creates the database. If opening or creating the table fails, it deletes the file and retries once.
    - `func replace(publicationID: UUID, chunks: [IndexChunk]) throws`: deletes the old rows and inserts the new ones in one transaction.
    - `func delete(publicationID: UUID) throws`
    - `func search(_ query: String, limitDocuments: Int = 50) throws -> [DocumentHits]`. Documents are ordered by bm25 of their best chunk. `totalMatches` is the number of matching chunks.
    - `func indexedPublicationIDs() throws -> Set<UUID>`
    - `static func defaultURL() -> URL`: `Application Support/SearchIndex.sqlite`.
  - `enum SearchQuery { static func ftsExpression(for userQuery: String) -> String? }`. Returns `nil` when no word characters remain.

- [ ] **Step 1: Write failing tests** in `@MainActor struct SearchIndexStoreTests`. Each test uses a store at a temp URL.
  - `testFTSExpressionQuotesWordsAndPrefixesLast`:
    - `ftsExpression("hola mundo") == "\"hola\" \"mundo\"*"`
    - `ftsExpression("  ") == nil`
    - `ftsExpression("a\"b") == "\"a\"\"b\"*"`
    - `ftsExpression("*-()") == nil` (the expression keeps letters and digits only; a word with neither is dropped)
  - `testSearchIgnoresCaseAndAccents`: insert a chunk with "La CANCIÓN del pirata". Searching "cancion" gives 1 document, and its snippet contains `[[CANCIÓN]]`.
  - `testPrefixMatchesLastWord`: searching "pira" matches "pirata".
  - `testReplaceSwapsChunksAndDeleteRemoves`: after `replace` with new text, the old word is not found. After `delete`, nothing is found and `indexedPublicationIDs()` is empty.
  - `testAtMostFiveHitsPerDocumentWithTotalCount`: 8 chunks contain "faro", so `hits.count == 5` and `totalMatches == 8`.
  - `testHostileQueriesNeverThrow`: for each of `["\"", "*", "-", "NEAR(", "a OR", "(", "col:x", "🙂"]`, `try store.search(q)` does not throw.
  - `testCorruptDatabaseIsRecreated`: write `Data("garbage".utf8)` to the URL. `SearchIndexStore(url:)` succeeds and `search("x")` returns `[]`.
- [ ] **Step 2: Run, expect FAIL** (types are undefined).
- [ ] **Step 3: Implement.**
  - Use the `sqlite3_*` C API with `SQLITE_TRANSIENT`, prepared statements and bound parameters. Never interpolate user text.
  - Search SQL:
    ```sql
    SELECT publication_id, locator, label,
           snippet(chunks, 3, '[[', ']]', '…', 12),
           bm25(chunks)
    FROM chunks
    WHERE chunks MATCH ?
    ORDER BY bm25(chunks)
    LIMIT 2000
    ```
  - Group in Swift: keep each document's first 5 hits in rowid order (also select `rowid`), count all of its rows, and order documents by best bm25. If `ftsExpression` returns `nil`, return `[]`.
  - Any SQLite error from `MATCH` maps to an empty result and is logged; nothing is thrown to the UI.
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit.** `feat(search): SQLite FTS5 index store for library search`

### Task 2: Chunking and the indexing lifecycle

**Files:**
- Create: `Lectoria/Services/Search/ContentChunker.swift`
- Create: `Lectoria/Services/Search/SearchIndexingService.swift`
- Create: `LectoriaTests/Fixtures/mini.epub`. A minimal valid EPUB 3 (2 chapters, titled in the nav "Capítulo uno" and "Capítulo dos", containing the words "ballena" and "faro"), built by a zip script in the scratchpad.
- Modify:
  - `Lectoria/App/AppDependencies.swift`: add `searchIndexingService`; pass it to `ImportService`.
  - `Lectoria/Services/Import/ImportService.swift`: an optional `searchIndexer` init param. After save, a fire-and-forget `Task { await indexer.index(publicationID:) }` for every format.
  - `Lectoria/DesignSystem/Components/PublicationCard.swift` and `Lectoria/Features/Home/HomeView.swift`: after `publicationRepository.delete(id:)`, call `searchIndexingService.remove(publicationID:)`.
  - `Lectoria/App/RootView.swift` (or the app's existing launch `.task`): call `searchIndexingService.backfill()` at low priority.
- Test: `LectoriaTests/ContentChunkerTests.swift` and `LectoriaTests/SearchIndexingServiceTests.swift`

**Interfaces:**
- Consumes (from Task 1): `SearchIndexStore`, `IndexChunk`.
- Produces:
  - `enum ContentChunker`, with:
    - `static let chunkSize = 4000`
    - `static func chunks(for record: PublicationRecord, fileURL: URL) async throws -> [IndexChunk]`
    - `static func split(_ text: String, locator: String, label: String) -> [IndexChunk]`: splits on whitespace near `chunkSize`; empty input gives `[]`.
  - Per format:
    - **PDF:** one chunk per page; `locator` = `"\(pageIndex)"`; `label` = `"Página \(pageIndex + 1)"`.
    - **TXT / Markdown / pasted text:** open `TextReaderAdapter` for the record and group blocks into about 4,000 characters; `locator` = the first block index; `label` = `"Párrafo \(firstBlock + 1)"`.
    - **EPUB:** open through `EPUBReaderAdapter` and iterate `publication.content()`, collecting text per `locator.href`. `label` = the TOC title for that href (match ignoring the fragment), else `"Capítulo \(n)"`; `locator` = href string. Long chapters go through `split`.
    - **PPTX:** if the rendered PDF is valid, run the PDF path on it with labels `"Diapositiva \(i + 1)"`. Otherwise use `PPTXParser.visibleSlides`, with title and body joined; `locator` = `"\(i)"`; `label` = `"Diapositiva \(i + 1)"`.
  - `@MainActor final class SearchIndexingService`, with:
    - `init(store: SearchIndexStore?, publications: any PublicationRepository, chunker: @escaping (PublicationRecord) async throws -> [IndexChunk] = <default resolving the Publications path and calling ContentChunker>)`
    - `func index(publicationID: UUID) async`: sets `indexing`, chunks, replaces in the store, then `completed`, or `failed` on error. It does nothing if the publication no longer exists. If the publication was deleted while chunking, it calls `store.delete` instead of writing.
    - `func remove(publicationID: UUID) async`
    - `func backfill() async`: indexes in sequence every publication whose status is `pending`, `failed` or `indexing` (Review Focus 5).
    - `var pendingCount: Int`: observable; publications not `completed`.

- [ ] **Step 1: Write failing tests.**
  - `ContentChunkerTests`:
    - `testSplitKeepsWordsAndSize`: 10,000 characters of words give 3 chunks, each ≤ 4000 + one word, with no word cut and all of them sharing the same locator and label.
    - `testPDFOneChunkPerPage`: use `PresentationRenderingTests.makePDF(pages: ["uno", "dos"])` written to a temp file. Expect 2 chunks with labels "Página 1" and "Página 2" and locators "0" and "1".
    - `testTextChunksFromBlocks`: write a `.txt` with 3 paragraphs to `Publications/` under a unique name. The chunks contain all three paragraphs, and the first `locator == "0"`.
    - `testEPUBChunksPerChapterWithTOCLabels`: copy `mini.epub` to `Publications/`. Expect labels `["Capítulo uno", "Capítulo dos"]`, and the second chunk's text contains "faro".
    - `testPPTXWithoutRenderedPDFUsesSlides`: use `three-slides-one-hidden.pptx`. Expect 2 chunks, labels "Diapositiva 1" and "Diapositiva 2", and the first text contains "presupuesto".
    - Clean up all files written to `Publications/` with `defer`.
  - `SearchIndexingServiceTests`:
    - Use an in-memory `ModelContainerFactory` repository, a temp store and a fake chunker.
    - `testIndexMarksCompletedAndIsSearchable`
    - `testIndexFailureMarksFailed`
    - `testDeletedDuringIndexingLeavesNoChunks`: the fake chunker deletes the record from the repository, then returns chunks. Afterwards `store.indexedPublicationIDs()` is empty and nothing crashes.
    - `testBackfillPicksPendingFailedAndStuckIndexing`: three records are `pending`, `failed` and `indexing`, plus one `completed`. The chunker is called 3 times.
    - `testRemoveDeletesChunks`
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** `ContentChunker`, `SearchIndexingService`, the fixture, and the wiring: import hook, delete hooks, launch backfill. `AppDependencies` creates the store with `try? SearchIndexStore(url: .defaultURL())`; if it is `nil`, the service no-ops and search shows only titles and notes.
- [ ] **Step 4: Run both suites, expect PASS. Then run the full suite.**
- [ ] **Step 5: Commit.** `feat(search): chunk documents and keep the search index up to date`

### Task 3: Library search results

**Files:**
- Create: `Lectoria/Services/Search/GlobalSearchService.swift`
- Create: `Lectoria/Features/Library/LibrarySearchResultsView.swift`
- Modify: `Lectoria/Features/Library/LibraryView.swift`. When `searchText` is non-empty, show `LibrarySearchResultsView` instead of the grid or list. Results come from a debounced `.task(id: searchText)` (300 ms sleep; cancellation is automatic with `task(id:)`).
- Test: `LectoriaTests/GlobalSearchServiceTests.swift`

**Interfaces:**
- Consumes: `SearchIndexStore.search`, `DocumentHits`, `SearchIndexingService.pendingCount`.
- Produces:
  - `struct GlobalSearchResults: Sendable, Equatable`, with:
    - `var titleMatches: [UUID]`
    - `var documents: [DocumentHits]`
    - `var annotations: [AnnotationHit]`
    - `var isEmpty: Bool`
  - `struct AnnotationHit: Sendable, Equatable, Identifiable`, with:
    - `let id: UUID`
    - `let publicationID: UUID`
    - `let kind: Kind` (`enum Kind { case note, highlight }`)
    - `let text: String`
    - `let anchor: String?`
  - `@MainActor final class GlobalSearchService`, with:
    - `init(store: SearchIndexStore?, container: ModelContainer)`
    - `func search(_ query: String, publications: [PublicationRecord]) async -> GlobalSearchResults`
  - Behaviour:
    - **Title matches:** title or author with `localizedStandardContains`, which matches today's filter but also ignores accents.
    - **Content:** documents for publications that no longer exist are dropped.
    - **Annotations:** a SwiftData fetch of `NoteModel` (body, or any tag) and `HighlightModel` (`selectedText`) with `localizedStandardContains`, at most 30 each. Sorted by `updatedAt` descending.
  - `struct ContentSearchTarget: Hashable` (`publication: PublicationRecord`, `query: String`, `scope: String`). `LibraryView` sets it to open a reader at a hit (Task 4 consumes it).

- [ ] **Step 1: Write failing tests** in `GlobalSearchServiceTests` (in-memory container, temp store):
  - `testFindsTitlesContentAndNotes`: one publication "Moby Dick" by "Melville", with chunk text "la ballena blanca", a note body "ballena favorita" and a highlight "una ballena". `search("ballena")` gives:
    - `titleMatches == []`
    - one document with 1 hit
    - 2 annotations
    - `search("melville").titleMatches == [id]`
  - `testIgnoresAccentsInTitlesAndNotes`: the title "Canción de hielo", searched as "cancion", matches.
  - `testDropsHitsOfDeletedPublications`: the publication is absent from the `publications:` argument, so `documents == []`.
  - `testEmptyQueryReturnsEmpty`
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement the service and the results view.**
  - Sections:
    - **"Títulos y autores":** `PublicationCard` in `.list` style, tap behaviour as today.
    - **"Dentro de documentos":** a row per document (icon from `publicationType.systemImage`, title, "N coincidencias") followed by up to 5 hit rows (label · snippet). In the snippet, the text between `[[ ]]` is rendered in bold via `AttributedString`.
    - **"Notas y destacados":** an icon for note or highlight, the text (2 lines) and the document title.
  - Footer when `pendingCount > 0`: "Indexando N documentos… algunos resultados pueden faltar".
  - Empty state: the existing "No hay resultados" view.
  - Tapping a hit in an archived publication shows the existing archived alert.
- [ ] **Step 4: Run, expect PASS. Then run the full suite.**
- [ ] **Step 5: Commit.** `feat(search): grouped library search across titles, content and notes`

### Task 4: Open a result at its match

**Files:**
- Create: `Lectoria/Features/Reader/InitialSearch.swift`
- Modify:
  - `Lectoria/Features/Reader/PDFReaderView.swift`
  - `Lectoria/Features/Reader/EPUBReaderView.swift`
  - `Lectoria/Features/Reader/TextReaderView.swift`
  - `Lectoria/Features/Reader/PresentationOpenerView.swift`
  - `Lectoria/Features/Library/LibraryView.swift`
- Test: `LectoriaTests/InitialSearchTests.swift`

**Interfaces:**
- Consumes: `ContentSearchTarget`, `AnnotationHit` (Task 3).
- Produces:
  - `struct InitialSearch: Equatable, Sendable { let query: String; let scope: String? }`
  - `enum InitialSearchResolver { static func firstMatchIndex<T>(in matches: [T], scope: String?, scopeOf: (T) -> String) -> Int? }`. Returns the first index whose `scopeOf == scope`, else 0 if the array is non-empty, else `nil` (Review Focus 4).
  - New reader init params, each defaulting to `nil`:
    - `PDFReaderView(record:initialLocation:initialSearch:)`
    - `EPUBReaderView(record:initialSearch:initialLocation:)`
    - `TextReaderView(record:initialLocation:initialSearch:)`
    - `PresentationOpenerView(record:initialPDFLocation:initialSearch:)`, which passes `initialSearch` through to `PDFReaderView`.
  - Reader behaviour once the document has loaded, when `initialSearch != nil`:
    - Set `searchQuery`, run the existing search, then `selectSearchMatch(at: resolver result)`.
    - Scope keys:
      - **PDF:** `"\(pageIndex)"`.
      - **EPUB:** the match's `chapterKey` (href), compared without the fragment.
      - **Text:** the first result whose block index is at or after `Int(scope)`. Text has no navigator bar: jump to that result's location, as tapping a result does today.
    - If there are no matches at all, open normally with the search sheet showing "No se encontraron resultados." (no empty bar).
  - Annotation taps from the Library open the document at its anchor:
    - **PDF / PPTX:** `PDFLocation`.
    - **Text:** `TextLocation`.
    - **EPUB:** a new `initialLocation: EPUBLocation?` param, decoded from the anchor. It takes precedence over saved progress.
    - Otherwise the document opens at its saved progress.

- [ ] **Step 1: Write failing tests** in `InitialSearchTests`:
  - `testResolverPrefersScope`: for scopes `["0", "2", "2", "5"]` and scope `"2"`, the result is 1.
  - `testResolverFallsBackToFirst`: scope `"9"` gives 0.
  - `testResolverEmptyIsNil`: `[]` gives `nil`.
  - `testHrefScopeIgnoresFragment`: `InitialSearchResolver.normalizedHref("ch2.xhtml#p3") == "ch2.xhtml"`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** the resolver, the reader params and behaviour, the EPUB `initialLocation` param, and the `LibraryView` navigation:
  - `.navigationDestination(item: $contentTarget)` routes by type with `initialSearch`.
  - Annotation taps reuse `router.selectedPublication` plus the decoded locations.
- [ ] **Step 4: Run the full suite. Expect PASS.**
- [ ] **Step 5: Install on the iPhone and commit.** `feat(search): open library search results at the matching location`
