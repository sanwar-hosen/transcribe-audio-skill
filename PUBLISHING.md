# Publishing to GitHub (maintainer notes)

Nothing here is needed by users. Replace `YOUR-USERNAME` throughout.

## 1. Fill in the placeholder

In `install.ps1`, change the default:

```powershell
[string]$Repo = 'YOUR-USERNAME/transcribe-audio-skill',
```

Then in `README.md`, replace `YOUR-USERNAME` in Option D.

## 2. Create the repo and push

On github.com: **New repository** -> name `transcribe-audio-skill` -> Public ->
do NOT add a README or license (they already exist) -> Create.

```powershell
git init -b main
git add .
git commit -m "Initial release v1.0.0"
git remote add origin https://github.com/YOUR-USERNAME/transcribe-audio-skill.git
git push -u origin main
```

## 3. Make the release zip

The zip must contain a single top-level folder `transcribe-audio-skill/`
with `Install.cmd` and `install.ps1` next to `skills\`. Build it with:

```powershell
Compress-Archive -Path . -DestinationPath ..\transcribe-audio-skill.zip
```

(Exclude `.git`. Easiest is to build the zip from a clean copy of the folder.)

## 4. Publish a release

GitHub -> **Releases** -> **Draft a new release** -> tag `v1.0.0` -> attach
`transcribe-audio-skill.zip` -> Publish.

## 5. Polish

- Add topics: `agent-skills`, `antigravity`, `gemini`, `transcription`, `bangla`
- Test on a clean Windows account before announcing.
