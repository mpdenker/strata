# Strata — Spec (Step 0)

> Working name **Strata**: you scroll *down* through a lesson the way you'd read rock layers, one idea per layer.
> The name lives in one place (`Config/App.xcconfig` → `APP_DISPLAY_NAME`; the app reads it from the bundle), so renaming means changing one line.

Status: **draft for your review. No app code is written yet.**
Spec date: 2026-11-24. Target: iPhone, iOS 17+, SwiftUI, SwiftData, no third-party packages.

---

## 0. Before you read: things I found that you should know

| # | Finding | What I'll do unless you say otherwise |
|---|---|---|
| 1 | **No Imprint screenshots came through** with the brief, and the project folder was empty. | This spec uses only the interaction patterns your brief lists. If you attach the screenshots later, I'll check the flow against them and change nothing visual. |
| 2 | **Xcode isn't installed on this Mac.** Only the Command Line Tools are present (`xcode-select -p` → `/Library/Developer/CommandLineTools`), and Spotlight finds no Xcode.app. Step 0 doesn't need it; Step 1 does. | Before Step 1: install Xcode from the Mac App Store (free), open it once, then run `sudo xcode-select -s /Applications/Xcode.app` (needs your password). |
| 3 | **Conflict inside "Decided":** `onScrollGeometryChange` needs **iOS 18**, but the target is **iOS 17+**. (`scrollTransition` and `scrollPosition(id:)` are iOS 17, so they're fine.) | Keep iOS 17 as the minimum. On iOS 18+ the progress bar uses `onScrollGeometryChange` (smooth, pixel-exact). On iOS 17 it falls back to "which section is at the top" (moves in section-sized steps). Resume works the same on both. If your phone runs iOS 18+, which is likely, you'll only ever see the smooth version. |
| 4 | **Daily goal vs. a finite library.** The goal is "1 lesson a day". With 30 lessons, a perfect streak runs out after 30 days. | As decided: the goal counts lessons, and **retaking a lesson counts**. Your call: should finishing a review session also count toward the goal? (Default: no.) |
| 5 | Running on **your own phone** without paying is possible: Xcode's free "Personal Team" signing works, but the install **expires after 7 days** and you reinstall from Xcode. Local notifications work with free signing. | No action. The $99/yr Developer Program is only needed for TestFlight or the App Store, which are on your ask-first list. |

---

## 0.5 Changes made during Step 1

What changed from this spec while building Step 1, and why:

| Area | Change | Why |
|---|---|---|
| Palette | `inkMuted` light → `#555A68`, `correct` light → `#2A7247` | The contrast tests showed 4.48:1 on paper, just under the 4.5:1 minimum |
| Schema | `Section` is `LessonSection` in Swift | Name clash with SwiftUI's `Section` |
| Schema | New optional section field `computed` ("1,000 × 1.07^40") | Worked math is labeled as calculated instead of needing a citation |
| Schema | Optional `heading` on comparison, timeline, steps and chart | Most of these need a title |
| Schema | Topics may have a `note` (Finance: "Educational, not financial advice.") | Keeps the disclaimer in data, not Swift |
| Schema | Source kinds add `organization` and `standard` | Covers TeleGeography, CERN, RFCs |
| Timeline | Vertical spine, not a horizontal axis | Readable at every Dynamic Type size and on a narrow phone |
| Reveal | "First visible" uses `onGeometryChange` (back-deployed to iOS 16) on all versions | Works for sections taller than the screen; no separate iOS 18 path needed. The progress bar still uses `onScrollGeometryChange` on iOS 18 |
| PSY-1 | Hook is the 1974 paper's 5-second multiplication puzzle. Dropped bat-and-ball, the System 1/2 comparison and confirmation bias | Frederick (2005) and the Gigerenzer review couldn't be retrieved to check, so those claims are out |
| HIS-2 | No Gibbon quote, no 117 CE or 1453 dates | Project Gutenberg was rate-limiting, and the textbook used doesn't state those dates. Britannica blocks automated reads. Second independent source still to add |
| FIN-1 | Money-history timeline replaced by "why not barter?"; rule of 72 and APR vs. effective rate shown as computed math | Investor.gov pages couldn't be retrieved to verify |
| PHI-2 | Seneca's evening review quoted from Stewart's 1900 translation; Enchiridion from Elizabeth Carter's translation | Public-domain texts that could be read and checked word for word |

## 0.6 Website first, iPhone app later (decided 2026-11-24)

You asked to make it a website now and put it in Xcode later. Steps 1–4 now exist as a website in `web/`. The iPhone app code (`App/`, `Packages/LessonKit`) stays as it was and isn't deleted. Both read the same `Content/` JSON, so lessons written now carry over unchanged.

| Spec item | iPhone app (as specced) | Website (built) | Why |
|---|---|---|---|
| Stack | SwiftUI, SwiftData | Plain HTML, CSS and JavaScript modules; no framework, no build step, no packages | Nothing to install; Python's built-in server runs it |
| Saved state | SwiftData | `localStorage` in the browser, same fields as §7 | No backend, still on-device only |
| Logic | `LeitnerScheduler`, `StreakCalculator` (planned in Swift) | `web/js/logic/` (Leitner, streak, day keys, progress, review session) | Tested with `scripts/test-web.sh` using macOS's built-in JavaScriptCore; no Node needed |
| Scroll animation | `scrollTransition` + staged builds | CSS scroll-driven animation (`animation-timeline: view()`) + the same staged builds | Same two layers (§5.2). Older browsers get a one-way fade-in |
| Progress bar, resume | `onScrollGeometryChange`, `scrollPosition(id:)` | Scroll position → bar; anchor section + fraction saved 0.8 s after scrolling stops, when the tab is hidden, and on close | Reloading or closing the tab is the web's force-quit |
| Icons | SF Symbols | Strata's own line icons; each SF Symbol name in the JSON maps to the nearest one | SF Symbols may only be used on Apple platforms |
| Charts | Swift Charts | Hand-drawn SVG | No charting library needed |
| Reminders | 14 local notifications | A calendar file (.ics) with a daily repeating event at your chosen time | A website can't schedule notifications without a push server, which is on your ask-first list. Trade-off: the calendar event can't skip days when the goal is already met |
| Offline | Bundled | A service worker saves the app and every lesson after the first visit | Works offline on `localhost`, or on any HTTPS address |
| Dynamic Type | Text styles | `font: -apple-system-body` (follows the iPhone text size in Safari); side-by-side layouts stack at very large sizes or when a label wouldn't fit | |
| Lesson index | Folder reference in Xcode | `scripts/serve.py` and `scripts/build_web.py` list `Content/Lessons/**.json` automatically | Adding a lesson is still one JSON file |
| App name | `APP_DISPLAY_NAME` in `Config/App.xcconfig` | Read from the same line by the server and build script | One place to rename both |
| Content problems screen | Debug builds only | Always on (a red banner on Home when a file fails to load) | Personal use; the Swift validator is still the full check |

## 1. Product in one paragraph

Strata teaches five topics (Psychology, Science & Technology, Finance & Business, History, Philosophy) through 30 long, visual scroll lessons of 10–15 minutes each. A lesson is one vertical page of 15–25 sections. Each section holds one idea: a large diagram built from data, plus a few sentences. Visuals draw themselves as they scroll into view. Quiz checks sit mid-lesson, a 5-question quiz closes the lesson, and every question you answer goes into a Leitner spaced-review deck. A daily goal, a streak with a weekly freeze, and a local reminder bring you back. Everything is bundled in the app; it never touches the network.

Design principles:
1. **Visual first.** The diagram is the content and the text is its caption. Body text is ≤ 60 words per section (the validator warns above 80).
2. **One idea per section.** If a section needs "also", it becomes two sections.
3. **Every lesson has the same arc:** hook → what it is → core ideas → a real example → why it matters → 3-bullet recap → sources.
4. **Honest content.** Every number, date and quote traces to a listed source. Contested claims carry a visible **Contested** badge.
5. **Data, not code.** A new lesson is one JSON file.

---

## 2. Look and feel (own identity)

Rules I'm holding myself to: I'm not using Imprint's name, logo, palette, illustrations, icons or text, and I'm not extracting anything from their app. The only things carried over are the generic interaction patterns your brief names.

### 2.1 Visual style: "field notebook"
- **Paper and ink.** A warm off-white page with near-black ink in light mode, and a deep slate page with warm off-white ink in dark mode.
- **Diagrams look hand-drafted but precise:** 2-pt ink strokes, flat topic-color fills, rounded corners, and a faint dot-grid behind each diagram canvas.
- **Motion is "drawing ink":** lines stroke in (`trim`), nodes stamp in one at a time, bars rise, timeline ticks march left to right.
- **Type:** headings in **New York** (Apple's system serif, via `.fontDesign(.serif)`), body in **SF Pro**, numbers in charts in SF Pro with `.monospacedDigit()`. All are system fonts, so there's nothing to license or bundle.
- **Icons:** SF Symbols only. They're free to use in apps on Apple platforms.
- **Streak mark:** a growing stack of layers (`square.stack.3d.up.fill`), not a flame.

### 2.2 Palette

| Token | Light | Dark | Use |
|---|---|---|---|
| `paper` | `#F6F1E7` | `#14161C` | page background |
| `card` | `#FFFDF8` | `#1E2129` | cards, quiz options |
| `ink` | `#1F2430` | `#ECE7DC` | body text, strokes |
| `inkMuted` | `#555A68` | `#A3A7B3` | captions, secondary |
| `rule` | `#E2DACB` | `#2C303A` | dividers, dot grid |
| `correct` | `#2A7247` | `#5CC48A` | right answer (always with ✓ icon + text) |
| `wrong` | `#B3261E` | `#F2766E` | wrong answer (always with ✗ icon + text) |

| Topic | SF Symbol | Light | Dark |
|---|---|---|---|
| Psychology | `brain.head.profile` | Coral `#D9573B` | `#F07A5E` |
| Science & Technology | `atom` | Teal `#127C7A` | `#3BB8B2` |
| Finance & Business | `chart.line.uptrend.xyaxis` | Ochre `#B07A12` | `#E3AE3F` |
| History | `scroll` | Plum `#8A3B78` | `#CC79B9` |
| Philosophy | `building.columns` | Indigo `#3E4FA8` | `#8796F0` |

The five hues sit about 60° apart on the color wheel, so each topic reads as its own color at a glance. Topic colors are used for **graphics and fills**, which need ≥ 3:1 contrast. Text never appears in a topic color on paper. Where colored text is unavoidable (a topic label), a darker `topicInk` variant is generated and checked to ≥ 4.5:1. Step 1 includes a unit test that computes WCAG contrast ratios for every token pair the UI actually uses.

---

## 3. Screens

| # | Screen | Purpose | Contents |
|---|---|---|---|
| S1 | **Home** (tab) | The daily entry point | Header with today's goal ring and streak count. **Continue** card: lesson in progress, a "% through" bar, Resume button. **Due for review** card: count due, "Start review", hidden when 0. Then **one shelf per topic**: a horizontal row of lesson cards with a "2/6" badge on the shelf title. |
| S2 | **Topic page** | All lessons of one topic | Topic-colored header (icon, name, "2 of 6 complete", progress bar). Lessons in `order` with ✓ (complete), a partial ring (in progress) or empty circle. Each row shows title, 1-line goal and minutes. Any lesson can be opened in any order. |
| S3 | **Scroll lesson** (full-screen cover) | The lesson itself | Sticky top bar: ✕ close, topic-colored progress bar, minutes left. Then the sections. At the bottom: recap, sources, and a "Take the final quiz" button. On re-entry: a "Resumed where you left off · Start over" pill for 3 s. |
| S4 | **Final quiz** (pushed inside the cover) | 5-question check | One question per screen; MC or T/F. Answer → feedback (✓/✗ + explanation) → Next. Progress dots 1–5. |
| S5 | **Lesson complete** | Reward plus the habit hook | Ink-stroke check animation, score "4/5", "+7 cards added to review", daily-goal ring filling, streak count with Mon–Sun dots (done / frozen / missed / today). Buttons: **Next lesson in topic**, **Done**. The first time, it offers "Want a daily reminder?" |
| S6 | **Review** (tab) | What's due today | "12 due today" with a Start button, the due cards grouped by lesson (title + count), and a box histogram (Box 1–5 bar chart). Empty state: "All caught up. Next review: Thu (3 cards)." |
| S7 | **Review session** (full-screen cover) | Answer due cards | Same question UI as S4, with up to the daily cap (default 20). Cards you get wrong come back once at the end of the session. |
| S8 | **Review complete** | Close the loop | "15 reviewed · 12 right". Shows box moves ("3 moved up, 2 back to box 1"), counts toward activity, Done. |
| S9 | **You** (tab) | Progress and settings | Streak, a month calendar (done / frozen / missed), totals (lessons, cards, accuracy). Settings: daily goal (1–3), reminder toggle and time picker, review cap, a Reduce Motion note ("follows iOS setting"), Reset progress (with confirm), About (name, version, "how content is sourced"). |
| S10 | **Content problems** (Debug builds only) | Surface bad JSON | Reached from a red banner on Home ("1 lesson failed to load"). Lists each file, its JSON path and the error message (see §6.8). Release builds silently skip bad files. |

Deliberately left out: onboarding (the reminder is offered on the first Lesson complete instead), accounts, search, social.

---

## 4. Navigation map

```
App
└── TabView
    ├── Home (NavigationStack)
    │   ├── Continue card ──────────────► [S3 Scroll lesson]  (fullScreenCover, resumes)
    │   ├── Due for review card ────────► [S7 Review session] (fullScreenCover)
    │   ├── Topic shelf title ──────────► S2 Topic page (push)
    │   │                                   └── lesson row ──► [S3 Scroll lesson]
    │   ├── Lesson card on shelf ───────► [S3 Scroll lesson]
    │   └── (Debug) error banner ───────► S10 Content problems (push)
    ├── Review (NavigationStack)
    │   └── Start review ───────────────► [S7 Review session] ──► S8 Review complete ──► dismiss
    └── You (NavigationStack)
        └── settings rows (inline), Reset (alert)

[S3 Scroll lesson] (own NavigationStack inside the cover)
    ├── ✕ ──────────────────────────────► dismiss (position saved)
    └── "Take the final quiz" ──────────► S4 Final quiz (push) ──► S5 Lesson complete (replace)
                                                                    ├── Next lesson ──► S3 (new lesson)
                                                                    └── Done ─────────► dismiss
```

Lessons and reviews open as full-screen covers, so the tab bar disappears and the lesson gets the whole screen. Swipe-down-to-dismiss is disabled inside a lesson (`interactiveDismissDisabled`) so a scroll gesture can't close it by accident.

---

## 5. The scroll lesson: behavior

### 5.1 Layout
`ScrollView` → `LazyVStack(spacing: 48)` of sections, max reading width 600 pt. Each section is a full-width "layer" with generous whitespace. The visual sits above the text by default (`layout: "visualFirst"`).

### 5.2 Scroll-driven animation (two layers)
- **A. Entrance (every section).** `.scrollTransition` maps the section's position in the viewport to opacity 0.3→1, a y-offset of 24→0 pt and a scale of 0.97→1. It's continuous and reversible, so the section "settles" as it reaches the reading zone.
- **B. Build (each visual, once).** Every visual has a `reveal` value from 0 to 1, driven by its parts' `step` numbers. It starts once, the first time the section is ≥ 35% visible: `onScrollVisibilityChange(threshold: 0.35)` on iOS 18, or a `GeometryReader` check against the scroll view's named coordinate space on iOS 17. Steps run with a stagger (default 0.25 s per step). Already-built visuals stay built for the rest of the session, so scrolling back up doesn't replay them.
- **Reduce Motion** (`@Environment(\.accessibilityReduceMotion)`): layer A becomes identity (no fade, move or scale) and layer B starts at `reveal = 1`. Everything is drawn complete and static.

### 5.3 Progress bar
- iOS 18+: `onScrollGeometryChange` gives `progress = contentOffset.y / (contentSize.height − containerSize.height)`, clamped 0…1.
- iOS 17: `progress = index(topSection) / (sectionCount − 1)`, using `scrollPosition(id:)`.
- VoiceOver reads it as "Lesson progress, 40 percent".

### 5.4 Saving and resuming
- **Saved state:** `anchorSectionID` (the top-most visible section, from `scrollPosition(id:)`) plus `anchorFraction` (how far into that section, 0…1, measured on iOS 18 and 0 on iOS 17), and `furthestProgress`.
- **When it saves:** debounced 1 s after scrolling stops, on ✕, and on `scenePhase == .background`, with an explicit `modelContext.save()`. Swiping up to the app switcher moves the app to background *before* it can be force-quit, so the last position is always on disk.
- **On reopen:** `scrollTo(anchorSectionID, anchor: .top)`, then nudge by `anchorFraction`. If the JSON changed and that section ID no longer exists, it falls back to the section with the same index, then to the top.
- "Start over" resets the anchor and keeps quiz history.

### 5.5 Inline checks
An inline check is a card with 1–2 questions and doesn't block scrolling. Answering shows ✓/✗ and the explanation in place. Answered questions go into review (see §8). Unanswered ones are added as **new, box 1, due tomorrow** when the lesson is completed, because unseen is treated as "not yet known".

### 5.6 Lesson completion
A lesson is complete when the final quiz is finished, at any score. The "Take the final quiz" button appears after the recap. Completing a lesson again (a retake) counts toward the daily goal again.

---

## 6. Content format

### 6.1 Files
```
Content/                      ← added to Xcode as a *folder reference* (blue folder),
  topics.json                   so new files are bundled automatically, subfolders kept
  Lessons/
    psychology/psy-cognitive-biases.json
    science/sci-how-the-brain-works.json
    ...
```
At launch the loader recursively reads every `*.json` under `Lessons/`. **Adding a lesson = dropping one JSON file in the folder.** Topics are data too (`topics.json`: id, name, symbol, colors, order), so even a sixth topic needs no Swift.

### 6.2 Lesson file (top level)

| Field | Type | Rule |
|---|---|---|
| `schemaVersion` | int | `1` |
| `id` | string | kebab-case, globally unique, **never changes** (progress and review cards key off it) |
| `topic` | string | must match an id in `topics.json` |
| `order` | int | position within the topic (1…6), unique per topic |
| `title` | string | ≤ 50 chars |
| `goal` | string | the 1-line goal, ≤ 120 chars |
| `minutes` | int | 10–15 |
| `contentVersion` | int | bump when content changes |
| `sections` | [Section] | 15–25 items, unique `id`s, must start with `hook` and end with `recap`, ≥ 1 `check` |
| `finalQuiz` | [Question] | exactly 5 |
| `sources` | [Source] | 2–4 |
| `factCheck` | object | `{ "checkedOn": "YYYY-MM-DD", "notes": "…" }`, required before a lesson counts as done |

### 6.3 Section types

Every section has `id`, `type`, optional `sourceRefs: [sourceId]` and optional `contested: { "note": "…" }`, which renders a **Contested** badge with the note underneath. Text fields accept inline Markdown (bold, italic) via `AttributedString(markdown:)`.

| Code (outline) | `type` | Fields | Renders as |
|---|---|---|---|
| HOOK | `hook` | `headline`, `body`, `visual?` | big serif headline over a hero visual; always first |
| TV | `textVisual` | `heading?`, `body`, `visual`, `layout?` (`visualFirst`\|`textFirst`) | the workhorse: large visual, short caption |
| KEY | `keyIdea` | `statement`, `body?`, `symbol?` | full-width topic-tinted card, statement in large serif |
| CMP | `comparison` | `columns` (2–3 × `{title, symbol?}`), `rows` (`{label, values[]}`), `takeaway?` | side-by-side columns, rows stamp in one by one. *(The brief says A vs B. I allow up to 3 columns only for the three-theories ethics lesson.)* |
| TL | `timeline` | `events` (`{date, sortKey, title, detail?, approx?}`), `scale?` (`linear`\|`even`) | horizontal axis with ticks that march in; events sorted by `sortKey` (negative = BCE) |
| STEPS | `steps` | `steps` (`{title, body?, symbol?}`), `style` (`numbered`\|`cycle`\|`flow`) | numbered stack, a circular cycle, or a left-to-right flow with arrows |
| CHART | `chart` | `chartKind` (`bar`\|`line`), `series` (`{name, points:[{x, y}]}`), `xLabel`, `yLabel`, `unit?`, `dataKind` (`sourced`\|`computed`\|`illustrative`), `dataNote`, `caption` | Swift Charts (Apple framework). `sourced` requires `sourceRefs`; `computed` shows the formula in `dataNote`; `illustrative` shows an "Illustrative" tag. |
| QUOTE | `quote` | `text`, `speaker`, `work`, `year`, `translator?`, `publicDomain` (bool) | large serif quote with attribution. If `publicDomain` is false, the text must be ≤ 25 words. A `sourceRef` is required. |
| CHECK | `check` | `questions` (1–2 Question) | inline quiz card (§5.5) |
| RECAP | `recap` | `bullets` (exactly 3) | three numbered takeaways; always last. Sources render automatically below it. |

### 6.4 Visuals (inside `hook` / `textVisual`)

All visuals are drawn by SwiftUI from data, with no image files. Every visual **requires** `accessibilityLabel` (one or two sentences describing what it shows). Colors are **semantic tokens** (`topic`, `topicSoft`, `ink`, `muted`, `paper`, `correct`, `wrong`), never hex, so themes and dark mode just work. Most parts accept a `step` (int) that sets build order.

| `kind` | Fields | Good for |
|---|---|---|
| `diagram` | `layout` (`row`\|`column`\|`cycle`\|`grid`\|`free`), `nodes` (`{id, label, symbol?, x?, y?, style}`), `edges` (`{from, to, label?, style: arrow\|line\|dashed}`) | flowcharts, cycles, networks, concept maps |
| `shapes` | `aspectRatio`, `items`: `rect`, `circle`, `polygon(points)`, `line(points, arrow?)`, `text`, `symbol`, all in 0–1 coordinates | maps-as-shapes, anatomy sketches, Venn diagrams, balance scales, anything custom |
| `iconArray` | `total`, `groups` (`{count, color, label}`), `symbol`, `columns` | "37 out of 100" unit charts, proportions |
| `formula` | `parts` (`{text, label?, color?}`) | `A = P(1 + r/n)^(nt)` with labeled pieces |
| `bigNumber` | `value`, `unit?`, `label`, `countUp` (bool) | a single striking stat |
| `layers` | `layers` (`{label, detail?, symbol?}`), `direction` (`up`\|`down`) | stacks: network layers, layers of a model |
| `symbol` | `name`, `caption?` | a single large SF Symbol hero |

### 6.5 Question

```json
{ "id": "c1q1", "kind": "multipleChoice",
  "prompt": "…", "choices": ["…", "…", "…", "…"], "answer": 2,
  "explanation": "…", "sourceRefs": ["s1"] }
{ "id": "f3", "kind": "trueFalse", "prompt": "…", "answer": true, "explanation": "…" }
```
- `id` is unique within the lesson. The global question ID is `"<lessonId>.<id>"` and is what review cards key off. **Don't reuse an ID for a different question.**
- Multiple-choice questions have 2–4 choices, and `answer` is a valid index. Choices are shuffled at display time, and the stored answer is checked by content, not position.
- An `explanation` is required: it's shown after every answer, right or wrong.

### 6.6 Source

```json
{ "id": "s1", "kind": "textbook",
  "title": "Psychology 2e", "authors": "Spielman, R. M., et al.",
  "publisher": "OpenStax", "year": 2020, "locator": "Ch. 7",
  "url": "https://openstax.org/details/books/psychology-2e", "accessed": "2026-11-24" }
```
`kind` is one of `textbook`, `journal`, `encyclopedia`, `university`, `government`, `organization`, `primary`, `book`, `standard`. The sources list at the end of a lesson shows each source as a citation. URLs are tappable and open **Safari**; the app itself never fetches them.

### 6.7 Example (format only, abbreviated, placeholder content)

```json
{
  "schemaVersion": 1,
  "id": "psy-how-memory-works",
  "topic": "psychology",
  "order": 2,
  "title": "How Memory Works",
  "goal": "Follow a memory from encoding to storage to retrieval, and see why it fails.",
  "minutes": 12,
  "contentVersion": 1,
  "sections": [
    { "id": "hook", "type": "hook",
      "headline": "You've seen a penny thousands of times.",
      "body": "Could you draw one from memory? Most people can't.",
      "visual": { "kind": "symbol", "name": "centsign.circle",
                  "accessibilityLabel": "A large coin outline with its details missing." },
      "sourceRefs": ["s3"] },
    { "id": "stages", "type": "textVisual",
      "body": "Every memory goes through three stages.",
      "visual": { "kind": "diagram", "layout": "row",
        "nodes": [ { "id": "e", "label": "Encoding", "symbol": "square.and.arrow.down", "style": "filled", "step": 1 },
                   { "id": "s", "label": "Storage",  "symbol": "archivebox",            "style": "filled", "step": 2 },
                   { "id": "r", "label": "Retrieval","symbol": "arrow.up.doc",          "style": "filled", "step": 3 } ],
        "edges": [ { "from": "e", "to": "s", "style": "arrow" }, { "from": "s", "to": "r", "style": "arrow" } ],
        "accessibilityLabel": "Three boxes in a row: encoding, then storage, then retrieval, joined by arrows." },
      "sourceRefs": ["s1"] },
    { "id": "c1", "type": "check", "questions": [ { "id": "c1q1", "kind": "trueFalse",
        "prompt": "Retrieval is the first stage of memory.", "answer": false,
        "explanation": "Encoding comes first: information has to get in before it can be stored or retrieved." } ] },
    { "id": "recap", "type": "recap", "bullets": ["…", "…", "…"] }
  ],
  "finalQuiz": [ "… 5 questions …" ],
  "sources": [ "… 2–4 sources …" ],
  "factCheck": { "checkedOn": "2026-11-24", "notes": "All dates and numbers checked against s1–s3." }
}
```

### 6.8 Loading and validation (clear errors)

One validator, written in Swift, is used in **three** places: the app's loader, the unit tests, and a command-line tool.

```
swift run --package-path Packages/LessonKit validate-lessons Content
```

**Error format:** file, JSON path, problem, and what was expected:
```
✗ Lessons/history/his-cold-war.json
  sections[7] (timeline "arms-race") → events[2].sortKey: missing required key
  sections[12] (type "chrat"): unknown section type. Expected one of: hook, textVisual, keyIdea,
      comparison, timeline, steps, chart, quote, check, recap
  finalQuiz: has 4 questions, needs exactly 5
  sections[9] (quote "churchill"): not public domain and 31 words (max 25)
⚠ sections[4] (textVisual "proxy-wars"): body is 94 words (aim ≤ 60)
⚠ sections[10]: contains numbers but no sourceRefs
1 file failed · 29 passed · 2 warnings
```
Swift's `DecodingError.codingPath` is turned into the `sections[7].events[2]` style path. Unknown enum values list the allowed ones.

**Errors** (the file is rejected): malformed JSON; missing or extra-unknown keys; a wrong `type`/`kind`; duplicate IDs (lesson, section, question); a duplicate `topic`+`order`; a section count outside 15–25; first not `hook` or last not `recap`; no `check`; a check with ≠ 1–2 questions; final quiz ≠ 5; sources outside 2–4; a `sourceRef` that points nowhere; a bad `answer` index; recap ≠ 3 bullets; a chart whose `sourced` data has no `sourceRefs`; a non-public-domain quote over 25 words; a missing `accessibilityLabel`; diagram edges pointing to missing nodes; `minutes` outside 10–15.

**Warnings:** body over 80 words; digits in a section with no `sourceRefs` (excluding `computed`/`illustrative` charts and `steps` numbering); missing `factCheck`.

Behavior in the app: bad files are skipped and the rest load. Debug builds show the S10 banner, and a unit test fails the build if any bundled lesson has an error.

---

## 7. Data model

Lesson **content** is not stored in the database. It's re-read from the bundle on each launch (30 small files, a few milliseconds). SwiftData stores only **your state**, keyed by stable IDs. That means editing a lesson never needs a migration.

```swift
@Model final class LessonProgress {
    @Attribute(.unique) var lessonID: String
    var statusRaw: String            // "notStarted" | "inProgress" | "completed"
    var anchorSectionID: String?     // resume point
    var anchorFraction: Double       // 0…1 within that section
    var furthestProgress: Double     // 0…1 of the whole lesson
    var contentVersionSeen: Int
    var startedAt: Date?
    var lastOpenedAt: Date?
    var firstCompletedAt: Date?
    var completionCount: Int
    var bestFinalScore: Int?         // 0…5
}

@Model final class ReviewCard {
    @Attribute(.unique) var questionID: String   // "psy-how-memory-works.c1q1"
    var lessonID: String
    var box: Int                     // 1…5
    var dueDay: Int                  // DayKey as yyyymmdd, e.g. 20261127
    var createdAt: Date
    var lastAnsweredAt: Date?
    var correctCount: Int
    var wrongCount: Int
}

@Model final class AnswerEvent {     // append-only log: debugging, stats, tests
    var questionID: String
    var lessonID: String
    var answeredAt: Date
    var day: Int                     // DayKey
    var contextRaw: String           // "inline" | "final" | "review"
    var correct: Bool
    var boxBefore: Int?
    var boxAfter: Int
}

@Model final class ActivityDay {
    @Attribute(.unique) var day: Int // DayKey in the time zone you were in when you did it
    var lessonsCompleted: Int
    var reviewsAnswered: Int
    var goalAtTime: Int              // goal when the day was recorded (changing goal never rewrites history)
    var goalMet: Bool                // set once lessonsCompleted ≥ goalAtTime; never unset
    var firstActivityAt: Date
    var lastActivityAt: Date
    var firstUTCOffset: Int          // seconds, at firstActivityAt
    var lastUTCOffset: Int           // seconds, at lastActivityAt
}
```

**Settings** live in `@AppStorage` (UserDefaults): `dailyGoal` (1), `reminderEnabled` (false), `reminderHour`/`reminderMinute` (19:00), `reviewCap` (20).

**`DayKey`** is a value type for a *calendar date* (year, month, day) with no time and no time zone. "Today" is `DayKey(now, in: TimeZone.current)`. Day math (`+3 days`, "days between") uses a Gregorian calendar fixed to UTC on these plain dates, so daylight-saving shifts (23- and 25-hour days) can't cause off-by-one bugs.

The streak is **never stored**. It's computed from `ActivityDay` rows every time (§9), so it can't drift out of sync.

---

## 8. Review algorithm (Leitner)

Five boxes. A card's box sets how long until you see it again:

| Box | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Interval (days) | 1 | 3 | 7 | 14 | 30 |

**Rules** (pure function `LeitnerScheduler.apply(card?, correct:, context:, today:) -> CardState`):

| Situation | Right answer | Wrong answer |
|---|---|---|
| First time you see the question (inline check or final quiz) | new card, **box 2**, due today + 3 | new card, **box 1**, due today + 1 |
| Unanswered inline question when the lesson completes | — | new card, box 1, due today + 1 |
| **Review session** | box + 1 (max 5), due today + interval(new box) | **back to box 1**, due today + 1 |
| Retaking a lesson (card already exists) | no change (so retakes can't inflate boxes) | back to box 1, due today + 1 |
| Box 5, right in review | stays box 5, due today + 30 | box 1 |

- **Due today** means `dueDay ≤ today`, which means overdue cards are included.
- **Session order:** most overdue first (`dueDay` ascending), then lower box first, then shuffled. Capped at `reviewCap` (default 20). The rest stay due and come first tomorrow.
- **Within a session:** a card you miss is shown once more at the end. That second try is practice only and doesn't move the box. Only the first answer counts.
- **Content edits:** cards whose question was deleted from the JSON are hidden (kept in the database, never shown). A question whose text changed but kept its `id` keeps its history.
- Wrong → comes back tomorrow; right → goes further out. This is the acceptance test "a wrong quiz answer brings that question back in a later review; a right one pushes it further out."

**Tests (Step 3):** every row of the table above; box-5 ceiling; overdue inclusion; ordering and cap; requeue doesn't move boxes; due dates across a DST change and month and year ends (Dec 31 + 3 → Jan 3).

---

## 9. Daily goal, streak, freeze, time zones

### 9.1 Definitions
- **Goal met** on a day: you completed ≥ `dailyGoal` lessons (retakes count) on that day. That fact is frozen into `ActivityDay.goalMet`.
- **Streak:** the number of goal-met days in the current unbroken run. Frozen and forgiven days keep the run alive but **don't add** to the count.
- **Freeze:** one per week, used automatically on the first missed day of a week, and only if there's a streak to protect (count > 0). Unused freezes don't carry over. The week boundary follows your iPhone's region setting (`Calendar.current.firstWeekday`).
- **Today doesn't count against you until it's over.** If today isn't done yet, the streak shows the run through yesterday, with "Do a lesson to keep your N-day streak".

### 9.2 Algorithm (pure function `StreakCalculator.compute(days:today:now:currentOffset:)`)
Simulate forward through time, which matches what you'd have seen live:

```
met     = set of DayKeys with goalMet (any key later than today is treated as today: see "flying west")
count   = 0; freezeUsedInWeek = {}; frozen = []; forgiven = []
for d from earliest met day through yesterday:
    if d ∈ met:                         count += 1
    else if travelForgives(d):          forgiven.append(d)          // see 9.3
    else if count > 0 and week(d) ∉ freezeUsedInWeek:
                                        freezeUsedInWeek.insert(week(d)); frozen.append(d)
    else:                               count = 0                   // streak broken
if today ∈ met: count += 1
return (count, todayDone: today ∈ met, frozen, forgiven,
        freezeAvailableThisWeek: week(today) ∉ freezeUsedInWeek)
```
Why forward and not backward: if you miss Monday and Thursday of the same week, Monday uses the freeze and Thursday breaks the streak. Walking backward from today would wrongly spend the freeze on Thursday and keep the streak alive.

### 9.3 Time-zone changes
Each `ActivityDay` is keyed by the calendar date **where you were** when you did the activity, and records the UTC offset.
- **Flying east can skip a calendar day.** For example: lesson at 8 pm on Nov 24 in Los Angeles, land in Tokyo where it's already Nov 26. Nov 25 never happened for you. Rule: a missed day `d` is **forgiven** if the met days on either side of it (A before, B after) were recorded at **different UTC offsets** and less than **24 real hours** passed between A's last activity and B's first. Without a time-zone change, skipping a whole calendar day always takes more than 23 hours, and with the "different offset" condition the 23-hour DST day can't trigger it by accident. If B hasn't happened yet (you just landed and haven't done today's lesson), "now" stands in for B, so yesterday isn't marked missed while you're still within 24 hours.
- **Flying west repeats part of a day.** The date can go backward (activity recorded as Nov 25 in Tokyo, now it's Nov 24 in LA). Days "after today" are treated as today, so nothing breaks and nothing double-counts.
- **DST:** handled by `DayKey` (§7). An hour more or less doesn't change which calendar day it is.

**Tests (Step 3):** 5 consecutive days; today not done yet (no break); one miss with a freeze; two misses in one week (break on the second); misses in two different weeks (both frozen); freeze not used when count = 0; week rollover gives a fresh freeze; Sunday-start vs Monday-start weeks; raising the goal doesn't rewrite past days; DST spring-forward and fall-back nights; east across the date line (forgiven); east trip with a real missed day (> 24 h, not forgiven); west trip with a "future" key; a midnight-boundary lesson (11:59 pm vs 12:01 am).

---

## 10. Reminders (local notifications)

- **Permission** is requested only when you turn the reminder on (S5 prompt or S9 toggle), never at launch.
- **Scheduling:** 14 one-off notifications (`UNCalendarNotificationTrigger`, not repeating) at your chosen time for the next 14 days. They're rescheduled on every app foreground and every lesson completion. **When today's goal is met, today's notification is removed.** That's why it isn't a single repeating notification: a repeating one can't skip just today.
- If you don't open the app for 14 days, reminders stop. That's deliberate: no endless nagging. iOS allows 64 pending notifications, and we use 14.
- **Copy** rotates through a few short lines ("Your next layer is ready: 12 minutes."). No network, no server.

---

## 11. Accessibility

- **Dynamic Type:** all text uses text styles. Comparison columns, step flows and quiz layouts switch from horizontal to vertical at accessibility sizes (`ViewThatFits` / `dynamicTypeSize.isAccessibilitySize`). Diagram labels use `minimumScaleFactor(0.7)` and wrap. Diagrams get taller rather than text getting smaller. Tested at XS and AX5.
- **VoiceOver:** every visual reads its required `accessibilityLabel`. Charts also expose an `AXChartDescriptor` built from the data, so the VoiceOver rotor's audio graph works. Timelines read events in order. Quiz choices are buttons with "selected / correct / incorrect" values. The progress bar reads as a percentage. Decorative dot grids are hidden.
- **Reduce Motion:** turns off scroll animations entirely (§5.2) and replaces the quiz feedback bounce with an instant change.
- **Color is never the only signal:** right/wrong always pair color with ✓/✗ and words, and topics pair color with an icon.

---

## 12. Offline and privacy

- No networking code at all: no `URLSession`, no analytics, no crash reporters, no remote config. All content is bundled.
- The only thing that touches the internet is a source link **you** tap, which opens Safari.
- The Step 5 check includes running the full lesson, quiz and review flow in Airplane Mode.
- Data stays on device in SwiftData. "Reset progress" deletes it.

---

## 13. Architecture, project layout, tests

```
Strata/
├── SPEC.md · README.md
├── Config/App.xcconfig               ← APP_DISPLAY_NAME (rename here), bundle id, iOS 17
├── Strata.xcodeproj
├── App/                              ← iOS app target (SwiftUI + SwiftData)
│   ├── StrataApp.swift
│   ├── Theme/                        palette tokens, topic colors, fonts
│   ├── Persistence/                  @Model types, ProgressStore (wraps ModelContext)
│   ├── Screens/  Home/ Topic/ Lesson/ Quiz/ Review/ You/ Debug/
│   ├── Sections/                     one view per section type (10)
│   ├── Visuals/                      one view per visual kind (7) + RevealState
│   └── Notifications/                ReminderScheduler
├── Content/                          ← folder reference: topics.json + Lessons/**.json
├── Packages/LessonKit/               ← local Swift package, pure logic, no UI
│   ├── Sources/LessonKit/            Codable models, Loader, Validator, DayKey,
│   │                                 LeitnerScheduler, StreakCalculator
│   ├── Sources/validate-lessons/     command-line validator (main.swift)
│   └── Tests/LessonKitTests/         loader/validator, Leitner, streak, contrast,
│                                     "all bundled lessons validate"
├── StrataTests/                      app-level: store integration, resume logic
├── StrataUITests/                    open lesson → scroll → kill → relaunch → resumed
└── scripts/validate.sh · scripts/test.sh
```

Why a local package: the scheduling, streak and validation logic has no UI, so it runs under **`swift test` on the Mac in seconds**, with no simulator boot. The same validator code serves the app, the tests and the CLI, so they can't disagree. It's your own code, not a third-party dependency.

**State:** `@Observable` view models (iOS 17 Observation), `@Query` for lists, and one `ProgressStore` that is the only thing writing to SwiftData. Pure functions decide (Leitner, streak) and the store persists the result.

**Commands** (exact versions in the README):
```
swift test --package-path Packages/LessonKit                       # logic + content, ~seconds
xcodebuild test -scheme Strata -destination 'platform=iOS Simulator,name=iPhone 17'
swift run --package-path Packages/LessonKit validate-lessons Content
```

---

## 14. Content accuracy process (per lesson)

1. **Pick 2–4 sources**, preferring ones you can open for free: OpenStax textbooks, the Stanford Encyclopedia of Philosophy, the Internet Encyclopedia of Philosophy, Britannica, university pages, government data (BLS, the Federal Reserve, SEC/Investor.gov), RFCs, and public-domain primary texts. Paywalled books appear only as a secondary source.
2. **Write from the sources, from scratch.** I don't paraphrase any app's lesson text.
3. **Tag claims:** every section with a number, date, statistic or quote gets `sourceRefs`. Chart data is `sourced` (with the dataset named), `computed` (formula shown) or `illustrative` (labeled).
4. **Contested:** where scholars genuinely disagree, or a famous finding failed to replicate, the section gets a `contested` note that says *what* is disputed.
5. **No invention:** no invented quotes, numbers or dates. If I can't confirm a claim against a listed source, it's cut, not softened.
6. **Accuracy pass:** a second read of each lesson against its sources, recorded in `factCheck`.
7. Quotes: public-domain translations quoted freely (with translator named). Modern works are quoted at ≤ 25 words with attribution.

> All numbers, dates and quotes in the outline below (§18) are **planning placeholders**. Each one is confirmed against the listed sources when the lesson is written, or dropped. The candidate sources are a starting list and may change.

---

## 15. Build plan (maps to your checklist)

| Step | Deliverable | Shown in simulator |
|---|---|---|
| 0 | This spec | — |
| 1 | Xcode project + LessonKit; schema, loader, validator with clear errors; scroll renderer with all 10 section types and 7 visual kinds; scroll animations; Reduce Motion; the 5 first lessons (one per topic: PSY-1, SCI-4, FIN-1, HIS-2, PHI-2, chosen because together they use every section and visual type) | lessons scrolling, animations, Reduce Motion on/off |
| 2 | Inline checks + final quiz with explanations; LessonProgress; resume after force-quit | quiz flow, kill-and-resume |
| 3 | Leitner + Review tab and session; streak, freeze, goal; reminders; tests for boxes, due dates, missed days, time zones | review session, Lesson complete with streak |
| 4 | Home (Continue, Due, shelves), Topic pages, You tab, polish, contrast test | full app tour |
| 5 | Remaining 25 lessons; validator passes on all 30; accuracy pass; accessibility pass (Dynamic Type AX5, VoiceOver, Reduce Motion); offline check; README | spot checks |
| ✓ | You: one lesson per topic + a review session on your phone | — |

---

## 16. Your decisions (defaults apply if you don't answer)

1. **Name and look:** "Strata" with the field-notebook palette above. (Default: yes.)
2. **iOS 17 minimum with an iOS 18 enhancement** for the progress bar (§0 #3). (Default: yes. Alternative: require iOS 18 and drop the fallback code.)
3. **Should a finished review session count toward the daily goal?** (Default: no, only lessons, as decided.)
4. **Comparison with 3 columns**, used once in the ethics lesson. (Default: yes.)

## 17. If you ever launch (personal use for now)

You'd need to: check the name against trademarks and the App Store (and pick another if needed); join the Apple Developer Program ($99/yr — ask-first); write a privacy policy and fill the App Store privacy label ("Data Not Collected" stays true); get an independent review of content accuracy and quote permissions; add a "not financial advice" line to Finance lessons (I'll add it anyway); design an app icon and screenshots; do an iPad layout pass; and get a second opinion that nothing looks like Imprint. Nothing in the architecture would change.

---

## 18. The 30 lessons

Section codes: **HOOK** hook · **TV** text + visual (`[kind]`) · **KEY** key idea · **CMP** comparison · **TL** timeline · **STEPS** step sequence · **CHART** chart (`sourced`/`computed`/`illustrative`) · **QUOTE** quote · **CHECK** inline quiz · **RECAP** recap.
⚑ = section carries a **Contested** note. Every lesson also ends with **Sources** (automatic) and a **5-question final quiz**; neither counts toward the 15–25 sections. The **(n)** after each title is the section count.

### 18.1 Psychology (coral · `brain.head.profile`)

**PSY-1 Cognitive Biases (19)**
Goal: See why the mind's fast shortcuts (heuristics) produce predictable errors, and learn to spot five classic biases.
1. HOOK — the bat-and-ball puzzle ($1.10 total; the "obvious" answer is wrong) [`bigNumber`]
2. TV[diagram] — what a heuristic is: a shortcut that's usually right and sometimes badly wrong
3. CMP — "System 1" (fast, automatic) vs "System 2" (slow, effortful); noted as a metaphor, not two brain parts
4. KEY — biases are *systematic*: errors lean the same way, so they're predictable
5. TV[shapes] — anchoring: the wheel-of-fortune experiment (Tversky & Kahneman 1974)
6. TV[iconArray] — availability: judging how common something is by how easily examples come to mind
7. CHECK — anchoring vs availability (2 Qs)
8. TV[diagram] — representativeness and the conjunction fallacy ("Linda", 1983)
9. TV[iconArray] — base-rate neglect, shown with 100 people
10. STEPS[flow] — confirmation bias: Wason's 2-4-6 task (1960)
11. QUOTE — Francis Bacon, *Novum Organum* (1620, public domain) on the mind seeking agreement
12. TV[diagram] — framing: the same choice worded as lives saved vs lives lost (1981)
13. CHART[computed] — prospect-theory value curve: losses loom larger than gains
14. CHECK — framing and loss aversion (2 Qs)
15. KEY ⚑ — how much lab biases matter in real life, and whether "debiasing" works, are debated; some researchers argue heuristics are often smart ("ecological rationality")
16. STEPS[numbered] — real example: a used-car negotiation, bias by bias (anchor price, framing, confirmation)
17. STEPS[numbered] — tools with evidence: consider the opposite, start from base rates, the pre-mortem
18. TV[symbol] — why it matters: money, medicine, juries, everyday judgment
19. RECAP
Candidate sources: Tversky & Kahneman (1974) *Science*; Kahneman, *Thinking, Fast and Slow* (2011); OpenStax *Psychology 2e* ch. 7; Bacon, *Novum Organum* (1620).

**PSY-2 How Memory Works (18)**
Goal: Follow a memory from encoding to storage to retrieval, see why we forget and misremember, and turn that into better study habits.
1. HOOK — can you draw a penny from memory? (Nickerson & Adams 1979)
2. TV[diagram] — three stages: encoding → storage → retrieval
3. TV[diagram] — the multi-store model: sensory → short-term → long-term (Atkinson & Shiffrin 1968), labeled "a model, simplified"
4. TV[iconArray] ⚑ — how much working memory holds: Miller's "7 ± 2" (1956) vs a later estimate of about 4 chunks (Cowan 2001)
5. TV[shapes] — chunking: a 10-digit number regrouped
6. CMP — explicit (episodic, semantic) vs implicit (procedural, priming)
7. TV[shapes] — the hippocampus and consolidation; patient H.M. (Henry Molaison)
8. CHECK — stages and memory types (2 Qs)
9. CHART[illustrative] — the forgetting curve (after Ebbinghaus, 1885)
10. QUOTE — Ebbinghaus, *Memory* (1885; 1913 English translation, public domain)
11. TV[diagram] — context and retrieval cues: the underwater divers study (Godden & Baddeley 1975)
12. TV[diagram] — memory is reconstructive: "smashed" vs "hit" (Loftus & Palmer 1974)
13. KEY — the testing effect: recalling something strengthens it more than rereading (Roediger & Karpicke 2006)
14. CMP — massed vs spaced practice
15. STEPS[cycle] — real example: how this app's Leitner review uses spacing and testing
16. CHECK — study strategies (2 Qs)
17. TV[symbol] — why it matters: studying, eyewitness testimony, aging
18. RECAP
Candidate sources: OpenStax *Psychology 2e* ch. 8; Roediger & Karpicke (2006) *Psychological Science*; Loftus & Palmer (1974); Ebbinghaus (1885/1913).

**PSY-3 Motivation & Habits (19)**
Goal: Understand what drives behavior, how habits form as cue–response links, and which habit-building methods have evidence behind them.
1. HOOK — a large share of daily actions are repeated in the same context almost every day (Wood et al. 2002 diary study) [`bigNumber`]
2. TV[diagram] — motivation as drives, incentives and goals
3. CMP — intrinsic vs extrinsic motivation
4. TV[diagram] — self-determination theory: autonomy, competence, relatedness
5. TV[shapes] ⚑ — the overjustification effect (Lepper, Greene & Nisbett 1973) and the meta-analysis debate over when rewards undermine motivation
6. CHECK (2 Qs)
7. STEPS[cycle] — the habit loop: cue → routine → reward, and how repetition makes it automatic
8. TV[diagram] — reinforcement schedules (operant conditioning); why variable rewards are sticky
9. TV[diagram] — dopamine as a *prediction-error* signal, not a "pleasure chemical"
10. CHART[illustrative] — automaticity rising then plateauing; median ≈ 66 days, range 18–254 (Lally et al. 2010)
11. KEY — a stable context beats willpower
12. STEPS[numbered] — implementation intentions: "If X, then I will Y" (Gollwitzer)
13. CMP — adding friction to bad habits vs removing it from good ones
14. KEY ⚑ — "willpower as a fuel tank" (ego depletion): a large multi-lab replication found little or no effect
15. CHECK (2 Qs)
16. STEPS[numbered] — real example: designing a 15-minute daily study habit
17. TV[symbol] — why it matters
18. TV[diagram] — what to do on a missed day (one miss doesn't erase a habit, per Lally et al.)
19. RECAP
Candidate sources: OpenStax *Psychology 2e* ch. 10; Lally et al. (2010) *European Journal of Social Psychology*; Wood & Neal (2007) *Psychological Review*; Ryan & Deci (2000) *American Psychologist*.

**PSY-4 Emotions & Stress (18)**
Goal: Learn what emotions are made of, how the stress response works in brain and body, and which coping strategies have evidence.
1. HOOK — pounding heart before an exam: fear or excitement?
2. TV[diagram] — the parts of an emotion: body, appraisal, expression, feeling
3. TL — theories of emotion: James–Lange (1884), Cannon–Bard (1927), Schachter–Singer (1962), appraisal theory, constructed emotion (2017)
4. CMP — James–Lange vs Cannon–Bard: which comes first, body or feeling?
5. TV[shapes] ⚑ — "basic emotions" and facial expressions: the universality debate
6. TV[shapes] — amygdala and prefrontal cortex: alarm and brake
7. CHECK (2 Qs)
8. TV[diagram] — the stress response: sympathetic system (adrenaline, fast) and HPA axis (cortisol, slower)
9. STEPS[flow] — hypothalamus → pituitary → adrenal glands → cortisol → feedback
10. STEPS[numbered] — Selye's general adaptation syndrome: alarm, resistance, exhaustion
11. CHART[illustrative] ⚑ — arousal vs performance, the "inverted U" (Yerkes–Dodson, 1908): how far it generalizes is debated
12. CMP — acute vs chronic stress effects
13. KEY — appraisal matters: reading arousal as "fuel" changes the response (stress-reappraisal studies)
14. STEPS[numbered] — coping with evidence: sleep, exercise, social support, reappraisal, problem-focused action
15. CHECK (2 Qs)
16. STEPS[numbered] — real example: exam week, step by step through the stress response and coping
17. TV[symbol] — why it matters: health, performance, relationships
18. RECAP
Candidate sources: OpenStax *Psychology 2e* ch. 10 & 14; NIMH, "I'm So Stressed Out!" fact sheet; Barrett et al. (2019) *Psychological Science in the Public Interest*.

**PSY-5 Social Influence & Persuasion (18)**
Goal: See how other people shape what we do through conformity, obedience and norms, and how persuasion works, so you can recognize it.
1. HOOK — which line matches? Everyone else just said the wrong one (Asch)
2. TV[shapes] — Asch's line-judgment setup; about a third of answers on critical trials conformed
3. CMP — informational influence (they might know better) vs normative influence (I want to fit in)
4. TV[diagram] — Milgram (1963): the setup, and 26 of 40 participants went to the end of the shock scale
5. CHART[sourced] — obedience across Milgram's variations (closeness to the victim, experimenter absent)
6. KEY ⚑ — reinterpretations of Milgram, and why the Stanford Prison Experiment is now heavily criticized
7. CHECK (2 Qs)
8. CMP — descriptive norms ("most guests reuse towels") vs injunctive norms ("you should")
9. TV[iconArray] ⚑ — the bystander effect (Darley & Latané 1968), and how the famous Kitty Genovese story was misreported
10. TV[diagram] — two routes to persuasion: central (arguments) vs peripheral (cues) (Petty & Cacioppo)
11. STEPS[numbered] — Cialdini's principles: reciprocity, commitment, social proof, authority, liking, scarcity
12. CHECK (2 Qs)
13. STEPS[numbered] — real example: taking apart a "Only 2 left! 140 people viewing" booking page
14. TV[diagram] — resisting: slow down, check who benefits, separate message from messenger
15. QUOTE — a short attributed line from Milgram (1974) on ordinary people
16. TV[symbol] — why it matters: cults, scams, workplaces, online crowds
17. TV[diagram] — the upside: norms also spread good behavior
18. RECAP
Candidate sources: OpenStax *Psychology 2e* ch. 12; Milgram (1963) *Journal of Abnormal and Social Psychology* & *Obedience to Authority* (1974); Cialdini, *Influence* (rev. 2021).

**PSY-6 How We Make Decisions (18)**
Goal: Compare the "rational chooser" model with how people actually decide, using expected value, prospect theory and choice architecture.
1. HOOK — $100 for sure, or a coin flip for $200?
2. TV[diagram] — anatomy of a decision: options, outcomes, probabilities, values
3. STEPS[numbered] — expected value, computed for the hook
4. TV[formula] — expected utility, and Bernoulli's (1738) idea that each extra dollar matters less
5. CHART[computed] — a diminishing-returns utility curve
6. TV[diagram] — bounded rationality and "satisficing" (Herbert Simon)
7. CHECK (2 Qs)
8. CHART[computed] — prospect theory (Kahneman & Tversky 1979): reference points and loss aversion
9. TV[diagram] — sunk-cost fallacy
10. CMP ⚑ — choice overload: the famous jam study vs a meta-analysis that found the average effect near zero
11. TV[iconArray] — defaults: organ-donor opt-in vs opt-out countries (Johnson & Goldstein 2003)
12. KEY ⚑ — "nudges" work sometimes; the size of the average effect is debated
13. TV[diagram] — emotion as an input to good decisions, not just noise
14. CHECK (2 Qs)
15. STEPS[numbered] — real example: choosing between two apartments with a weighted decision matrix
16. TV[diagram] — practical rules: decide what matters before seeing the options; beware the default
17. TV[symbol] — why it matters
18. RECAP
Candidate sources: Kahneman & Tversky (1979) *Econometrica*; Simon (1955) *Quarterly Journal of Economics*; Johnson & Goldstein (2003) *Science*; Thaler & Sunstein, *Nudge* (2008/2021).

### 18.2 Science & Technology (teal · `atom`)

**SCI-1 How the Brain Works (17)**
Goal: Tour the brain from single neurons and synapses up to regions and networks, and clear away common myths.
1. HOOK — about 86 billion neurons (Azevedo et al. 2009) [`bigNumber`]
2. TV[shapes] — a neuron: dendrites, cell body, axon, myelin, terminals
3. STEPS[flow] — an action potential: rest → threshold → sodium in → potassium out → reset
4. TV[diagram] — the synapse: neurotransmitters cross a gap and bind receptors
5. CMP — excitatory (glutamate) vs inhibitory (GABA) signals
6. CHECK (2 Qs)
7. TV[shapes] — map of the brain as shapes: four lobes, cerebellum, brainstem
8. TV[diagram] — two hemispheres and the corpus callosum; split-brain research (Sperry)
9. KEY ⚑ — myths: "left-brained vs right-brained people" and "we use 10% of our brain"
10. TV[iconArray] — the brain is about 2% of body mass but uses about 20% of resting energy
11. TV[diagram] — plasticity: London taxi drivers' hippocampi (Maguire et al. 2000)
12. CMP — how we study the brain: EEG (fast timing) vs fMRI (good location, measures blood oxygen indirectly)
13. CHECK (2 Qs)
14. STEPS[flow] — real example: catching a ball (eyes → visual cortex → planning → motor cortex → cerebellum correcting)
15. TV[diagram] — neurons → circuits → networks → behavior
16. TV[symbol] — why it matters: medicine, learning, AI
17. RECAP
Candidate sources: OpenStax *Psychology 2e* ch. 3; OpenStax *Anatomy & Physiology 2e* ch. 12–14; Azevedo et al. (2009) *Journal of Comparative Neurology*.

**SCI-2 Evolution & Genetics (18)**
Goal: Understand natural selection, how DNA carries inherited information, and how the two fit together.
1. HOOK — bacteria evolving antibiotic resistance, in real time
2. TL — Darwin & Wallace (1858), *Origin of Species* (1859), Mendel (1866), Mendel rediscovered (1900), modern synthesis (1930s–40s), DNA double helix (1953), human genome sequenced (2003; gap-free 2022)
3. STEPS[numbered] — natural selection: variation, inheritance, more offspring than survive, differential reproduction
4. CHART[illustrative] — a helpful gene variant spreading through a population over generations
5. QUOTE — Darwin, *On the Origin of Species* (1859, public domain), the closing "endless forms" line
6. CHECK (2 Qs)
7. TV[shapes] — Mendel's peas and a Punnett square
8. CMP — genotype vs phenotype; dominant vs recessive
9. STEPS[flow] — DNA → RNA → protein
10. TV[diagram] — mutations: the raw material, mostly neutral or harmful
11. TV[diagram] — beyond selection: genetic drift, gene flow, sexual selection
12. TV[shapes] — evidence: the same bones in a human arm, bat wing and whale flipper
13. KEY — evolution has no goal, and populations evolve, not individuals
14. CHECK (2 Qs)
15. STEPS[flow] — real example: how a resistant bacterial strain takes over during incomplete antibiotic use
16. TV[diagram] — the tree of life: common ancestry
17. TV[symbol] — why it matters: medicine, agriculture, conservation
18. RECAP
Candidate sources: OpenStax *Biology 2e* ch. 12, 14–15, 18–19; Darwin (1859); NHGRI (genome.gov) fact sheets; UC Berkeley, *Understanding Evolution*.

**SCI-3 Energy & the Laws of Physics (18)**
Goal: Grasp what energy is, why it's conserved, Newton's laws of motion and the laws of thermodynamics through everyday examples.
1. HOOK — why a dropped ball never bounces higher than where it started
2. TV[diagram] — energy: the capacity to do work, measured in joules
3. CMP — kinetic vs potential energy [`formula`: ½mv², mgh]
4. CHART[computed] — a pendulum: kinetic and potential trade off, total stays constant
5. KEY — conservation of energy: energy changes form but is never created or destroyed
6. STEPS[numbered] — Newton's three laws (*Principia*, 1687)
7. QUOTE — Newton's first law (1729 Motte translation, public domain)
8. TV[formula] — F = ma, worked through with a shopping cart
9. CHECK (2 Qs)
10. CMP — heat vs temperature
11. TV[diagram] — the second law: heat flows from hot to cold; entropy; why perpetual-motion machines fail
12. STEPS[flow] — a power plant: chemical → heat → motion → electricity, with losses at each step
13. TV[diagram] — the zeroth and third laws, briefly (equilibrium, absolute zero)
14. TV[formula] — E = mc² (1905): mass is a form of energy
15. CHECK (2 Qs)
16. STEPS[flow] — real example: a car braking (kinetic → heat), and regenerative braking recovering some of it
17. TV[symbol] — why it matters: engines, climate, your phone battery
18. RECAP
Candidate sources: OpenStax *University Physics* Vol. 1 (ch. 4–8) & Vol. 2 (ch. 1–4); Newton, *Principia* (1687; Motte 1729); *The Feynman Lectures on Physics* (Caltech, free online).

**SCI-4 How the Internet Works (18)**
Goal: Follow a web request from your phone to a server and back: packets, IP addresses, DNS, TCP and HTTPS.
1. HOOK — what happens in the second after you tap a link?
2. TV[diagram] — the internet is a network of networks
3. TL — ARPANET (1969), switch to TCP/IP (1 Jan 1983), World Wide Web proposed (1989) and public (1991), SSL/HTTPS (mid-1990s)
4. TV[diagram] — packet switching: a message split into packets that may take different routes
5. CMP — IPv4 (32-bit, about 4.3 billion addresses) vs IPv6 (128-bit)
6. TV[layers] — the layers: link, internet (IP), transport (TCP/UDP), application (HTTP)
7. CHECK (2 Qs)
8. STEPS[flow] — DNS lookup: resolver → root → TLD → authoritative server
9. CMP — TCP (reliable, ordered) vs UDP (fast, no guarantees)
10. STEPS[numbered] — the TCP handshake: SYN, SYN-ACK, ACK
11. TV[diagram] — routers and BGP: networks announcing routes to each other
12. TV[diagram] — HTTPS/TLS: encryption plus certificates that prove who you're talking to
13. TV[shapes] — the physical internet: undersea cables carry most traffic between continents
14. CHECK (2 Qs)
15. STEPS[numbered] — real example: loading a web page, end to end, step by step
16. KEY — no one runs the internet; it works because everyone agrees on open protocols
17. TV[symbol] — why it matters: privacy, outages, censorship
18. RECAP
Candidate sources: RFC 791 (IP), RFC 9293 (TCP), RFC 1034/1035 (DNS); Kurose & Ross, *Computer Networking: A Top-Down Approach*; Internet Society, "Brief History of the Internet".

**SCI-5 How AI & Language Models Work (18)**
Goal: Understand machine learning and neural networks, how large language models generate text by predicting tokens, and their limits.
1. HOOK — "autocomplete, scaled up enormously": what that means and what it leaves out
2. CMP — traditional programming (write the rules) vs machine learning (learn from examples)
3. TL — Turing's "imitation game" (1950), Dartmouth workshop (1956), perceptron (1958), backpropagation popularized (1986), deep-learning breakthrough (2012), Transformer (2017), ChatGPT (2022)
4. TV[diagram] — a neural network: inputs, weighted connections, layers, outputs
5. STEPS[cycle] — training: predict → measure error → adjust weights (gradient descent) → repeat
6. CHART[illustrative] — loss falling during training
7. CHECK (2 Qs)
8. TV[shapes] — tokens: text cut into pieces
9. CHART[illustrative] — next-token probabilities for "The capital of France is…"
10. TV[shapes] — embeddings: words as points, with similar meanings close together
11. TV[diagram] — attention: each token weighs every other token (Vaswani et al. 2017)
12. STEPS[flow] — pretraining → fine-tuning → learning from human feedback
13. KEY — limits: confident errors ("hallucinations"), training cutoffs, biases from data
14. KEY ⚑ — whether these models "understand" anything is an open debate
15. CHECK (2 Qs)
16. STEPS[numbered] — real example: one question going through a chatbot, token by token
17. TV[symbol] — why it matters: how to use these tools well and check their output
18. RECAP
Candidate sources: Vaswani et al. (2017), "Attention Is All You Need"; Russell & Norvig, *AI: A Modern Approach* (4th ed.); Jurafsky & Martin, *Speech and Language Processing* (3rd ed. draft, free online); Turing (1950) *Mind*.

**SCI-6 The Scientific Method (18)**
Goal: Learn how science builds reliable knowledge (hypotheses, controlled tests, statistics, peer review) and why replication matters.
1. HOOK — 1847: a doctor asks colleagues to wash their hands, and deaths fall (Semmelweis)
2. TV[diagram] — science as testable explanations about the natural world
3. STEPS[cycle] — observe → question → hypothesis → predict → test → analyze → share, as a loop rather than a straight line
4. KEY — falsifiability: a good hypothesis says what would prove it wrong (Popper)
5. CMP — correlation vs causation
6. TV[diagram] — controlled experiments: independent and dependent variables, control groups
7. TV[iconArray] — randomization, placebo and double-blinding
8. CHECK (2 Qs)
9. TV[diagram] — sample size, and what a p-value does and doesn't mean
10. STEPS[flow] — peer review and publication
11. CHART[sourced] — the 2015 reproducibility project: about 97% of original psychology studies significant vs about 36% of replications
12. KEY ⚑ — the replication crisis: causes and fixes (preregistration, open data) are still debated
13. TL — Bacon's *Novum Organum* (1620), Royal Society (1660), Popper (1934), Kuhn's *Structure of Scientific Revolutions* (1962)
14. QUOTE — Bacon (1620, public domain) on testing ideas against nature
15. CHECK (2 Qs)
16. STEPS[numbered] — real example: Semmelweis's comparison of two clinics, why he was resisted, and the later germ theory
17. TV[symbol] — why it matters: medicine, policy, reading the news
18. RECAP
Candidate sources: Open Science Collaboration (2015) *Science*; Stanford Encyclopedia of Philosophy, "Karl Popper" and "Scientific Method"; UC Berkeley, *Understanding Science*; Encyclopaedia Britannica, "Ignaz Semmelweis".

### 18.3 Finance & Business (ochre · `chart.line.uptrend.xyaxis`)
Finance lessons show a one-line "educational, not financial advice" note.

**FIN-1 Money, Interest & Compounding (18)**
Goal: Understand what money is, how simple and compound interest work, and why time is the most powerful variable.
1. HOOK — $1,000 at 7% a year for 40 years is about $14,974 [`bigNumber`, computed]
2. TV[diagram] — money's three jobs: medium of exchange, unit of account, store of value
3. TL ⚑ — a short history of money: early coins in Lydia, Chinese paper money, Bretton Woods (1944), the end of dollar–gold convertibility (1971); the "barter came first" story is disputed by anthropologists
4. KEY — interest is the price of using money over time
5. CMP — simple vs compound interest
6. CHART[computed] — simple vs compound over 40 years
7. TV[formula] — A = P(1 + r/n)^(nt), each part labeled
8. CHECK (2 Qs)
9. TV[formula] — the rule of 72: a quick estimate of doubling time
10. CHART[computed] — starting at 20 vs at 30 with the same monthly deposits
11. TV[bigNumber] — compounding against you: typical credit-card interest rates (Federal Reserve data)
12. CMP — APR vs APY
13. TV[diagram] — inflation eats into real returns (links to FIN-6)
14. CHECK (2 Qs)
15. CHART[computed] — real example: paying a credit-card balance at the minimum vs a fixed higher payment
16. STEPS[numbered] — what to do with this: high-interest debt first, start early, automate
17. TV[symbol] — why it matters
18. RECAP
Candidate sources: SEC Investor.gov (compound interest); Consumer Financial Protection Bureau (APR); OpenStax *Principles of Finance* ch. 7–8; Federal Reserve G.19 consumer credit release.

**FIN-2 How the Stock Market Works (19)**
Goal: Learn what a share is, how exchanges match buyers and sellers, what moves prices, and why diversification and index funds matter.
1. HOOK — owning a sliver of a company you use every day
2. TV[shapes] — what a share is: a claim on profits, plus votes
3. TL — Dutch East India Company shares (1602), Buttonwood Agreement (1792), crash of 1929, SEC created (1934), first retail index fund (1976), 2008 crisis
4. STEPS[flow] — going public: private company → IPO → trading
5. TV[diagram] — the order book: bids, asks, spread, matching
6. TV[formula] — market cap = share price × shares outstanding
7. CHECK (2 Qs)
8. TV[diagram] — what moves prices: expectations about future profits, and news changing those expectations
9. CMP — stocks vs bonds (ownership vs loan; risk vs steadiness)
10. CMP — price-weighted (the Dow) vs market-cap-weighted (the S&P 500) indexes
11. CHART[illustrative] — portfolio ups and downs shrinking as you add more stocks
12. KEY — diversification: don't let one company sink you
13. CHART[sourced] — share of actively managed funds that trailed their index over 15 years (SPIVA scorecard)
14. KEY ⚑ — how "efficient" markets are is debated; Fama and Shiller shared the 2013 economics Nobel with opposing views
15. CHECK (2 Qs)
16. STEPS[numbered] — real example: what happens when you tap "Buy" in a brokerage app
17. TV[diagram] — risks: volatility, fees, emotional trading
18. TV[symbol] — why it matters
19. RECAP
Candidate sources: SEC Investor.gov, "Stocks" and "Index Funds"; S&P Dow Jones Indices, SPIVA U.S. Scorecard; OpenStax *Principles of Finance* ch. 10–11, 14–15.

**FIN-3 Reading Financial Statements (17)**
Goal: Read an income statement, balance sheet and cash-flow statement, and see how the three connect.
1. HOOK — a profitable company can still run out of cash
2. TV[diagram] — who reads these statements and why; GAAP and IFRS rules
3. TV[diagram] — the three statements and the arrows between them
4. STEPS[flow] — income statement: revenue → cost of goods → gross profit → operating expenses → operating income → interest and taxes → net income
5. CHART[illustrative] — a waterfall chart for a fictional coffee shop
6. KEY — the accounting equation: assets = liabilities + equity
7. TV[shapes] — the balance sheet as a balanced scale
8. CHECK (2 Qs)
9. CMP — accrual accounting vs cash accounting
10. STEPS[numbered] — cash-flow statement: operating, investing, financing
11. TV[diagram] — how they link: net income → retained earnings; ending cash → balance sheet
12. TV[formula] — four ratios: gross margin, net margin, current ratio, debt-to-equity
13. CHECK (2 Qs)
14. TV[layers] — real example: headline figures from a real public company's annual report (10-K), read top to bottom, with figures taken from SEC EDGAR
15. TV[diagram] — warning signs: profits rising while operating cash falls
16. TV[symbol] — why it matters: jobs, investing, starting a business
17. RECAP
Candidate sources: OpenStax *Principles of Accounting* Vol. 1 ch. 2–5; SEC, "Beginners' Guide to Financial Statements"; the chosen company's 10-K on SEC EDGAR.

**FIN-4 Business Strategy & Competitive Advantage (17)**
Goal: Understand what strategy is, use Porter's five forces, and recognize the sources of lasting advantage ("moats").
1. HOOK — why some companies keep high profits for decades and most don't
2. KEY — strategy is choosing where to play and how to win, and what *not* to do
3. CMP — operational effectiveness vs strategic positioning (Porter 1996)
4. TV[diagram] — five forces: rivalry, new entrants, substitutes, buyer power, supplier power (Porter 1979)
5. STEPS[numbered] — the five forces applied to airlines
6. CHECK (2 Qs)
7. CMP — cost leadership vs differentiation
8. TV[diagram] — moats: network effects, switching costs, economies of scale, brand, patents
9. CHART[computed] — network effects: connections grow as n(n−1)/2
10. TV[diagram] — VRIO: valuable, rare, hard to imitate, organized to capture (Barney 1991)
11. TV[diagram] ⚑ — disruptive innovation (Christensen 1997) and critiques of how well it predicts
12. TV[diagram] — real example: Southwest Airlines' activity system, where the choices reinforce each other (Porter 1996)
13. STEPS[numbered] — why rivals couldn't simply copy Southwest
14. CHECK (2 Qs)
15. STEPS[numbered] — a quick strategy check for any business: forces, position, moat
16. TV[symbol] — why it matters: careers, investing, founding
17. RECAP
Candidate sources: Porter, "How Competitive Forces Shape Strategy" (HBR 1979) and "What Is Strategy?" (HBR 1996); Barney (1991) *Journal of Management*; OpenStax *Principles of Management* ch. 8.

**FIN-5 Startups & Unit Economics (19)**
Goal: Learn how startups differ from small businesses, and judge a business model with unit economics: CAC, LTV, contribution margin, burn and runway.
1. HOOK — selling more can make you lose more money
2. CMP — startup (built to grow fast) vs small business (built to be steady)
3. STEPS[flow] — funding stages: bootstrapping → pre-seed/seed → Series A, B, C → IPO or acquisition
4. TV[shapes] — equity and dilution: founder ownership across rounds (computed)
5. CHECK (2 Qs)
6. KEY — unit economics: do you make money on each customer?
7. TV[formula] — contribution margin = price − variable costs
8. TV[formula] — CAC: marketing and sales spend ÷ new customers
9. TV[formula] — LTV: revenue per month × margin ÷ monthly churn
10. CHART[computed] ⚑ — LTV vs CAC; the "3:1" rule is a common rule of thumb, not a law
11. TV[formula] — payback period
12. TV[formula] — burn rate and runway
13. CHART[computed] — cash in the bank, month by month, until zero
14. TV[diagram] — product–market fit: what it looks like when it's there
15. CHECK (2 Qs)
16. STEPS[numbered] — real example: a subscription study app's unit economics (made-up numbers, labeled as such)
17. CHART[sourced] — how many new businesses survive 1, 5 and 10 years (Bureau of Labor Statistics)
18. TV[symbol] — why it matters
19. RECAP
Candidate sources: U.S. Bureau of Labor Statistics, Business Employment Dynamics (establishment survival); OpenStax *Entrepreneurship* ch. 9–10; Y Combinator Startup School library (free).

**FIN-6 Inflation, Interest Rates & the Economy (18)**
Goal: Understand how inflation is measured, what causes it, and how central banks use interest rates to steer the economy.
1. HOOK — U.S. consumer prices rose about 9% in the year to June 2022 [`bigNumber`, BLS]
2. TV[diagram] — inflation is a general rise in prices, which means each dollar buys less
3. STEPS[numbered] — how the CPI is built: a basket of goods, prices, weights, an index
4. CHART[sourced] — U.S. annual CPI inflation since 2000 (BLS)
5. CMP — demand-pull vs cost-push inflation
6. TV[formula] ⚑ — MV = PQ; how tightly money supply drives prices is debated
7. CHECK (2 Qs)
8. TV[diagram] — the Federal Reserve's dual mandate (maximum employment, stable prices) and its 2% target
9. STEPS[flow] — how a rate hike works: policy rate → loan rates → spending → prices, with long lags
10. CMP — nominal vs real interest rates
11. TL — the Great Inflation of the 1970s, the Volcker rate hikes (1979–82), near-zero rates after 2008, hikes from 2022
12. TV[diagram] ⚑ — the Phillips curve: the inflation–unemployment trade-off, and why it seems weaker than once thought
13. TV[bigNumber] — hyperinflation: Germany (1923) and Zimbabwe (2008)
14. CHECK (2 Qs)
15. CHART[computed] — real example: the monthly payment on a 30-year mortgage at different rates
16. TV[diagram] — what it means for you: savings, loans, wages
17. TV[symbol] — why it matters
18. RECAP
Candidate sources: U.S. Bureau of Labor Statistics, CPI; Federal Reserve, "Monetary Policy" pages; OpenStax *Principles of Macroeconomics 3e* ch. 22 & 28; FRED (St. Louis Fed).

### 18.4 History (plum · `scroll`)

**HIS-1 The Agricultural Revolution & First Civilizations (18)**
Goal: Understand how farming began independently in several regions and how it led to cities, writing and states.
1. HOOK — for more than 95% of our species' existence, everyone lived by foraging [computed from dates, cited]
2. TV[shapes] — forager life: small, mobile groups
3. TL — farming begins: Fertile Crescent (around 12,000 years ago), then China, Mesoamerica, the Andes, New Guinea and others
4. TV[shapes] — a world map as shapes: independent centers of domestication
5. STEPS[numbered] ⚑ — why farming? Competing explanations (warming climate after the Ice Age, population pressure, feasting)
6. CMP ⚑ — foragers vs early farmers: more food and people, but often worse health; the "worst mistake" argument and its critics
7. CHECK (2 Qs)
8. STEPS[flow] — surplus → specialists → inequality → rulers
9. TV[shapes] ⚑ — Göbekli Tepe: monumental building by foragers, and the debate over which came first
10. TV[shapes] — Uruk: one of the first cities
11. TV[diagram] — writing invented for accounting: Mesopotamian cuneiform, Egyptian hieroglyphs, and later independent inventions in China and Mesoamerica
12. TL — early civilizations: Mesopotamia, Egypt (unified around 3100 BCE), the Indus Valley, Shang China
13. QUOTE — Code of Hammurabi, law 196 ("eye for an eye"), 1910 L. W. King translation (public domain)
14. CHECK (2 Qs)
15. STEPS[numbered] — real example: a clay tablet recording grain rations, read step by step
16. TV[diagram] — the legacy: states, taxes, laws, social classes
17. TV[symbol] — why it matters
18. RECAP
Candidate sources: OpenStax *World History* Vol. 1 ch. 1–3; Encyclopaedia Britannica, "Neolithic" and "Mesopotamia"; Smithsonian National Museum of Natural History, Human Origins.

**HIS-2 Rise and Fall of Rome (18)**
Goal: Trace Rome from a small city to a republic to an empire, see what held it together, and weigh the debated reasons the Western Empire fell.
1. HOOK — one state, more than a thousand years
2. TL — founding legend (753 BCE), Republic (509 BCE), Punic Wars (264–146 BCE), Caesar killed (44 BCE), Augustus (27 BCE), largest extent (117 CE), split East/West, Constantinople founded (330), sack of Rome (410), last Western emperor deposed (476), Constantinople falls (1453)
3. TV[diagram] — how the Republic worked: consuls, Senate, assemblies, tribunes
4. CMP — Republic vs Empire
5. TV[shapes] — map as shapes: the territory in 3 snapshots
6. CHECK (2 Qs)
7. TV[diagram] — what held it together: roads, law, army, citizenship
8. TL — the Crisis of the Third Century (235–284)
9. STEPS[numbered] — reforms: Diocletian's tetrarchy, Constantine and Christianity
10. TV[diagram] ⚑ — why the West fell: migrations and invasions, money, civil wars, disease, climate; historians weigh them differently
11. CMP ⚑ — "fall" vs "transformation": two schools of interpretation
12. QUOTE — Edward Gibbon, *Decline and Fall of the Roman Empire* (1776–89, public domain)
13. CHECK (2 Qs)
14. STEPS[numbered] — real example: the sack of Rome in 410, and why it shocked the Roman world
15. TV[shapes] — the East carried on for another thousand years (the Byzantine Empire)
16. TV[diagram] — the legacy: law, Latin and the Romance languages, ideas of a republic
17. TV[symbol] — why it matters
18. RECAP
Candidate sources: OpenStax *World History* Vol. 1 ch. 6–7; Encyclopaedia Britannica, "Ancient Rome"; Gibbon (1776–89); Mary Beard, *SPQR* (2015).

**HIS-3 The Scientific Revolution & Enlightenment (18)**
Goal: See how observation, experiment and mathematics overturned old views of nature, and how confidence in reason spread into politics.
1. HOOK — in 1600, most educated Europeans believed the Earth stood still at the center of everything
2. CMP — Earth-centered (Ptolemy) vs Sun-centered (Copernicus, 1543) models
3. TL — Copernicus (1543), Kepler (1609), Galileo's telescope (1610), Bacon (1620), Galileo's trial (1633), Descartes (1637), Royal Society (1660), Newton's *Principia* (1687), Locke (1689), *Encyclopédie* (from 1751), Kant's essay (1784), French Revolution (1789)
4. TV[shapes] — what Galileo saw: Jupiter's moons and the phases of Venus
5. TV[shapes] — Kepler's ellipses
6. TV[diagram] — Newton's synthesis: one law for a falling apple and the orbiting Moon
7. CHECK (2 Qs)
8. CMP — Bacon's induction vs Descartes' deduction
9. TV[diagram] ⚑ — the Galileo affair: more complicated than "science vs religion"
10. KEY — the Enlightenment: use reason to examine society, not just nature
11. TV[diagram] — the big ideas: natural rights (Locke), separation of powers (Montesquieu), social contract (Rousseau), toleration (Voltaire)
12. QUOTE — Kant (1784, public domain): "Sapere aude!", have courage to use your own understanding
13. TV[diagram] — into politics: the American Declaration (1776) and the French Declaration of the Rights of Man (1789)
14. TV[diagram] — its blind spots: slavery, and women's exclusion (Wollstonecraft, 1792)
15. CHECK (2 Qs)
16. STEPS[numbered] — real example: Halley's comet, predicted with Newton's laws to return in 1758, and it did
17. TV[symbol] — why it matters
18. RECAP
Candidate sources: OpenStax *World History* Vol. 2; Stanford Encyclopedia of Philosophy, "Enlightenment"; Encyclopaedia Britannica, "Scientific Revolution"; Kant, "What Is Enlightenment?" (1784).

**HIS-4 The Industrial Revolution (18)**
Goal: Explain why industrialization began in Britain, how steam, factories and railways changed work and life, and its mixed consequences.
1. HOOK — for most of history, living standards barely changed; then growth took off
2. CHART[sourced] — GDP per person over centuries (Maddison Project)
3. TV[diagram] ⚑ — why Britain first? Coal, high wages, capital, institutions; historians weigh these differently
4. TL — Newcomen engine (1712), spinning jenny (1760s), Arkwright's water frame (1769), Watt's separate condenser (1769), railways (1825, 1830), Factory Act (1833), Great Exhibition (1851), Second Industrial Revolution (around 1870–1914)
5. STEPS[flow] — how a steam engine works, and Watt's improvement
6. TV[diagram] — the factory system and division of labor
7. QUOTE — Adam Smith on the pin factory, *Wealth of Nations* (1776, public domain)
8. CHECK (2 Qs)
9. TV[iconArray] — urbanization: people moving from farms to cities
10. TV[diagram] — working conditions, child labor and the Factory Acts
11. CMP ⚑ — the standard-of-living debate: optimists vs pessimists
12. TV[shapes] — industrialization spreads: Belgium, the U.S., Germany, Japan
13. TV[diagram] — the second wave: steel, electricity, chemicals
14. TV[diagram] — the environmental bill: coal, smoke, the start of the rise in CO₂
15. CHECK (2 Qs)
16. STEPS[numbered] — real example: making cotton cloth by hand vs in a mill, step by step
17. TV[symbol] — why it matters: the world we live in started here
18. RECAP
Candidate sources: OpenStax *World History* Vol. 2; Robert C. Allen, *The British Industrial Revolution in Global Perspective* (2009); Maddison Project Database; Smith (1776).

**HIS-5 The World Wars (18)**
Goal: Understand the causes, turning points and consequences of both world wars, and how the second grew out of the first.
1. HOOK — two world wars within 31 years (1914–1945)
2. TV[diagram] — causes of WWI: alliances, militarism, imperialism, nationalism; the spark of 28 June 1914
3. TL — WWI: July Crisis (1914), Verdun and the Somme (1916), U.S. entry and Russian revolutions (1917), armistice (11 Nov 1918), Versailles (1919)
4. TV[shapes] — trench warfare
5. TV[diagram] ⚑ — the Treaty of Versailles: how harsh was it really? Historians disagree
6. CHECK (2 Qs)
7. CHART[sourced] — Nazi vote share, 1928 vs 1932 (a fringe party to the largest party)
8. TL — WWII: Poland (1939), fall of France (1940), invasion of the USSR and Pearl Harbor (1941), Midway and Stalingrad (1942–43), D-Day (1944), Germany surrenders (May 1945), atomic bombs and Japan's surrender (Aug–Sep 1945)
9. TV[shapes] — map as shapes: Axis-held Europe at its height
10. TV[iconArray] — the Holocaust: about six million Jews murdered, along with Roma, disabled people and others
11. KEY — turning points: Stalingrad, Midway, and industrial output
12. CHART[sourced] ⚑ — estimated deaths in each war, with ranges, since estimates vary
13. CHECK (2 Qs)
14. TV[diagram] — after 1945: the United Nations, the Universal Declaration of Human Rights (1948), decolonization, two superpowers
15. QUOTE — opening of the UN Charter preamble (1945)
16. STEPS[flow] — real example: how defeat, a treaty and a depression helped a fringe party reach power
17. TV[symbol] — why it matters
18. RECAP
Candidate sources: OpenStax *World History* Vol. 2; United States Holocaust Memorial Museum, *Holocaust Encyclopedia*; Imperial War Museums; Encyclopaedia Britannica, "World War I" and "World War II".

**HIS-6 The Cold War (18)**
Goal: Follow the U.S.–Soviet rivalry from 1945 to 1991 (ideology, nuclear deterrence, proxy wars, the space race) and how it ended.
1. HOOK — a 45-year war in which the two main rivals never fought each other directly
2. CMP — two systems: market democracy vs one-party communism
3. TL — Iron Curtain speech (1946), Truman Doctrine and Marshall Plan (1947–48), Berlin Airlift (1948–49), NATO (1949), Korea (1950–53), Sputnik (1957), Berlin Wall (1961), Cuban Missile Crisis (1962), Moon landing (1969), SALT I (1972), Afghanistan (1979), Wall falls (9 Nov 1989), USSR dissolves (26 Dec 1991)
4. TV[shapes] — map as shapes: a divided Europe and a divided Berlin
5. TV[diagram] — containment (Kennan)
6. CHECK (2 Qs)
7. TV[diagram] — the nuclear arms race and "mutually assured destruction"
8. CHART[sourced] — U.S. and Soviet nuclear stockpiles over time (Federation of American Scientists)
9. STEPS[numbered] — thirteen days: the Cuban Missile Crisis, day by day (Oct 1962)
10. TV[shapes] — proxy wars: Korea, Vietnam, Afghanistan
11. TL — the space race: Sputnik, Gagarin, Apollo 11
12. QUOTE — Churchill, 1946, "an iron curtain has descended across the Continent"
13. TV[diagram] — détente and arms control
14. TV[diagram] ⚑ — why it ended: Soviet economic trouble, Gorbachev's reforms, the 1989 revolutions, Western pressure; historians weigh these differently
15. CHECK (2 Qs)
16. STEPS[numbered] — real example: the night the Berlin Wall opened (9 Nov 1989)
17. TV[symbol] — why it matters: NATO, nuclear arsenals and today's rivalries
18. RECAP
Candidate sources: U.S. Department of State, Office of the Historian (history.state.gov); OpenStax *U.S. History* ch. 28–32; Federation of American Scientists, "Status of World Nuclear Forces"; John Lewis Gaddis, *The Cold War: A New History* (2005).

### 18.5 Philosophy (indigo · `building.columns`)

**PHI-1 What Philosophy Is & the Socratic Method (17)**
Goal: Learn what philosophy studies and its main branches, and use Socratic questioning and basic logic to test ideas.
1. HOOK — "What is justice?" Give an answer, then get questioned
2. TV[symbol] — "philosophy" from the Greek for love of wisdom
3. TV[diagram] — the branches: metaphysics, epistemology, ethics, logic, aesthetics, political philosophy
4. CMP — philosophy vs science: questions experiments alone can't settle
5. TV[shapes] — Socrates (c. 470–399 BCE): wrote nothing; known through Plato and Xenophon
6. STEPS[cycle] — the Socratic method: claim → question → contradiction → better claim
7. QUOTE — Plato, *Apology* 38a, "the unexamined life is not worth living" (Jowett translation, public domain)
8. CHECK (2 Qs)
9. TV[diagram] — the Euthyphro dilemma: is something good because the gods love it, or do they love it because it's good?
10. CMP — valid vs sound arguments
11. STEPS[flow] — a valid form: modus ponens
12. TV[diagram] — three fallacies: straw man, ad hominem, false dilemma
13. TV[diagram] — Socratic wisdom: knowing what you don't know, and the trial of 399 BCE
14. CHECK (2 Qs)
15. STEPS[numbered] — real example: questioning "you should always follow your passion" Socratically
16. TV[symbol] — why it matters: clearer thinking in every field
17. RECAP
Candidate sources: Stanford Encyclopedia of Philosophy, "Socrates"; Internet Encyclopedia of Philosophy, "Fallacies"; Plato, *Apology* and *Euthyphro* (Jowett translation, Project Gutenberg).

**PHI-2 Stoicism (18)**
Goal: Understand the Stoics' core ideas (virtue as the only true good, the dichotomy of control, emotions as judgments) and how they're practiced.
1. HOOK — a former slave, an emperor and a statesman shared one philosophy
2. TL — Zeno founds the school in Athens (c. 300 BCE, at the "painted porch"), Chrysippus, Seneca (c. 4 BCE–65 CE), Epictetus (c. 50–135), Marcus Aurelius (emperor 161–180)
3. KEY — virtue is the only true good; health, wealth and reputation are "indifferents"
4. TV[diagram] — four cardinal virtues: wisdom, courage, justice, temperance
5. TV[shapes] — the dichotomy of control: two circles
6. QUOTE — Epictetus, *Enchiridion* ch. 1 (public-domain translation)
7. CHECK (2 Qs)
8. TV[diagram] — emotions as judgments; harmful passions vs healthy feelings
9. STEPS[numbered] — practices: imagining setbacks in advance, the "view from above", the evening review (Seneca)
10. QUOTE — Marcus Aurelius, *Meditations* (George Long translation, public domain)
11. TV[diagram] — living "according to nature" and the Stoic idea of world citizenship
12. TV[diagram] — the Stoic influence on cognitive behavioral therapy, which its founders acknowledged
13. CMP — Stoicism vs being "stoic" (suppressing feelings), a common misunderstanding
14. KEY ⚑ — critiques: too passive about injustice? Is modern self-help Stoicism faithful to the original?
15. CHECK (2 Qs)
16. STEPS[numbered] — real example: a cancelled flight, handled with the dichotomy of control
17. TV[symbol] — why it matters
18. RECAP
Candidate sources: Stanford Encyclopedia of Philosophy, "Stoicism"; Internet Encyclopedia of Philosophy, "Stoicism"; Epictetus, *Enchiridion* (public-domain translation); Marcus Aurelius, *Meditations* (Long translation).

**PHI-3 Ethics: Utilitarianism, Kant & Virtue (18)**
Goal: Compare the three major ethical theories by applying each to the same dilemmas and seeing where they agree and clash.
1. HOOK — the trolley problem (Foot 1967; Thomson)
2. TV[diagram] — what ethics asks: what should I do, and how should I live?
3. TV[layers] — metaethics, normative ethics, applied ethics
4. TV[diagram] — utilitarianism: the greatest happiness (Bentham, Mill)
5. QUOTE — Mill, *Utilitarianism* (1863, public domain), the "greatest happiness principle"
6. CHART[illustrative] — adding up happiness across everyone affected
7. CHECK (2 Qs)
8. TV[diagram] — Kant's categorical imperative: universal law, and treating people as ends (1785)
9. STEPS[numbered] — the universalizability test applied to a lying promise
10. TV[shapes] — virtue ethics: Aristotle's mean (courage between cowardice and recklessness)
11. CMP — the three theories side by side (3 columns): what matters, how to decide, key thinker
12. TV[diagram] — the trolley vs the footbridge: what each theory says
13. KEY — the classic objection to each: the transplant surgeon, the murderer at the door, "what should I actually do?"
14. CHART[sourced] ⚑ — no consensus: how professional philosophers lean (PhilPapers 2020 survey)
15. CHECK (2 Qs)
16. STEPS[numbered] — real example: should an employee blow the whistle? All three theories applied
17. TV[symbol] — why it matters
18. RECAP
Candidate sources: Stanford Encyclopedia of Philosophy, "Consequentialism", "Kant's Moral Philosophy", "Virtue Ethics"; Mill (1863); Bourget & Chalmers (2023), "Philosophers on Philosophy: The 2020 PhilPapers Survey".

**PHI-4 Free Will vs Determinism (18)**
Goal: Map the free-will debate (determinism, libertarianism, compatibilism) and what neuroscience does and doesn't show.
1. HOOK — did you choose to open this lesson?
2. TV[diagram] — what's at stake: responsibility, praise, blame, punishment
3. KEY — determinism: every event follows from earlier causes plus the laws of nature
4. QUOTE — Laplace's "demon", *A Philosophical Essay on Probabilities* (1814; 1902 translation, public domain)
5. TV[diagram] — the map: incompatibilism (hard determinism, libertarianism) vs compatibilism
6. TV[diagram] — hard determinism: no free will, so rethink blame
7. TV[diagram] — libertarian free will: agents as true starting points
8. TV[diagram] — compatibilism: free means acting on your own reasons without coercion (Hume; Frankfurt's 1969 cases)
9. CHECK (2 Qs)
10. TV[diagram] — quantum randomness doesn't obviously help: random isn't the same as in control
11. TL ⚑ — Libet (1983): brain activity seems to come before the felt decision; later work (Schurger et al. 2012) challenges what that means
12. TV[diagram] — responsibility without metaphysics: reactive attitudes (P. F. Strawson 1962)
13. CHART[sourced] — what philosophers think (PhilPapers 2020): most lean compatibilist
14. KEY ⚑ — the debate is unresolved
15. CHECK (2 Qs)
16. STEPS[numbered] — real example: a man whose behavior changed with a brain tumor and returned to normal after surgery (Burns & Swerdlow 2003). Who was responsible?
17. TV[symbol] — why it matters: law, punishment, how we treat ourselves
18. RECAP
Candidate sources: Stanford Encyclopedia of Philosophy, "Free Will", "Compatibilism", "Causal Determinism"; Libet et al. (1983) *Brain*; Bourget & Chalmers (2023).

**PHI-5 Existentialism (18)**
Goal: Understand existentialism's core claims (existence precedes essence, radical freedom, anxiety, authenticity, the absurd) through its key thinkers.
1. HOOK — no one hands you a meaning. Now what?
2. TL — Kierkegaard (1813–55), Nietzsche (1844–1900), Heidegger's *Being and Time* (1927), Camus's *Myth of Sisyphus* (1942), Sartre's *Being and Nothingness* (1943) and "Existentialism Is a Humanism" (1945 lecture), Beauvoir's *The Second Sex* (1949)
3. KEY — "existence precedes essence" (Sartre)
4. CMP — a paper knife (designed for a purpose first) vs a human (exists first, defines itself after): Sartre's example
5. TV[diagram] — radical freedom and responsibility: "condemned to be free"
6. TV[shapes] — anxiety as the "dizziness of freedom" (Kierkegaard)
7. CHECK (2 Qs)
8. TV[shapes] — bad faith: Sartre's café waiter
9. TV[diagram] — authenticity: owning your choices
10. QUOTE — Nietzsche, *The Gay Science* §125, "God is dead" in context (public-domain translation)
11. TV[diagram] — Nietzsche: creating values rather than inheriting them
12. TV[shapes] ⚑ — Camus and the absurd: Sisyphus pushing his rock; Camus himself rejected the "existentialist" label
13. QUOTE — Beauvoir (1949): "One is not born, but rather becomes, a woman" (short, attributed)
14. CHECK (2 Qs)
15. STEPS[numbered] — real example: choosing a major, applying existentialist ideas
16. TV[diagram] — criticisms: too individualistic? Too bleak?
17. TV[symbol] — why it matters
18. RECAP
Candidate sources: Stanford Encyclopedia of Philosophy, "Existentialism"; Internet Encyclopedia of Philosophy, "Existentialism"; Sartre, *Existentialism Is a Humanism* (Yale UP, 2007 translation).

**PHI-6 What Can We Know? (Epistemology) (18)**
Goal: Explore what knowledge is, the Gettier problem, skepticism, and how rationalists and empiricists answer "how do we know?"
1. HOOK — a stopped clock that happens to be right: do you *know* the time? (Russell)
2. TV[symbol] — epistemology: the theory of knowledge
3. KEY — the classic definition: knowledge = justified true belief (from Plato's *Theaetetus*)
4. TV[shapes] — a three-circle Venn diagram: belief, truth, justification
5. TV[diagram] — Gettier's 1963 counterexamples: justified, true, and still not knowledge
6. CHECK (2 Qs)
7. CMP — rationalism (reason first: Descartes) vs empiricism (experience first: Locke, Hume)
8. STEPS[numbered] — Descartes' method of doubt: the senses, dreaming, the evil demon, "I think, therefore I am"
9. QUOTE — Descartes, *Discourse on the Method* (1637, public-domain translation)
10. TV[diagram] — Hume's problem of induction: why expect the sun to rise tomorrow?
11. TV[shapes] — Kant's 2×2: analytic/synthetic × a priori/a posteriori
12. TV[shapes] — modern skepticism: the brain in a vat (Putnam)
13. CMP — foundationalism vs coherentism
14. KEY ⚑ — after Gettier, there's still no agreed definition of knowledge
15. CHECK (2 Qs)
16. STEPS[numbered] — real example: a viral health claim, and how you'd actually come to know whether it's true
17. TV[symbol] — why it matters: science, news and AI-generated content
18. RECAP
Candidate sources: Stanford Encyclopedia of Philosophy, "Epistemology" and "The Analysis of Knowledge"; Gettier (1963) *Analysis*; Descartes, *Meditations* / *Discourse* (public-domain translations); Hume, *Enquiry Concerning Human Understanding* (public domain).

---

*End of spec. On your approval, Step 1 starts with the Xcode project, LessonKit, the loader and validator, the renderer for all section types, and the first five lessons: PSY-1, SCI-4, FIN-1, HIS-2, PHI-2.*
