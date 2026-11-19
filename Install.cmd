@echo off
rem Double-click to install the transcribe-audio skill for Antigravity.
rem For Claude Code instead, run:  Install.cmd -Agent Claude
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
echo.
pause
