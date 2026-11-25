# Strata

A personal app that teaches five topics through long, visual scroll lessons. Diagrams draw themselves as you scroll, quiz checks sit along the way, and spaced review plus a daily streak bring you back. The design is in [SPEC.md](SPEC.md).

**Status:** the **website** in `web/` has Steps 1–4: five lessons (one per topic), all section types, inline checks and final quiz, resume, Leitner review, streak with weekly freeze, daily goal, Home, topic pages and the You tab. It works offline after the first visit. The **iPhone app** code (`App/`, SwiftUI) is from Step 1 and hasn't been run yet; it needs Xcode. Both read the same lesson files in `Content/`. SPEC.md §0.6 lists how the website differs from the iPhone spec.

## Use it online

**https://mpdenker.github.io/strata/** (GitHub Pages, free, HTTPS). Open it once in Safari on your iPhone, then Share → Add to Home Screen. After that first visit it works offline, including all lessons. Progress is saved separately in each browser, so your phone and your Mac each keep their own.

Every push to `main` on GitHub rebuilds and republishes the site (`.github/workflows/pages.yml`, about a minute). The next time you open the site online you get the new version.

## Run the website locally

Needs only Python 3, which comes with macOS.

```bash
python3 scripts/serve.py
```

Then open http://localhost:8000. Progress is saved in that browser.

**On your iPhone, over your Wi-Fi** (for testing changes before you push): run `python3 scripts/serve.py --lan` and open the address it prints in Safari on your phone. Your Mac must stay on and on the same network. Offline mode doesn't work this way, because browsers only allow it on `localhost` or HTTPS; use the online address above for that.

**Reminders:** the You tab's "Add to calendar" downloads a calendar event that repeats daily at your chosen time. A website can't send notifications on its own without a server.

## Run the tests

```bash
scripts/test-web.sh
```

38 tests of the website's logic and content, run with macOS's built-in JavaScript engine (no Node needed): Leitner boxes and due dates, streak with freezes, missed days, daylight saving and time-zone travel, resume after reload, every lesson loading, every icon name mapping to an icon, and topic color contrast. You can also open http://localhost:8000/tests/ while the server runs.

The lesson rules and the iPhone app's model code have their own tests (43, needs the Command Line Tools):

```bash
swift test --package-path Packages/LessonKit
```

## Add a lesson (no code changes)

1. Copy an existing file in `Content/Lessons/<topic>/`, rename it (e.g. `psy-how-memory-works.json`), and give it a new kebab-case `id` and an unused `order` within its topic.
2. Write 15–25 sections. Start with a `hook`, end with a `recap` (exactly 3 bullets), and include at least one `check`. Add exactly 5 `finalQuiz` questions and 2–4 `sources`. The section types and visual kinds are listed in SPEC.md §6. Icons use SF Symbol names (e.g. `"symbol": "brain"`); the website maps each to its own icon, and `scripts/test-web.sh` fails if a name has no match.
3. Cite sources on every section with numbers, dates or quotes (`"sourceRefs": ["s1"]`). For worked math, add `"computed": "how it was calculated"` instead.
4. Validate:
   ```bash
   swift run --package-path Packages/LessonKit validate-lessons Content
   ```
   Errors name the file, the section and the exact field, for example `sections[7] (timeline "arms-race") → events[2].sortKey: missing required key 'sortKey'`.
5. Reload the local website. The server finds new files in `Content/Lessons` on its own.
6. Commit and push to publish it online.

## Build a static copy

```bash
python3 scripts/build_web.py
```

This writes `dist/` (not committed), which any static file host can serve. GitHub Actions runs the same script to publish the site, so you only need it to host the site somewhere else.

## The iPhone app (later)

Needs **Xcode 16 or later** (free from the Mac App Store). After installing, open it once, then:

```bash
sudo xcode-select -s /Applications/Xcode.app
```

Open `Strata.xcodeproj`, pick an iPhone simulator and press Run. Running on your own iPhone works with Xcode's free "Personal Team" signing, but the install expires after 7 days. No paid Apple Developer Program is needed for either.

## Rename the app

Change `APP_DISPLAY_NAME` in `Config/App.xcconfig`. The iPhone app and the website both read it. If Xcode says the bundle ID is taken, change `PRODUCT_BUNDLE_IDENTIFIER` in the same file.

## Project layout

```
web/                  the website: index.html, styles.css, sw.js (offline), js/, tests/
  js/logic/           Leitner, streak, day keys, saved progress (no page code, so tests run it)
  js/render/          section types, visuals, charts, staged builds
Content/              topics.json + Lessons/<topic>/*.json, shared by web and iPhone
scripts/              serve.py, build_web.py, test-web.sh, typecheck-macos.sh
App/                  iPhone app (SwiftUI), Step 1
Packages/LessonKit/   Swift models, loader, validator, palette; tests; validate-lessons CLI
Config/App.xcconfig   app name, bundle ID, deployment target
.github/workflows/    publishes the website to GitHub Pages on every push
SPEC.md               the design
```

## Privacy

No accounts, analytics or trackers, and no third-party code. The website only loads its own files from wherever it's served (GitHub Pages or your Mac). The code and lessons are public on GitHub; your progress is not. Your progress stays in your browser on that device; "Reset progress" in the You tab deletes it. Source links open only when you tap them.
