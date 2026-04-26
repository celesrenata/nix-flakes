@echo off
REM OEM post-install script for dockurr/windows
REM Installs M365 and Adobe Creative Cloud, then signals the host

set OEMDIR=%~dp0
echo [%date% %time%] Starting OEM software installation... > %OEMDIR%install.log

REM Download and install Microsoft 365 via ODT
echo [%date% %time%] Downloading Office Deployment Tool... >> %OEMDIR%install.log
powershell -Command "Invoke-WebRequest -Uri 'https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_18324-20030.exe' -OutFile '%OEMDIR%odt.exe'" >> %OEMDIR%install.log 2>&1
if exist %OEMDIR%odt.exe (
    echo [%date% %time%] Extracting ODT... >> %OEMDIR%install.log
    start /wait %OEMDIR%odt.exe /quiet /extract:%OEMDIR%ODT
    if exist %OEMDIR%ODT\setup.exe (
        echo [%date% %time%] Installing M365... >> %OEMDIR%install.log
        copy %OEMDIR%m365config.xml %OEMDIR%ODT\m365config.xml
        start /wait %OEMDIR%ODT\setup.exe /configure %OEMDIR%ODT\m365config.xml
        echo [%date% %time%] M365 installation completed >> %OEMDIR%install.log
    ) else (
        echo [%date% %time%] ODT extraction failed >> %OEMDIR%install.log
    )
) else (
    echo [%date% %time%] ODT download failed >> %OEMDIR%install.log
)

REM Download and install Adobe Creative Cloud
echo [%date% %time%] Downloading Adobe Creative Cloud... >> %OEMDIR%install.log
powershell -Command "Invoke-WebRequest -Uri 'https://ccmdls.adobe.com/AdobeProducts/KCCC/1/win32/CreativeCloudSet-Up.exe' -OutFile '%OEMDIR%CreativeCloudSet-Up.exe'" >> %OEMDIR%install.log 2>&1
if exist %OEMDIR%CreativeCloudSet-Up.exe (
    echo [%date% %time%] Installing Adobe Creative Cloud... >> %OEMDIR%install.log
    start /wait %OEMDIR%CreativeCloudSet-Up.exe
    echo [%date% %time%] Adobe CC installer launched >> %OEMDIR%install.log
) else (
    echo [%date% %time%] Adobe CC download failed >> %OEMDIR%install.log
)

REM Signal the host via shared folder
echo [%date% %time%] Signaling host... >> %OEMDIR%install.log
if exist C:\Shared (
    echo done > C:\Shared\oem-complete
    copy %OEMDIR%install.log C:\Shared\install.log
)
if exist D:\Shared (
    echo done > D:\Shared\oem-complete
    copy %OEMDIR%install.log D:\Shared\install.log
)

echo [%date% %time%] OEM installation complete! >> %OEMDIR%install.log
