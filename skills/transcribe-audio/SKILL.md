---
name: transcribe-audio
description: Transcribes a local audio or video file (English, Bangla, or mixed Bangla-English) by listening to it with the model's own audio understanding, uses ffmpeg scripts only to measure silence and prove no speech was skipped, then saves a timestamped transcript (original, English, Bangla) plus a clean dialogue file. Use when the user asks to transcribe, translate, or write up a recording.
---

# Transcribe audio

READ THIS WHOLE FILE BEFORE DOING ANYTHING. FOLLOW IT EXACTLY.
This is a fixed procedure, not a suggestion. You do not get to improve it,
shortcut it, or "be thorough" in your own way. Every action you take must be
one of the ALLOWED ACTIONS below. If it is not on that list, you do not do it.

## ALLOWED ACTIONS (the complete list)
1. Run these four scripts, and ONLY these, exactly as shown:
   `powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\ensure-tools.ps1"`
   `powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\analyze-audio.ps1" -Audio "<file>"`
   `powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\split-audio.ps1" -Audio "<file>" -From <s> -To <s>`  (ONLY when MODE=CHUNK)
   `powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\check-coverage.ps1" -Transcript "<file>" -Regions "<csv>"`
   (`<skill-dir>` = the folder containing this SKILL.md.)
2. Open (listen to) the ORIGINAL audio file, or - only when MODE=CHUNK - the
   piece files that split-audio.ps1 printed.
3. Read `speech_regions.csv` / `analysis.txt` in WORKDIR.
4. Write exactly two files: `<name>_transcription.txt` and `<name>_dialogue.txt`.
5. Delete WORKDIR at the end.

## FORBIDDEN (no exceptions, no matter how helpful it seems)
- NEVER run `ffmpeg` or `ffprobe` yourself. NEVER cut, trim, split, extract,
  convert, re-encode, slow down or "test clip" the audio in any way. The ONLY
  thing that may ever cut audio is split-audio.ps1, and ONLY when MODE=CHUNK
  (recordings of 30 minutes or more). For anything shorter, the file is
  heard WHOLE, every time, including the second pass.
- NEVER open, read, or inspect the .ps1 script files. You do not need to know
  how they work. Just run them and read their output.
- NEVER create any file other than the two output files. No test files, no
  notes, no scratch audio, no copies.
- NEVER look for other tools: no Whisper, Python, pip, npm, WSL, cloud speech
  APIs, API keys, plugin accounts, or "brain"/transcript files.
- NEVER retry a failed step more than ONCE. After one fix attempt, STOP and
  tell the user the exact error.
- NEVER claim you checked or verified something you did not actually run.
- NEVER overwrite an existing transcript; add `_v2`, `_v3`.
- NEVER delete anything except WORKDIR.

If you notice yourself about to do something not in ALLOWED ACTIONS: stop,
re-read this file, and go back to the current step.

If your model cannot take audio input (for example Claude), STOP now and tell
the user this skill needs an audio-capable model such as Gemini in Antigravity.

---

## Step 0: Find the input
Use the path the user gave. If they gave only a name, look in the workspace,
then the Downloads folder. If several files match, list them and ask once.
Supported: m4a, mp3, wav, aac, flac, ogg, opus, wma, mp4, mov, mkv, webm.

## Step 1: Tools
Run `ensure-tools.ps1`.
- Exit 0 -> continue.
- Exit 1 -> tell the user to run `winget install Gyan.FFmpeg`, then stop.
- Exit 2 -> not Windows: one attempt with `brew install ffmpeg` or
  `sudo apt install ffmpeg`; the scripts need PowerShell 7 (`pwsh`). Otherwise stop.

## Step 2: Analyze
Run `analyze-audio.ps1 -Audio "<file>"`. Read its output. Note WORKDIR, MODE,
the speech regions, and any gap marked `QUIET SOUND PRESENT`.
The output ends with a `NEXT:` line. Do exactly what it says.
- MODE=NONE -> tell the user no speech was detected. Do not write a transcript. Stop.
- MODE=WHOLE_FILE -> go to Step 3A. (This is the normal case. No cutting.)
- MODE=CHUNK -> go to Step 3B. (Only for 30+ minute recordings.)

## Step 3A: WHOLE_FILE - listen and transcribe
Open the ORIGINAL file and transcribe the entire timeline in one go, using
the rules in "Transcription rules" below. Pay extra attention to any
`QUIET SOUND PRESENT` range. Do not cut anything. Go to Step 4.

## Step 3B: CHUNK - listen and transcribe in pieces
For each speech region run `split-audio.ps1 -Audio "<file>" -From <start> -To <end>`.
It makes 10-minute pieces (3 s overlap) in WORKDIR\chunks and prints each
piece's START_SECONDS. Open the pieces in order. Real time = time inside the
piece + START_SECONDS. Remove words duplicated by the 3 s overlap. Append to
the transcript piece by piece. Go to Step 4.

## Step 4: Second pass (same audio, no new cuts)
Listen AGAIN to the SAME audio you used in Step 3: the original file
(WHOLE_FILE) or the same pieces (CHUNK). Do NOT make clips of "hard parts".
Check line by line: wrong words, missing sentences, wrong speaker, wrong
script. Fix only what you are sure of; otherwise mark [?]. Count corrections.

## Step 5: Write the transcription file, then check coverage
Write `<audio name>_transcription.txt` (format below), next to the audio file
unless the user named a folder. Then run
`check-coverage.ps1 -Transcript "<that file>" -Regions "<WORKDIR>\speech_regions.csv"`.
- COVERAGE_OK -> continue.
- Problems listed -> listen to those time ranges in the SAME audio
  (original file or existing pieces; no new cuts), add the missing speech,
  run the check again. Max 2 repair loops, then report what is still missing.

## Step 6: Write the dialogue file
`<audio name>_dialogue.txt`: original language only, no timestamps,
`Speaker 1: ...` lines, [?] kept.

## Step 7: Clean up and report
Delete WORKDIR (`%TEMP%\transcribe-audio\<name>`). Then tell the user:
- both file paths
- total duration, speech duration, silent gaps
- MODE used
- number of [?] marks and second-pass corrections
- coverage result
- that timestamps are approximate and Bangla/mixed parts are worth a spot-check
Do not paste the whole transcript into the chat.

---

## Transcription rules
- Verbatim. Do not clean up, paraphrase, shorten, reorder or censor.
- Bangla speech -> Bangla script. English words -> Latin letters exactly as
  spoken (e.g. "podcast", "redirect"). Mixed sentences keep both, in order.
- Numbers as digits; keep spoken unit/currency words.
- Names: the user's spelling if given; otherwise best guess + [?].
- Unclear -> best guess + [?]. Not audible -> [inaudible]. Overlap ->
  [crosstalk]. Meaningful sounds only -> [laughs], [pause].
- NEVER invent words to fill a gap. A [?] is always better than a confident guess.
- One entry per sentence or speaker turn, max about 15 seconds each.
- Label Speaker 1, Speaker 2 only when voices are clearly different.
- Timestamps are your estimates. Always call them approximate.

## Transcription file format
```
TRANSCRIPTION
Source: <file name>
Duration: HH:MM:SS | Speech: HH:MM:SS
Method: model's own audio understanding (no separate speech-to-text tool)
Silence check: <e.g. 1 silent gap 00:01:03-00:09:25, peak -91 dB, verified>
Timestamps are approximate. Uncertain words are marked [?] (count: N).
------------------------------------------------------------
[HH:MM:SS] Speaker 1
ORIGINAL: <exactly as spoken>
EN: <English version; copy ORIGINAL if already English>
BN: <Bangla version in Bangla script; copy ORIGINAL if already Bangla>
```
Every entry starts with `[HH:MM:SS]` at the very start of the line (the
coverage check depends on it). Translations are faithful, never summaries.
In BN keep common English loanwords, brands and tech terms in Latin letters.
If the user asks for romanized Banglish, add a `ROMAN:` line per entry.

## Troubleshooting
| Symptom | Action |
|---|---|
| ensure-tools exit 1 | Ask user to run `winget install Gyan.FFmpeg`, then retry once |
| Script blocked | Check you used `-ExecutionPolicy Bypass`; if still blocked, report it |
| Original file won't open | Retry once, then STOP and report. Do NOT cut it to make it work |
| A piece won't open (CHUNK) | Retry once, then report which time range is missing |
| Coverage problems after 2 loops | Report the remaining ranges honestly |
| Quiet speech missed | Re-run analyze-audio.ps1 with `-NoiseDb -45` |
| Noisy / overlapping audio | Use [?] / [crosstalk] and tell the user |
