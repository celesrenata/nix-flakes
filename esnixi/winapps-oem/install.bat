@echo off
REM OEM post-install script for dockurr/windows
REM Installs M365 and Adobe Creative Cloud, then signals the host

echo [%date% %time%] Starting OEM software installation... > C:\OEM\install.log

REM Download and install Microsoft 365
echo [%date% %time%] Installing Microsoft 365... >> C:\OEM\install.log
powershell -Command "Invoke-WebRequest -Uri 'https://c2rsetup.officeapps.live.com/c2r/download.aspx?ProductreleaseID=O365ProPlusRetail&platform=x64&language=en-us&version=O16GA' -OutFile 'C:\OEM\m365setup.exe'" >> C:\OEM\install.log 2>&1
if exist C:\OEM\m365setup.exe (
    start /wait C:\OEM\m365setup.exe /configure C:\OEM\m365config.xml
    echo [%date% %time%] M365 installation completed >> C:\OEM\install.log
) else (
    echo [%date% %time%] M365 download failed, using ODT instead >> C:\OEM\install.log
    powershell -Command "Invoke-WebRequest -Uri 'https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_18324-20030.exe' -OutFile 'C:\OEM\odt.exe'" >> C:\OEM\install.log 2>&1
    if exist C:\OEM\odt.exe (
        start /wait C:\OEM\odt.exe /quiet /extract:C:\OEM\ODT
        start /wait C:\OEM\ODT\setup.exe /configure C:\OEM\m365config.xml
    )
)

REM Download and install Adobe Creative Cloud
echo [%date% %time%] Installing Adobe Creative Cloud... >> C:\OEM\install.log
powershell -Command "Invoke-WebRequest -Uri 'https://ccmdl.adobe.com/AdobeProducts/KCCC/CCD/5_13/win64/ACCCx5_13_0_19.zip' -OutFile 'C:\OEM\acc.zip'" >> C:\OEM\install.log 2>&1
if exist C:\OEM\acc.zip (
    powershell -Command "Expand-Archive -Path 'C:\OEM\acc.zip' -DestinationPath 'C:\OEM\ACC' -Force" >> C:\OEM\install.log 2>&1
    start /wait C:\OEM\ACC\Set-up.exe --silent
    echo [%date% %time%] Adobe CC installation completed >> C:\OEM\install.log
)

REM Signal the host that installation is complete
echo [%date% %time%] Signaling host... >> C:\OEM\install.log
echo done > \\host.lan\Data\oem-complete
copy C:\OEM\install.log \\host.lan\Data\install.log

REM Also write to shared folder
echo done > Z:\oem-complete
copy C:\OEM\install.log Z:\install.log

echo [%date% %time%] OEM installation complete! >> C:\OEM\install.log
