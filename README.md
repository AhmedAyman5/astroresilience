# AstroResilience OS

> **"It doesn't just monitor — it predicts, recommends, and learns."**

An offline "edge" health system for **astronauts on long missions** (for
example to Mars). There, a message to Earth can take 4 to 24 minutes each way,
so the crew cannot wait for ground support. AstroResilience runs fully on
the device. It watches vital signs, predicts health risks before they
happen, recommends food and rest, records what the astronaut did, and adapts
to that person.

Built for the **NASA Space Apps Challenge 2026** (6th of October, Egypt).
Challenge: Health Monitoring Software (astronaut health).

---

## The 5 layers

| # | Layer | What it does |
|---|-------|--------------|
| 1 | **Telemetry Simulator** | Simulated smart-patch vitals: heart rate, HRV, SpO2, skin temperature, activity. Realistic random walk, 6 live scenarios (Nominal, Fatigue onset, Hypoxia event, Thermal stress, Nutrition deficit, Recovery). |
| 2 | **Edge AI Engine** | Explainable rule-based engine. Gives a risk score 0–100, a status (Normal / Warning / Critical) and predictions with a "Why?" list. |
| 3 | **Predictive Nutrition Loop** | Ranks space foods for each predicted risk, adds a non-food action (rest, hydrate, breathing…), logs meals at 100/75/50/25 % and updates the energy balance. |
| 4 | **Offline Dashboard** | Mission dashboard, vitals charts, nutrition, Mission Log, Demo Control. |
| 5 | **On-device Security** | Mission Log and meal history stored AES-256 encrypted on the device, with a "Wipe local data" button. |

## How it predicts

- The engine looks at a **rolling window of the last 12 readings**.
- Each vital is compared with **thresholds** (for example SpO2 under 94 % =
  warning, under 90 % = critical) and with the astronaut's **personal
  baseline** (for example HRV more than 20 % below baseline).
- Signals are **combined**. Example: low HRV + high heart rate + high activity
  means FATIGUE.
- A **trend slope** (linear regression over the window) shows if a risk is
  rising, stable or falling, and gives **minutes to threshold**.
- **WATCH stage:** if a value is still normal but rising toward a threshold
  that it will reach within about 10 minutes, the app shows WATCH (blue,
  radar icon) *before* the warning happens.

## How it learns

1. **Adaptive baseline:** the normal heart rate and HRV of the astronaut are
   learned with an exponential moving average, updated **only from calm
   readings**. Stress never becomes the new "normal".
2. **Meal feedback:** the app remembers how much of each food the astronaut
   really ate. A food often eaten only at 25–50 % ranks lower next time
   (score × (0.5 + 0.5 × average fraction eaten)). A recommendation nobody
   eats does not help, so the system adapts to the person.

## Data honesty

- **Telemetry is simulated.** There is no NASA dataset for this challenge.
  The vitals come from the built-in simulator; the scenarios are chosen in
  Demo Control.
- The **NASA Replay** source is ready for real data. Its bundled file
  (`assets/data/nasa/sample_replay.json`) is a **simulated sample**, and the
  app labels it "SIMULATED SAMPLE". A real file placed in `assets/data/nasa/`
  is used instead.
- **Thresholds are general physiology values, not NASA flight rules.**
- **Food values are approximate**, inspired by ISS menu items, not official
  NASA nutrition data.
- NASA hazard chips and HRP risk titles are **related context** from public
  NASA articles, not an official NASA classification.

Knowledge sources (articles, not data): NASA HRP "5 Hazards of Human
Spaceflight", "Risks of Human Spaceflight", "Ongoing HRP Research in Space";
CSA "Monitoring Radiation for Astronaut Health", "Why Do We Conduct Science
Experiments in Space?". See the References screen in Demo Control.
Radiation is not monitored in this MVP (a planned extension).

## Run it on the web (Windows)

You need the Flutter SDK (this project uses Flutter 3.47.9 stable).

```
flutter pub get
flutter run -d chrome --web-port 8080
```

Tip: in Chrome press F12 → device toolbar → choose a 390 × 844 phone size.

## Get the Android APK (GitHub Actions)

The APK is built in the cloud; no Android Studio is needed.

1. Push to the `main` branch, **or** open the repository on GitHub →
   **Actions** → **Build APK** → **Run workflow**.
2. Wait for the run to finish (green check, about 10 minutes).
3. Open the run → **Artifacts** → download **astroresilience-apk**
   (a zip with `app-release.apk`).
4. Copy the APK to an Android phone (Android 7.0+) and install it (allow
   "install unknown apps"). The demo build is signed with the debug key.

## Run the tests

```
flutter analyze
flutter test
```

The tests cover the engine rules, the simulator scenarios, the food
ranking, the meal loop, the wipe, and full screen tests at phone size
(390 × 844) that fail on any layout overflow.

## Privacy

- **Zero network calls** at runtime. Fonts, foods and data are bundled.
- No login, no backend, no cloud database.
- The Mission Log and meal history are stored **AES-256 encrypted** on the
  device. The key is kept in the platform's secure storage (Android Keystore
  / browser secure storage). If secure storage is not available the app
  says "memory only (not saved)" and still works.
- **Wipe local data** (Demo Control → Security) deletes the log, meal
  history and learned preferences. Android cloud backup is turned off.

## Credits

- NASA Space Apps Challenge 2026 team (6th of October, Egypt).
- Fonts: IBM Plex Sans and IBM Plex Mono, SIL Open Font License
  (`assets/fonts/OFL.txt`).
- Built with Flutter, provider, fl_chart, hive_ce, flutter_secure_storage,
  uuid and intl.
