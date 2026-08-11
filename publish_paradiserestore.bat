@echo off
setlocal EnableExtensions

rem ParadiseRestore Workshop + Git publisher.
rem Edit WORKSHOP_ID and STEAM_USER before the first run.

set "ROOT=%~dp0"
set "WORKSHOP_ID=REPLACE_WITH_PARADISERESTORE_WORKSHOP_ID"
set "STEAM_USER=YOUR_STEAM_USERNAME"
set "STEAMCMD=%ProgramFiles(x86)%\Steam\steamcmd.exe"
set "APP_ID=108600"
set "CONTENT_FOLDER=%ROOT%42.20"
set "PREVIEW_FILE=%CONTENT_FOLDER%\poster.png"
set "VDF=%ROOT%workshop_item.vdf"
set "PUBLISH_VDF=%TEMP%\ParadiseRestore_workshop_item_%RANDOM%.vdf"
set "BRANCH=codex/b42-audit"

if "%WORKSHOP_ID%"=="REPLACE_WITH_PARADISERESTORE_WORKSHOP_ID" (
    echo ERROR: Set WORKSHOP_ID in this file first.
    exit /b 1
)
if "%STEAM_USER%"=="YOUR_STEAM_USERNAME" (
    echo ERROR: Set STEAM_USER in this file first.
    exit /b 1
)
if not exist "%STEAMCMD%" (
    echo ERROR: SteamCMD not found at "%STEAMCMD%".
    echo Install SteamCMD or edit STEAMCMD in this file.
    exit /b 1
)
if not exist "%CONTENT_FOLDER%\mod.info" (
    echo ERROR: Project Zomboid mod.info not found in "%CONTENT_FOLDER%".
    exit /b 1
)

echo === Uploading Workshop item %WORKSHOP_ID% ===
rem Fill the ID into a temporary VDF so the checked-in template stays reusable.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$v = Get-Content -Raw -LiteralPath $env:VDF; $v = $v.Replace('REPLACE_WITH_PARADISERESTORE_WORKSHOP_ID', $env:WORKSHOP_ID).Replace('__CONTENT_FOLDER__', $env:CONTENT_FOLDER).Replace('__PREVIEW_FILE__', $env:PREVIEW_FILE); Set-Content -LiteralPath $env:PUBLISH_VDF -Value $v -Encoding UTF8"
if errorlevel 1 (
    echo ERROR: Could not prepare the Workshop VDF.
    exit /b 1
)
"%STEAMCMD%" +login %STEAM_USER% +workshop_build_item "%PUBLISH_VDF%" +quit
del /q "%PUBLISH_VDF%" >nul 2>&1
if errorlevel 1 (
    echo ERROR: SteamCMD upload failed. Git will not be pushed.
    exit /b 1
)

echo === Committing and pushing Git ===
pushd "%ROOT%"
git add -A
git diff --cached --quiet
if not errorlevel 1 (
    echo No Git changes to commit.
    popd
    exit /b 0
)

for /f "tokens=1-3 delims=/ " %%a in ("%date%") do set "STAMP=%%c-%%a-%%b"
for /f "tokens=1-2 delims=: " %%a in ("%time%") do set "CLOCK=%%a%%b"
git commit -m "Publish ParadiseRestore Workshop update %STAMP%_%CLOCK%"
if errorlevel 1 (
    echo ERROR: Git commit failed.
    popd
    exit /b 1
)
git push -u origin %BRANCH%
if errorlevel 1 (
    echo ERROR: Git push failed.
    popd
    exit /b 1
)
popd

echo === Workshop and Git publish complete ===
exit /b 0
