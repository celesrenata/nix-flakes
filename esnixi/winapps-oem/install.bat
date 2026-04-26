@echo off
REM OEM post-install script for dockurr/windows
REM Installs M365 and Adobe Creative Cloud via winget

set OEMDIR=%~dp0
echo [%date% %time%] Starting OEM software installation... > %OEMDIR%install.log

REM Install Microsoft 365 Apps
echo [%date% %time%] Installing Microsoft 365... >> %OEMDIR%install.log
winget install Microsoft.Office --source winget --accept-source-agreements --accept-package-agreements >> %OEMDIR%install.log 2>&1
echo [%date% %time%] M365 install completed >> %OEMDIR%install.log

REM Install Adobe Creative Cloud
echo [%date% %time%] Installing Adobe Creative Cloud... >> %OEMDIR%install.log
winget install Adobe.CreativeCloud --source winget --accept-source-agreements --accept-package-agreements >> %OEMDIR%install.log 2>&1
echo [%date% %time%] Adobe CC install completed >> %OEMDIR%install.log

REM Signal the host
echo [%date% %time%] Signaling host... >> %OEMDIR%install.log
echo done > %OEMDIR%oem-complete
echo [%date% %time%] OEM installation complete! >> %OEMDIR%install.log
