# NASA replay data

Files in this folder are replayed by `ReplaySource` (Layer 1) when the data
source is switched to **NASA Replay**. Everything is bundled with the app: no
network calls.

## Which file is used
- Any `.json` or `.csv` file placed here is picked up automatically
  (alphabetical order, first one wins).
- Real data files are preferred over `sample_replay.json`.
- `sample_replay.json` is a bundled 60-reading demo file (1 minute apart):
  20 nominal minutes, a slow 25-minute SpO2 drop (hypoxia onset, down to
  ~89%), then recovery. It is **synthetic**, made only so replay works before
  real NASA data arrives.

## Accepted formats
1. JSON array of objects: `[{"timestamp": "...", "heart_rate": 78, ...}, ...]`
2. JSON object with a `readings`, `data` or `records` array.
3. CSV with a header row (comma, semicolon or tab separated).

## Fields and accepted column names
Column names are matched case-insensitively, ignoring spaces, `_`, `-` etc.

| Field         | Also accepted                                                    |
|---------------|------------------------------------------------------------------|
| `timestamp`   | time, datetime, date, ts, utc (optional)                         |
| `heart_rate`  | hr, pulse, pulse_rate, bpm, heart_rate_bpm                       |
| `hrv`         | hrv_ms, rmssd, hrv_rmssd, heart_rate_variability, sdnn           |
| `spo2`        | sp02, spo2_pct, oxygen_saturation, o2sat, sao2, saturation       |
| `temperature` | temp, temp_c, skin_temp, skin_temperature, body_temp             |
| `activity`    | activity_level, intensity, exertion (optional, default `low`)    |

- `activity` can be `low / moderate / high` (also rest, medium, vigorous...),
  `0 / 1 / 2`, or a MET value (3+ moderate, 6+ high).
- SpO2 as a fraction (`0.97`) is converted to percent.
- Temperatures above 50 are treated as °F and converted to °C.

## Bad rows
A row is skipped (not a crash) when a vital is missing, not a number, or
outside physiological limits (HR 25–250, HRV 1–300, SpO2 50–100,
temperature 30–43 °C).

## Replay behaviour
Readings are emitted at the chosen interval (2 / 5 / 10 s), re-stamped with
the current time, and the file loops when it ends.
