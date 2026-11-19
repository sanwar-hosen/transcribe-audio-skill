# Publishing (maintainer notes)

Nothing here is needed by users. Repo: https://github.com/sanwar-hosen/transcribe-audio-skill

## Push

```powershell
git remote add origin https://github.com/sanwar-hosen/transcribe-audio-skill.git
git push -u origin main
```

## Make the release zip

The zip must contain a single top-level folder `transcribe-audio-skill/`
with `Install.cmd` and `install.ps1` next to `skills\`. Exclude `.git` and
this file. Build it from a clean copy of the folder.

## Publish a release

GitHub -> **Releases** -> **Draft a new release** -> tag `v1.0.0` -> attach
`transcribe-audio-skill.zip` -> Publish.

## Polish

- Add topics: `agent-skills`, `antigravity`, `gemini`, `transcription`, `bangla`
- Test on a clean Windows account before announcing.
