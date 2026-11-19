# transcribe-audio

An agent skill that transcribes recordings in **English, Bangla, or mixed
Bangla-English**. It saves:

- `<name>_transcription.txt` - timestamped, one entry per sentence with
  `ORIGINAL`, `EN` and `BN` lines
- `<name>_dialogue.txt` - a clean reading version (original language, no timestamps)

The agent's model **listens to the audio itself**. There is no Whisper, no
Python, no cloud speech API and no API key. The only dependency is
**ffmpeg**, which the skill installs for you. ffmpeg is used only to measure
silence and to prove that no speech was skipped.

## Requirements

| Need | Details |
|---|---|
| OS | Windows 10 or 11 (PowerShell 5.1, built in) |
| Agent | **Google Antigravity** with a Gemini model (audio input). |
| Internet | First run only, to download ffmpeg |

> **Claude (Claude Code / claude.ai) cannot listen to audio files.** The skill
> installs there but will stop and say it needs an audio-capable model.

## Install

### Option A - from the release zip (easiest)

1. Download `transcribe-audio-skill.zip` from the
   [Releases](../../releases) page and **Extract All**.
2. Double-click **`Install.cmd`**. (If SmartScreen appears: *More info* -> *Run anyway*.)
3. Start a **new** Antigravity session. Skills load only when a session starts.

This installs to `%USERPROFILE%\.gemini\config\skills\transcribe-audio`,
Antigravity's global skills folder, so it works in every project.

### Option B - one project only

In PowerShell, inside the extracted folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -ProjectPath "D:\My Project"
```

This installs to `<project>\.agents\skills\transcribe-audio`.

### Option C - manual copy (no script)

Copy the `skills\transcribe-audio` folder so that this file exists:

- All projects: `%USERPROFILE%\.gemini\config\skills\transcribe-audio\SKILL.md`
- One project: `<project>\.agents\skills\transcribe-audio\SKILL.md`

### Option D - one-line install from GitHub

Replace `YOUR-USERNAME` with the account that hosts this repo:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/YOUR-USERNAME/transcribe-audio-skill/main/install.ps1))) -Repo "YOUR-USERNAME/transcribe-audio-skill"
```

### Installer options

| Flag | Meaning |
|---|---|
| `-ProjectPath "<dir>"` | Install into one project instead of globally |
| `-Agent Claude` / `-Agent All` | Also install to `%USERPROFILE%\.claude\skills` (see the note above) |
| `-TargetDir "<dir>"` | Install to any skills folder you choose |
| `-SkipTools` | Do not set up ffmpeg now (it is set up on first use anyway) |
| `-Uninstall` | Remove the skill |

## Check that it is installed

1. Confirm the file exists:
   ```powershell
   Test-Path "$env:USERPROFILE\.gemini\config\skills\transcribe-audio\SKILL.md"
   ```
   `True` means the files are in place.
2. Open a **new** Antigravity session and ask:
   > What skills do you have? Is transcribe-audio one of them?

If it is missing: make sure the session is new, and note that
`%USERPROFILE%\.gemini\antigravity\skills\` is **not** a scanned folder.

## Use

> Use the transcribe-audio skill on "D:\Recordings\meeting.m4a"

Supported: m4a, mp3, wav, aac, flac, ogg, opus, wma, mp4, mov, mkv, webm
(the audio track is used for video files).

## How it works

1. **Tools** - `ensure-tools.ps1` finds or installs ffmpeg.
2. **Analyze** - `analyze-audio.ps1` measures duration, speech regions and
   silent gaps, and checks quiet gaps for hidden sound.
3. **Listen** - recordings **under 30 minutes are heard whole**, in one piece.
   Recordings of **30 minutes or more** are cut by `split-audio.ps1` into
   10-minute pieces with 3 s overlap.
4. **Transcribe** - verbatim, Bangla in Bangla script, English words in Latin
   letters, `[?]` for uncertain words.
5. **Second pass** - the same audio is checked line by line.
6. **Coverage check** - `check-coverage.ps1` proves every speech region has
   transcript entries.
7. **Output and cleanup** - two files are written, the temp folder is removed.

`SKILL.md` contains a strict allowed/forbidden action list so the agent does
not improvise (no extra ffmpeg commands, no test clips, no tool hunting).

## Troubleshooting

| Problem | Fix |
|---|---|
| Skill not listed | Start a **new** session; check the folder path above |
| "scripts are disabled" | The installer and skill already use `-ExecutionPolicy Bypass`. If a company policy still blocks it, ask your IT admin |
| ffmpeg could not be installed | Run `winget install Gyan.FFmpeg`, then try again |
| "Request was blocked by Gemini's filters" | That is Google's safety filter, not the skill. Reply "continue", or switch to another Gemini model and retry |
| Quiet speech was missed | Ask the agent to re-run analysis with `-NoiseDb -45` |
| Agent starts cutting audio itself | Reinstall the latest version (older versions allowed it) |

## Privacy

Your audio is sent to whichever model your agent uses (for Antigravity,
Google's Gemini). ffmpeg runs locally and sends nothing anywhere.

## Limits

- Timestamps are the model's estimates (a few seconds off).
- Bangla and mixed-language speech can contain mistakes. Uncertain words are
  marked `[?]`. Spot-check important recordings.
- The coverage check proves no speech region was skipped, not that every word
  is correct.

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Uninstall
```

or delete the `transcribe-audio` folder from the skills folder.

## Contributing

Issues and pull requests are welcome. Keep all `.ps1` files plain ASCII with
CRLF line endings (Windows PowerShell 5.1 misreads UTF-8 without a BOM).
Run each script through the PowerShell parser before submitting.

## License

[MIT](LICENSE)
