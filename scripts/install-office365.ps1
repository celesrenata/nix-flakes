, 'y' * 2 | powershell -ExecutionPolicy Unrestricted -c Install-Script -Name Install-Office365Suite
cd 'C:\Program Files\WindowsPowerShell\Scripts'
powershell -ExecutionPolicy Unrestricted -command "& './Install-Office365Suite.ps1'"
