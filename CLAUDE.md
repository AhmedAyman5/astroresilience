# AstroResilience OS — Project Rules for Claude Code

Read this file fully before every task. It is the single source of truth for this project.

## 1. Context
- NASA Space Apps hackathon (6th of October, Egypt) — Health & Science. Demo MVP, built in ~2 days.
- Owner: Ahmed. He does NOT know Flutter. Work autonomously, keep code simple and well commented, never leave the project in a broken state.
- Product: an offline "edge" system that helps an astronaut stay healthy on long missions (e.g. Mars) when the Earth link is delayed or lost. It monitors vitals from (simulated) smart patches, predicts risks before they happen, recommends nutrition and rest, records what the astronaut did, and adapts its recommendations.
- Pitch line: "It doesn't just monitor — it predicts, recommends, and learns."

## 2. Non-negotiable constraints
- Platforms: android + web only. Dev machine: Windows.
- Do NOT install Android Studio, Android SDK, or Java locally. Local machine = web preview in Chrome only. APKs are built by GitHub Actions.
- Flutter SDK lives at D:\dev\flutter. Pub cache lives at D:\dev\pub-cache (env var PUB_CACHE). Nothing Flutter-related on C:.
- ZERO network calls at runtime. Fonts and data are bundled as assets. Do NOT use the google_fonts package.
- No login, no backend, no remote database.
- UI language: English only.
- Approved packages: provider, fl_chart, hive_ce, hive_ce_flutter, flutter_secure_storage, uuid, intl. Dev: flutter_launcher_icons, flutter_lints, flutter_test. Adding any other package needs a strong reason, written in the Progress Log.

## 3. Architecture — 5 layers
lib/
- main.dart
- app/ — theme (colors, typography), app shell, bottom nav, routes
- core/ — models, constants (thresholds, weights), utils
- layers/telemetry/ — Layer 1: Telemetry Simulator
- layers/engine/ — Layer 2: Edge AI Engine (rule-based)
- layers/nutrition/ — Layer 3: Predictive Nutrition Loop
- layers/security/ — Layer 5: On-device security
- features/ — Layer 4: Offline Dashboard screens (dashboard, vitals, nutrition, log, demo_control, splash)

assets/
- data/foods.json — space food database
- data/nasa/ — real NASA data for replay (README placeholder until data arrives)
- fonts/ — IBM Plex Sans + IBM Plex Mono TTFs
- images/logo.png

State management: provider + ChangeNotifier. Business logic never lives inside widgets.

## 4. Layer specs

### Layer 1 — Telemetry Simulator
- Model VitalReading: timestamp (ISO 8601), heartRate (int bpm), hrv (int ms), spo2 (int %), temperature (double °C, 1 decimal), activity (enum low / moderate / high).
- JSON keys must be exactly: timestamp, heart_rate, hrv, spo2, temperature, activity.
  Example: {"timestamp":"2026-11-14T10:30:00","heart_rate":78,"hrv":42,"spo2":97,"temperature":36.6,"activity":"low"}
- Emits a reading on a Stream every N seconds (default 5; options 2 / 5 / 10).
- Realistic values: bounded random walk around a baseline, no jumpy noise. HR correlates with activity; HRV falls with fatigue and stress.
- Scenarios (switchable live, values drift gradually over ~1–2 minutes): NOMINAL, FATIGUE_ONSET, HYPOXIA_EVENT, THERMAL_STRESS, NUTRITION_DEFICIT, RECOVERY.
- Interface TelemetrySource with SimulatedSource and ReplaySource. ReplaySource reads a JSON array or CSV from assets/data/nasa/ and replays it at the chosen interval; it skips bad rows and maps common column names.

### Layer 2 — Edge AI Engine (rule-based, explainable)
- Rolling window: last 12 readings.
- Adaptive personal baseline: exponential moving average of HR and HRV, updated only during calm readings. This is the "learning" part — explain it in comments.
- Output EngineResult:
  - riskScore 0–100 (weighted, weights documented in core/constants)
  - status: NORMAL / WARNING / CRITICAL
  - predictions: list of RiskPrediction { type, severity, confidence %, trend (rising / stable / falling from slope over the window), minutesToThreshold (when rising), why (plain-English list of the signals that triggered it) }
- Risk types: FATIGUE, PHYSIOLOGICAL_STRESS, HYPOXIA, THERMAL_STRESS, NUTRITION_DEFICIT.
- Combined rules:
  - low HRV + high HR + high activity → FATIGUE
  - SpO2 under threshold → HYPOXIA
  - sustained high temperature → THERMAL_STRESS
  - high HR at low activity + low HRV → PHYSIOLOGICAL_STRESS
  - energy deficit + fatigue markers → NUTRITION_DEFICIT

### Thresholds (core/constants/thresholds.dart)
General physiology values — the team will verify them against NASA medical references. Keep a comment saying so.
- SpO2: under 94 = warning, under 90 = critical
- HR at low activity: over 100 = warning, over 120 = critical
- HRV drop vs personal baseline: over 20% = warning, over 35% = critical
- Skin temperature (sustained 3+ readings): over 37.5 = warning, over 38.0 = critical
- Energy deficit (estimated intake vs expenditure from activity): over 500 kcal = warning, over 900 kcal = critical

### Layer 3 — Predictive Nutrition Loop
- foods.json: ~25 items inspired by NASA ISS menus. Fields: id, name, category, kcal, protein_g, carbs_g, fat_g, sodium_mg, potassium_mg, tags.
- Tags: high_protein, low_sodium, high_carb, high_calorie, hydrating, electrolytes, iron_rich, quick_energy.
- Mapping risk → preferred tags:
  - FATIGUE → high_protein + quick_energy
  - THERMAL_STRESS → hydrating + electrolytes + low_sodium
  - NUTRITION_DEFICIT → high_calorie + high_carb
  - HYPOXIA → iron_rich (plus rest advice)
  - PHYSIOLOGICAL_STRESS → low_sodium + hydrating
- Every recommendation also includes a non-food action (rest, reduce activity, hydrate, breathing protocol).
- Loop: risk detected → ranked foods → astronaut picks a meal and a consumption level (100 / 75 / 50 / 25 %) → encrypted log saved → energy balance updated → engine reacts on next readings.
- Feedback learning: track average consumption % per food; foods often eaten at 25–50% rank lower next time. Explain in comments.

### Layer 5 — Security
- Meal logs and alert history stored in an encrypted Hive box (HiveAesCipher, AES-256).
- Key generated once, stored with flutter_secure_storage (Android + web).
- UI shows "Local data: AES-256 encrypted" + a "Wipe local data" action.

## 5. Design system — "Pressure Suit"
Feel: calm, precise NASA mission-control console. Story: the primary color is International Orange, the color of NASA launch-and-entry pressure suits — the system protects the astronaut like the suit does.

Forbidden: neon glows, purple, cyan neon, gradient blobs, glassmorphism, heavy shadows.

Colors (dark theme only):
- background #121314
- surface #1A1C1E
- surfaceRaised #222528
- border #2E3236
- textPrimary #ECE8E1
- textSecondary #9B9A96
- primary (brand, buttons, active nav) #E8743B
- info (nutrition, charts secondary) #8DB4D6
- normal #6FB38E
- warning #F2C14E
- critical #E5484D

Typography:
- IBM Plex Sans for all UI text.
- IBM Plex Mono for vital numbers, timestamps, IDs (tabular look).
- Small uppercase labels with letter spacing, e.g. "HEART RATE · BPM".

Shapes and layout:
- Corner radius 12. Cards use a 1px border, no shadows. Generous spacing (8-pt grid).
- Status is never shown by color alone: always icon + text label.
- Must look right on a phone: test at 390x844 in Chrome responsive mode. No overflow anywhere.

## 6. Screens
- Top bar on all tabs: logo + "AstroResilience", chip "OFFLINE · EDGE MODE", chip "EARTH LINK DELAY: 12m 40s" (simulated Mars delay, slowly varying 4–24 min), icon to open Demo Control.
- Splash: logo + name + "Initializing edge engine…" (~1.5 s).
- Tab 1 Mission Dashboard: risk gauge 0–100 with status label; 5 vital cards (value, unit, sparkline of last 12, trend arrow); top prediction card with expandable "Why?"; recommended action card linking to Nutrition.
- Tab 2 Vitals: one line chart per vital with dashed threshold lines; range toggle (2 min / 10 min / session).
- Tab 3 Nutrition: active recommendations with reasons; food cards with macros; bottom sheet to pick 100/75/50/25% and log; energy balance bar; searchable full list.
- Tab 4 Mission Log: timeline of status changes, predictions and meals (newest first, mono timestamps); export log as JSON in a dialog with copy button.
- Demo Control: scenario selector, data source toggle (Simulated / NASA Replay), interval selector, reset session, security status + wipe data, short "About: 5-layer architecture".

## 7. Coding conventions
- Null-safe Dart, small widgets, const constructors where possible.
- Immutable models with copyWith, fromJson, toJson.
- No magic numbers: thresholds, weights, colors, spacing go in constants/theme.
- Comments explain WHY (Ahmed will explain the code to judges).
- Unit tests for the engine rules and the recommender ranking.

## 8. Commands
- flutter pub get
- flutter analyze
- flutter test
- flutter run -d chrome --web-port 8080
- flutter build web (quick compile check)

## 9. Definition of done (every phase)
- flutter analyze: 0 errors.
- flutter test: all passing.
- App runs in Chrome without runtime errors and without overflow at 390x844.
- Progress Log below updated.
- End with a short summary in simple English (the terminal cannot display Arabic correctly): what was built, what Ahmed should test now.

## 10. Workflow rules
- Do only the phase requested; basic scaffolding for later phases is fine.
- If the same error fails 3 times, stop and explain the problem to Ahmed in simple Arabic with options.
- Never delete or rewrite working features unless the task asks for it.
- Never run git commit, git push, or change git history. Ahmed handles Git manually. If you change .gitignore, tell him why.

## 11. Progress Log
- [x] Phase 1 — Environment, project setup, theme, app shell
- [x] Phase 2 — Telemetry simulator + Edge AI engine + tests
- [ ] Phase 3 — Dashboard + Vitals screens
- [ ] Phase 4 — Nutrition loop + security + Mission Log
- [ ] Phase 5 — Demo Control, icons, GitHub Actions APK, README, final QA

Notes:
- (Claude Code adds dated notes here: decisions, package versions, Flutter version, known issues.)
- 2026-11-11 Phase 1 done.
  - Flutter 3.47.9 stable (rev c197ca5199), Dart 3.13.7, at D:\dev\flutter. PUB_CACHE=D:\dev\pub-cache (user env). Uninstall steps: UNINSTALL.md.
  - Packages: provider 6.1.5+1, fl_chart 1.3.1, hive_ce 2.23.3, hive_ce_flutter 2.5.0, flutter_secure_storage 11.2.0, uuid 4.6.0, intl 0.20.3; dev: flutter_lints 6.0.0, flutter_launcher_icons 0.14.4. No extra packages.
  - Fonts: IBM Plex Sans (400/500/600/700) + Mono (400/500) TTFs from github.com/IBM/plex, with OFL.txt. Families: IBMPlexSans, IBMPlexMono.
  - Offline on web: web/flutter_bootstrap.js sets canvasKitBaseUrl "canvaskit/" (no CanvasKit CDN). pubspec registers a "Roboto" family that points at Plex Sans; without it the web engine fetches Roboto from fonts.gstatic.com. Verified in Chrome: build/web makes only localhost requests.
  - logo.png (root) copied to assets/images/logo.png. AppLogo falls back to an orange circle if it is missing.
  - Top bar chips sit in one row inside FittedBox(scaleDown), so they shrink instead of overflowing at 390px.
  - EarthLinkController (app/state): bounded random walk of the Mars delay, 4–24 min, ticks every 3 s.
  - core/constants/thresholds.dart already holds the section-4 threshold values (scaffold for Phase 2).
  - The widget test renders at 390x844 and fails on any overflow. A manual check at phone size in Chrome DevTools is still worth doing.
- 2026-11-11 Phase 2 done. No new packages.
  - Layer 1 (layers/telemetry): TelemetrySource (abstract, has stream()), SimulatedSource, ReplaySource + ReplayParser (JSON array / {readings:[]} / CSV with ; , tab; column aliases; °F→°C; SpO2 fraction→%; bad rows skipped), TelemetryController (history, scenario, source, interval, resetSession with sessionId, broadcast `readings` stream). Scenario targets in scenario_profiles.dart.
  - Drift: a scenario switch starts a 90 s smoothstep ramp from current values (not an exponential ease, which crossed thresholds within ~15 s and hid the WATCH stage). Noise = bounded AR(1). HR follows activity with a 20 s ease. Reset session also resets the scenario to NOMINAL.
  - Replay: uses the first non-sample .json/.csv in assets/data/nasa/ (via AssetManifest), else sample_replay.json (60 synthetic readings, 1 min apart: nominal → slow SpO2 drop → recovery). Readings are re-stamped with now and the file loops.
  - Layer 2 (layers/engine): EdgeEngine (pure Dart), AdaptiveBaseline (EMA, alpha 0.3 for the first 5 calm readings, then 0.05; learns only from calm readings), MetricScale/RiskScoring, TrendAnalyzer (linear regression), EngineController. All numbers in core/constants/engine_constants.dart and thresholds.dart.
  - Severity scale: approach→0, warning→0.5, critical→1.0, max 1.5. Score points 0/40/70/100 match the status bands NORMAL <40, WARNING 40–69, CRITICAL ≥70. Score = worst risk + 25% × weighted other risks. Combined rules with only part of their supporting signals are multiplied by 0.8 ("one notch lower"). A WATCH prediction = rising trend + warning expected within 10 min.
  - Thresholds file gained "approach" values (start of the watch zone) and supporting-signal values (fatigueHrHigh 110, hrElevatedRatio 15%, nutritionHrvMarker 10%). Still general physiology, to be checked against NASA references.
  - Energy (layers/nutrition/energy_balance_service.dart): burn 1.2 / 3.5 / 6.0 kcal/min (low/moderate/high), planned menu covers 2.0 kcal/min, demo time ×60 (1 s = 1 mission min). Deficit is floored at 0. The NUTRITION_DEFICIT scenario sets mealsSkipped, so the menu covers nothing. Without this, every active scenario built a deficit and NUTRITION_DEFICIT overtook the scenario's own risk. addIntake(kcal) is ready for Phase 4.
  - Temporary debug view: features/dashboard/engine_debug_view.dart (scenario dropdown, interval, source, reset, "+600 kcal" test meal, live reading, score, baseline, predictions with Why). It gets replaced in Phase 3/5.
  - Tests: 59 passing, including end-to-end runs of each scenario with seeded randoms, and NOMINAL/RECOVERY checked over 10 minutes × 5 seeds for false alarms. Shared helpers in test/helpers.dart.
  - Known: SegmentedButton uses the theme's secondary (info blue) for its selected segment. That is fine for the temporary view; Phase 5 Demo Control should style it orange.