@echo off
REM OEM post-install script for dockurr/windows
REM Installs M365, Adobe Creative Cloud + apps, and Ninite utilities

set OEMDIR=%~dp0
echo [%date% %time%] Starting OEM software installation... > %OEMDIR%install.log

REM Install Microsoft 365 Apps via winget
echo [%date% %time%] Installing Microsoft 365... >> %OEMDIR%install.log
winget install Microsoft.Office --source winget --accept-source-agreements --accept-package-agreements >> %OEMDIR%install.log 2>&1
echo [%date% %time%] M365 install completed >> %OEMDIR%install.log

REM Install Adobe Creative Cloud via winget
echo [%date% %time%] Installing Adobe Creative Cloud... >> %OEMDIR%install.log
winget install Adobe.CreativeCloud --source winget --accept-source-agreements --accept-package-agreements >> %OEMDIR%install.log 2>&1
echo [%date% %time%] Adobe CC install completed >> %OEMDIR%install.log

REM Install individual Adobe apps via winget where available
echo [%date% %time%] Installing Adobe Photoshop... >> %OEMDIR%install.log
winget install Adobe.Photoshop --source winget --accept-source-agreements --accept-package-agreements >> %OEMDIR%install.log 2>&1
echo [%date% %time%] Installing Adobe Lightroom... >> %OEMDIR%install.log
winget install Adobe.Lightroom --source winget --accept-source-agreements --accept-package-agreements >> %OEMDIR%install.log 2>&1
echo [%date% %time%] Installing Adobe Lightroom Classic... >> %OEMDIR%install.log
winget install Adobe.LightroomClassic --source winget --accept-source-agreements --accept-package-agreements >> %OEMDIR%install.log 2>&1
echo [%date% %time%] Installing Adobe Camera Raw... >> %OEMDIR%install.log
echo [%date% %time%] Installing Adobe Acrobat Reader... >> %OEMDIR%install.log
winget install Adobe.Acrobat.Reader.64-bit --source winget --accept-source-agreements --accept-package-agreements >> %OEMDIR%install.log 2>&1
winget install Adobe.CameraRaw --source winget --accept-source-agreements --accept-package-agreements >> %OEMDIR%install.log 2>&1
echo [%date% %time%] Adobe apps install completed >> %OEMDIR%install.log

REM Run Ninite installer (7zip, Notepad++, PuTTY, TeamViewer, VS Code, WinDirStat, Zoom)
if exist %OEMDIR%ninite.exe (
    echo [%date% %time%] Running Ninite installer... >> %OEMDIR%install.log
    start /wait %OEMDIR%ninite.exe >> %OEMDIR%install.log 2>&1
    echo [%date% %time%] Ninite install completed >> %OEMDIR%install.log
) else (
    echo [%date% %time%] No ninite.exe found, skipping >> %OEMDIR%install.log
)

REM Signal the host
echo [%date% %time%] Signaling host... >> %OEMDIR%install.log
echo done > %OEMDIR%oem-complete
echo [%date% %time%] OEM installation complete! >> %OEMDIR%install.log
