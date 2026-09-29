# Voice golden corpus (T4.7)

Each YAML file is a list of `[utterance, expected]` pairs. `now` is 20:00 on 29 Sep 2026
unless a case says otherwise with a third element `{now: "HH:MM"}`.

Expected syntax: `<type> [action] [duration|clock] | <words…> | [all] [except=<words…>]`

- type: `power`, `powerFor`, `powerAfter`, `powerAt`, `powerUntil`, `cancelTimer`,
  `status`, `unknown`
- action: `on`, `off`, `toggle`
- duration: `20m`, `1h30m`, `90s`; clock: `23:00`
- words: canonical target words as the parser emits them (nouns canonicalised: batti →
  light, pankha → fan, water heater → geyser)

Cases marked `# stt` imitate speech-recogniser misspellings. Add real transcripts from
T4.9 here.
