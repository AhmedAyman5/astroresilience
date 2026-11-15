# AstroResilience OS — Project Rules for Claude Code

Read this file fully before every task. It is the single source of truth for this project.

## 1. Context
- NASA Space Apps Challenge 2026 (6th of October, Egypt). Challenge: Health Monitoring Software (astronaut health). Demo MVP. Hackathon ends 2026-11-15.
- Owner: Ahmed. He does NOT know Flutter. Work autonomously, keep code simple and well commented, never leave the project in a broken state.
- Product: an offline "edge" system that helps an astronaut stay healthy on long missions (e.g. Mars) when the Earth link is delayed or lost. It monitors vitals from (simulated) smart patches, predicts risks before they happen, recommends nutrition and rest, records what the astronaut did, and adapts its recommendations.
- Users: ASTRONAUTS ONLY. No patient mode, no explorer mode, no diseases, no medications. This line wins over anything else.
- Data: there is NO NASA dataset for this challenge. The app runs on the built-in telemetry simulator with selectable scenarios (Demo Control). The NASA Replay source stays as a ready feature for real data; its bundled sample file is SIMULATED and labeled as simulated in the UI and docs.
- Knowledge sources (articles, not data): NASA HRP "5 Hazards of Human Spaceflight", "Risks of Human Spaceflight", "Ongoing HRP Research in Space"; CSA "Monitoring Radiation for Astronaut Health", "Why Do We Conduct Science Experiments in Space?".
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
- data/nasa/ — replay folder. sample_replay.json is a SIMULATED sample (no NASA dataset exists for this challenge). A real NASA file dropped here later is preferred automatically.
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

## 5. Design system — "Nile & Gold"
Feel: calm, precise mission-control console with an Egyptian identity. Story: Nile blue, pharaonic gold, sun yellow, faience turquoise on black — the gold of the pharaohs' masks guards the astronaut, the Nile blue carries the data, faience turquoise means "all is well".

Forbidden: neon glows, purple, gradient blobs, glassmorphism, heavy shadows. (Turquoise is allowed as a calm accent, never neon.)

Colors (dark theme only):
- background #0B0B0D (deep black)
- surface #131A24 (black with a hint of Nile blue)
- surfaceRaised #1A2433
- border #26354A
- textPrimary #F3EBD8 (warm papyrus white)
- textSecondary #A79F8C
- primary (brand, buttons, active nav) #D4A73A (Egyptian gold); onPrimary #0B0B0D
- info (nutrition, charts secondary, WATCH) #3D7BC4 (light Nile blue; deep Nile #1F5FA8 = decoration only, too dark for text)
- accent #30B5A6 (faience turquoise)
- normal #30B5A6 (turquoise)
- warning #F2C230 (sun yellow)
- critical #E5484D

Egyptian touches (keep it minimal): thin gold top line on cards, pyramid-line motif under the top bar. Light animations (lib/app/theme/app_motion.dart): cards fade + slide in once (250 ms), one gold shimmer on the splash logo. Every animation plays once and stops.

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
- Demo Control: scenario selector, data source toggle (Simulated / NASA Replay; the bundled replay sample is labeled SIMULATED SAMPLE), interval selector, reset session, security status + wipe data, short "About: 5-layer architecture".

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
- [x] Phase 3 — Dashboard + Vitals screens
- [x] Phase 4A — Nutrition loop + Mission Log (in-memory storage behind an interface)
- [x] Phase 4B — Security: encrypted Hive, key in flutter_secure_storage, wipe
- [x] Phase 5 — App icon, GitHub Actions APK, Demo Control polish, README
- [x] Phase 6 — NASA/CSA References screen + hazard tags, final QA

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
- 2026-11-11 Phase 3 done. No new packages.
  - Debug controls moved to Demo Control (scenario, interval, source + replay file/row/bad rows, reset session, "+600 kcal" test meal). engine_debug_view.dart deleted.
  - Dashboard: RiskGauge (CustomPainter, 240° arc, dim NORMAL/WARNING/CRITICAL bands, animated with TweenAnimationBuilder 0.9 s), 5 VitalCards (2 columns, Activity full width, sparkline of the last 12, trend arrow, status dot + text), PredictionCard ("Why?" and "+N more" toggles, kept open across readings), "All systems nominal" calm card, ActionCard ("See nutrition plan" switches tab), footer with baseline learning UPDATED/PAUSED + window N/12 + baseline values.
  - AlertLevel (core/models/alert_level.dart) adds WATCH = status NORMAL with predictions. WATCH = info blue + radar icon. The widget test checks that WATCH, WARNING and CRITICAL all appear during the hypoxia ramp.
  - Vital card status (core/utils/vital_analysis.dart) uses the average of the last 3 readings, like the engine. HR counts only at LOW activity. HRV is compared with the learned baseline. Trend arrows have dead bands (ui_constants.dart) so noise does not flip them.
  - Vitals tab: one fl_chart per vital, dashed warning/critical lines with labels (HRV lines move with the baseline), range 2 min / 10 min / Session, current + min/max/avg, activity as a step chart with a shaded band (plus % time per level). x = seconds since session start, so the 300 ms animation looks like a smooth scroll.
  - Rebuilds: TelemetryController gained `revision` (increments per reading) and `historyView` (no copy). Cards and charts select on revision. Charts are wrapped in RepaintBoundary.
  - ShellNavigation (app/state) holds the open tab. PhoneFrame (MaterialApp.builder) centers the app at max 520 px on wide windows. maxContentWidth was 720, now 520.
  - The segmented-button theme now uses an orange tint (blue now means WATCH). This was planned for Phase 5 and was done early.
  - layers/nutrition/action_advisor.dart: non-food action per risk (rest / hydrate / reduce activity / breathing / routine). Phase 4 builds on it.
  - Tests: 67 passing. widget_test renders Mission + Vitals at 390x844 with NOMINAL, then HYPOXIA_EVENT for 3 min. It scrolls every list and fails on any overflow. New test/ui/vital_analysis_test.dart.
  - Chrome check (build/web on localhost): no app console errors and no network requests.
- 2026-11-15 Stage 0 done: CLAUDE.md + assets/data/nasa/README.md updated (astronauts only, no NASA dataset, replay sample is SIMULATED, knowledge sources).
- 2026-11-15 Phase 4A done. No new packages.
  - assets/data/foods.json: 26 ISS-inspired foods (approximate values, disclaimer under the list). Every mapped tag is on 3+ foods. Food model in core/models/food.dart.
  - LogStore interface + InMemoryLogStore (layers/security/log_store.dart). Entries are JSON maps (no TypeAdapters). The store is created in one place (main.dart); AstroResilienceApp(store:) falls back to memory only.
  - MissionLogController (layers/log/ — new folder, the log is shared by Layers 3/4/5). Logs changes only: status (new AlertLevel confirmed on 2 readings, LogConstants.statusConfirmReadings), prediction (new risk or higher severity; a risk is "closed" after 3 absent readings), meal, system (scenario / source / reset, marked simulated). Max 500 entries. Reset session keeps the log. Timestamps are full ISO 8601 with ms.
  - Meal history = the meal entries of the log (one source of truth, so Wipe clears history + preferences together).
  - FoodRecommender (pure Dart): tag score (weights in core/constants/nutrition_constants.dart) × preference factor (0.5 + 0.5 × average fraction eaten; never eaten = 1.0). Ties by food id. Max 2 recommendations × 3 foods + ActionAdvisor action.
  - NutritionController: logMeal → EnergyBalanceService.addIntake → Mission Log (store) → preferences. Demo Control "+600 kcal" uses logTestMeal (same path, no food id, does not teach preferences).
  - EnergyBalanceService gained totalPlannedKcal / totalEatenKcal / deficitStatus.
  - Nutrition tab: energy card (bar with 500/900 marks), recommendations or "No active risk" routine card, searchable food cards, bottom sheet 100/75/50/25 % + snackbar. Mission Log tab: filters All/Alerts/Meals/System, expandable Why?, Export JSON dialog (Copy/Close).
  - Test gotcha: an indeterminate progress indicator in an offstage IndexedStack tab keeps ticking, and rootBundle caches across widget tests. Foods load with cache:false and the tab shows static "Loading…" text.
  - Tests: 81 passing (new test/nutrition/nutrition_test.dart; widget test 2 runs NUTRITION_DEFICIT → log 75 % via the sheet → Log filters → Export at 390x844).
- 2026-11-15 Phase 4B done. No new packages.
  - EncryptedLogStore (layers/security/encrypted_log_store.dart): Hive box "mission_log_secure" opened with HiveAesCipher; 256-bit key from Hive.generateSecureKey(), stored base64 in flutter_secure_storage; entries are JSON strings keyed by id.
  - SecurityService: mode ENCRYPTED / MEMORY_ONLY, stored entry count, wipeLocalData() (clears box + log → meal history and preferences follow). The key is KEPT on wipe (the box is empty, so rotating adds risk for no gain); uninstall / clearing site data removes it.
  - main.dart: openLogStore() with a 5 s timeout and try/catch → InMemoryLogStore on any failure. AstroResilienceApp(store:, storeError:). Tests pass InMemoryLogStore.
  - UI: Demo Control Security card (status, entry count, Wipe with confirm dialog, red only on the confirm button, snackbar). Mission Log chip "AES-256 · ON DEVICE" / "MEMORY ONLY".
  - Android: effective minSdk is already 24 (Flutter default, flutter_secure_storage needs 23+), not changed. android:allowBackup="false" added with a comment.
  - Verified in Chrome (build/web on localhost): the chip shows AES-256 · ON DEVICE, so secure storage + Hive work on web.
  - Tests: 84 passing (wipe test, open-failure and open-timeout fallback tests).
- 2026-11-15 Phase 5 done (with one open item: icon files).
  - ICON DECISION: pubspec has the flutter_launcher_icons config (android true, ios false, image_path assets/icon/app_icon.png, adaptive background #111011, adaptive foreground assets/icon/app_icon_foreground.png padded for the safe zone, web generate with background #121314 / theme #E8743B). assets/icon/ is NOT in the flutter assets list.
  - OPEN: assets/icon/app_icon.png and app_icon_foreground.png were NOT in the project, so `dart run flutter_launcher_icons` was NOT run (we do not create or resize them). The app still has the default Flutter launcher icons. Fix: put the two files in assets/icon/ and run `dart run flutter_launcher_icons`. The CI workflow also runs it automatically when both files exist.
  - web/manifest.json theme_color #E8743B, description updated (index.html too). Title stays AstroResilience.
  - .github/workflows/build-apk.yml: push to main + workflow_dispatch, ubuntu-latest, checkout@v4, setup-java@v4 temurin 17 (AGP 9.1 / Gradle 9.3 need 17+), subosito/flutter-action@v2 Flutter 3.47.9 stable cache, pub get, conditional icon generation, analyze, test, build apk --release (debug key), upload-artifact@v4 "astroresilience-apk". YAML checked by parsing it with package:yaml; it has not run on GitHub yet.
  - Demo Control order: Scenario, Telemetry, Session, Security, About (5 layers + "No network · No backend · No login" + References tile). Replay of sample_replay.json shows chip SIMULATED SAMPLE + explanation (ReplaySource.isSimulatedSample).
  - README.md rewritten (pitch, users, 5 layers, predict, learn, data honesty, web run, APK download, tests, privacy, credits).
  - AstroResilienceApp gained simulatorSeed (tests only): the widget test uses seed 7, because the unseeded simulator made the "WATCH appears" check flaky (failed 1 run in ~5).
- 2026-11-15 Phase 6 done.
  - core/constants/hazard_constants.dart: risk → related NASA hazard + HRP risk (labeled "related", not an official classification) + app-wide Distance from Earth.
  - HazardChip "NASA HAZARD · …" (ellipsis) + HrpRiskLine on the dashboard prediction card and each Nutrition recommendation.
  - features/references/references_screen.dart (route /references from the About card): NASA HRP 3 articles, CSA 2 articles (radiation NOT monitored, dosimeter = planned extension), related-hazard table, footer about thresholds. Plain text, no links.
  - Final QA: analyze 0 issues; 84 tests pass; flutter build web OK. Chrome walk on build/web (phone frame): Nominal → Fatigue onset (WARNING, CRITICAL) → Nutrition (Protein bar first, logged at 50%, "Ranked lower" appeared) → Log (status, prediction, meal) → F5 kept 11 encrypted entries → Hypoxia CRITICAL with hazard chip → Recovery NOMINAL → NASA Replay SIMULATED SAMPLE → References → Wipe (0 entries). No console errors; all app requests are localhost.
  - Grep for patient / explorer / disease / medication in lib/, assets/, README: none.
  - Known: near a band edge (score 69/70) the log can show WARNING ↔ CRITICAL changes a few seconds apart; confirmation is 2 readings (LogConstants.statusConfirmReadings), raise it to 3 if it looks noisy.
  - dart format was only run on edited files; formatting-only changes to untouched files were reverted.
- 2026-11-15 Re-skin "Nile & Gold" (visual only): new palette in app_colors.dart, app_motion.dart (card entrance, splash shimmer), gold card top line, pyramid motif in top bar, gold nav indicator outline, web theme/background colors. No logic, text, keys or tests changed. Written without a local Flutter SDK: Ahmed must run flutter analyze + flutter test.
