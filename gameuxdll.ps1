<# : batch script
@echo off

REM :: This currently just assumes PowerShell is installed and tries to run the script.
REM :: In the future, I want to do something like this:
REM ::
REM :: 1. Look for PowerShell
REM :: 2. If PowerShell is found, automatically run script with the latest version installed
REM :: 2. If PowerShell is not found, perform internet and OS check to determine the latest version of PowerShell available for the detected OS
REM :: 3. If the internet is directly available, download and install said latest version before running script
REM :: 4. If the internet is not directly available, ask user to download and install said latest version themselves and then prompt to exit
REM :: 5. If no version available, the script is not supported for the OS - tell the user and then prompt to exit

REM :: Run script
powershell -nop Invoke-Expression ('$PSScriptRoot = """"%~dp0""' + [System.IO.File]::ReadAllText('%~f0'))
goto :eof
#>
<# REM ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: REM #>
<# REM :: Basic setup #>

<#
Currently, all of this is stolen from / based off of https://winclassic.net/post/8739 and
https://www.tenforums.com/gaming/207026-i-want-bring-back-game-explorer-removed-windows-10-1803-a-3.html#post2564725,
with some tweaks here and there.
#>

Set-Location $PSScriptRoot
$WinVersion = [System.Environment]::OSVersion.Version

<# REM :: TODO - Properly check Windows version in order to correctly import Games Explorer #>
<# REM :: Currently only assumes you're using Windows 10/11 #>
if ($WinVersion.Major == 10) { $global:prompt = 'This script will temporarily disable parts of Windows Defender and modify system files to give you Games Explorer.' }
else { $global:prompt = 'This script will modify system files to give you Games Explorer.' }
$choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))
$decision = $Host.UI.PromptForChoice($global:prompt, 'Choose [Y] to continue, or [N] to exit.', $choices, 1)
if (!($decision -eq 0)) {
    Write-Host "Exiting. No modifications have been made to your system."
    Exit 0
}

<# REM :: TODO - Remove dependency on IconGroup14.res #>
if (!(Test-Path 'IconGroup14.res')) {
    Write-Host "Missing resource file IconGroup14.res. No modifications have been made to your system.`n" -ForegroundColor Red
    Exit 1
} 

<# REM :: Detect Controlled folder access or read-only behavior #>
New-Item __readonlytest.txt -type file
if (!(Test-Path "__readonlytest.txt")) {
    try {
        if (Get-Command ConfigDefender\Get-MpPreference -CommandType Function -errorAction SilentlyContinue) {
            if ((Get-MpPreference).EnableControlledFolderAccess) {
                $ProtectedFolders = ($((Get-MpPreference).ControlledFolderAccessDefaultProtectedFolders; (Get-MpPreference).ControlledFolderAccessProtectedFolders) | Where-Object { $null -ne $_ })
                $global:CFAToDisable = 0
                $global:CFADisabled = 0
                try {
                    foreach ($folder in $ProtectedFolders) {
                        if ($PSScriptRoot -like "$folder*") {
                            Write-Host "This script is inside of $folder, a folder protected by Controlled folder access.`n" -ForegroundColor Yellow
                            $global:CFAToDisable = 1
                        }
                    }
                } finally {
                    if ($global:CFAToDisable == 1) {
                        try {
                            Set-MpPreference -EnableControlledFolderAccess Disabled
                            $global:CFADisabled = 1
                            Write-Host "Controlled folder access has been temporarily disabled. It will be re-enabled when the script is done.`n" -ForegroundColor Yellow
                        } catch {
                            Write-Host "Could not disable Controlled folder access. Please disable it yourself in Windows Defender and try again.`n" -ForegroundColor Red
                            Exit 1
                        }
                    }
                }
            }
        }
    } finally {
        New-Item __readonlytest.txt -type file
        if (!(Test-Path "__readonlytest.txt")) {
            Write-Host "Could not write test file. Please move to a directory that is not read-only.`n" -ForegroundColor Red
            Exit 1
        }
    }

}

<# REM ::  #>
$registry = @"
Windows Registry Editor Version 5.00

[HKEY_CLASSES_ROOT\CLSID\{06EEE695-542D-46F6-AEAB-FA2F1B2102D3}]
@="GameCleanupHandler Class"

[HKEY_CLASSES_ROOT\CLSID\{06EEE695-542D-46F6-AEAB-FA2F1B2102D3}\InprocServer32]
@="C:\\Windows\\System32\\gameux.dll"
"ThreadingModel"="Both"

[HKEY_CLASSES_ROOT\CLSID\{2e7583c7-7eba-4a1a-8468-d03d28477e6f}]
@="Shell settings migration"

[HKEY_CLASSES_ROOT\CLSID\{2e7583c7-7eba-4a1a-8468-d03d28477e6f}\InProcServer32]
@=hex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,\
  00,5c,00,53,00,79,00,73,00,74,00,65,00,6d,00,33,00,32,00,5c,00,6d,00,69,00,\
  67,00,72,00,61,00,74,00,69,00,6f,00,6e,00,5c,00,67,00,61,00,6d,00,65,00,75,\
  00,78,00,6d,00,69,00,67,00,2e,00,64,00,6c,00,6c,00,00,00
"ThreadingModel"="Apartment"

[HKEY_CLASSES_ROOT\CLSID\{6C5CFCDA-1F1A-4c9e-8D65-94771169D0B9}]
@="GameDetails Class"

[HKEY_CLASSES_ROOT\CLSID\{6C5CFCDA-1F1A-4c9e-8D65-94771169D0B9}\InprocServer32]
@="C:\\Windows\\System32\\gameux.dll"
"ThreadingModel"="Apartment"

[HKEY_CLASSES_ROOT\CLSID\{709E2729-F883-441e-A877-ED3CEFC975E6}]
@="ProfileNotifyHandler Class"
"AppID"="{E10F6C3A-F1AE-4adc-AA9D-2FE65525666E}"

[HKEY_CLASSES_ROOT\CLSID\{709E2729-F883-441e-A877-ED3CEFC975E6}\InprocServer32]
@="C:\\Windows\\System32\\gameux.dll"
"ThreadingModel"="Apartment"

[HKEY_CLASSES_ROOT\CLSID\{9A5EA990-3034-4D6F-9128-01F3C61022BC}]
@="GameExplorer Class"

[HKEY_CLASSES_ROOT\CLSID\{9A5EA990-3034-4D6F-9128-01F3C61022BC}\InprocServer32]
@="C:\\Windows\\System32\\gameux.dll"
"ThreadingModel"="Both"

[HKEY_CLASSES_ROOT\CLSID\{9A5EA990-3034-4D6F-9128-01F3C61022BC}\Programmable]

[HKEY_CLASSES_ROOT\CLSID\{CA22F5B1-E06F-4A2B-94FC-21E87FE53781}]
@="GameUpdateTask Class"

[HKEY_CLASSES_ROOT\CLSID\{CA22F5B1-E06F-4A2B-94FC-21E87FE53781}\InprocServer32]
@="C:\\Windows\\System32\\gameux.dll"
"ThreadingModel"="Both"

[HKEY_CLASSES_ROOT\CLSID\{DBC85A2C-C0DC-4961-B6E2-D28B62C11AD4}]
@="GameStatistics Class"

[HKEY_CLASSES_ROOT\CLSID\{DBC85A2C-C0DC-4961-B6E2-D28B62C11AD4}\InprocServer32]
@="C:\\Windows\\System32\\gameux.dll"
"ThreadingModel"="Apartment"

[HKEY_CLASSES_ROOT\CLSID\{E7B2FB72-D728-49B3-A5F2-18EBF5F1349E}]
@="PSFactoryBuffer"

[HKEY_CLASSES_ROOT\CLSID\{E7B2FB72-D728-49B3-A5F2-18EBF5F1349E}\InProcServer32]
@="C:\\Windows\\System32\\gameux.dll"
"ThreadingModel"="Both"

[HKEY_CLASSES_ROOT\CLSID\{ED228FDF-9EA8-4870-83b1-96b02CFE0D52}]
@="Games Explorer"
"InfoTip"="Play and Manage Games."
"LocalizedString"=hex(2):40,00,25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,\
  6f,00,6f,00,74,00,25,00,5c,00,73,00,79,00,73,00,74,00,65,00,6d,00,33,00,32,\
  00,5c,00,73,00,68,00,65,00,6c,00,6c,00,33,00,32,00,2e,00,64,00,6c,00,6c,00,\
  2c,00,2d,00,33,00,30,00,35,00,37,00,39,00,00,00
"System.AppUserModel.ID"="Microsoft.Windows.GamesExplorer"
"System.AppUserModel.RelaunchCommand"="%SystemRoot%\\explorer.exe shell:::{ED228FDF-9EA8-4870-83b1-96b02CFE0D52}"
"System.AppUserModel.RelaunchDisplayNameResource"="@%SystemRoot%\\system32\\shell32.dll,-30579"
"System.AppUserModel.RelaunchIconResource"="%SystemRoot%\\system32\\imageres.dll,-14"

[HKEY_CLASSES_ROOT\CLSID\{ED228FDF-9EA8-4870-83b1-96b02CFE0D52}\DefaultIcon]
@="C:\\Windows\\System32\\imageres.dll,-14"

[HKEY_CLASSES_ROOT\CLSID\{ED228FDF-9EA8-4870-83b1-96b02CFE0D52}\InprocServer32]
@="C:\\Windows\\System32\\gameux.dll"
"ThreadingModel"="Apartment"

[HKEY_CLASSES_ROOT\CLSID\{ED228FDF-9EA8-4870-83b1-96b02CFE0D52}\Programmable]

[HKEY_CLASSES_ROOT\CLSID\{ED228FDF-9EA8-4870-83b1-96b02CFE0D52}\ShellFolder]
"Attributes"=dword:20100130
"FolderValueFlags"=dword:00000000

[HKEY_CLASSES_ROOT\CLSID\{F382DA49-9148-4a22-AF78-C378DFC32D02}]
@="MS_InstalledGameProv Class"

[HKEY_CLASSES_ROOT\CLSID\{F382DA49-9148-4a22-AF78-C378DFC32D02}\InprocServer32]
@="C:\\Windows\\System32\\gameux.dll"
"ThreadingModel"="Both"

[HKEY_CLASSES_ROOT\WOW6432Node\CLSID\{06EEE695-542D-46F6-AEAB-FA2F1B2102D3}]
@="GameCleanupHandler Class"

[HKEY_CLASSES_ROOT\WOW6432Node\CLSID\{06EEE695-542D-46F6-AEAB-FA2F1B2102D3}\InprocServer32]
@="C:\\Windows\\SysWOW64\\gameux.dll"
"ThreadingModel"="Both"

[HKEY_CLASSES_ROOT\WOW6432Node\CLSID\{2e7583c7-7eba-4a1a-8468-d03d28477e6f}]
@="Shell settings migration"

[HKEY_CLASSES_ROOT\WOW6432Node\CLSID\{2e7583c7-7eba-4a1a-8468-d03d28477e6f}\InProcServer32]
@=hex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,\
  00,5c,00,53,00,79,00,73,00,74,00,65,00,6d,00,33,00,32,00,5c,00,6d,00,69,00,\
  67,00,72,00,61,00,74,00,69,00,6f,00,6e,00,5c,00,67,00,61,00,6d,00,65,00,75,\
  00,78,00,6d,00,69,00,67,00,2e,00,64,00,6c,00,6c,00,00,00
"ThreadingModel"="Apartment"

[HKEY_CLASSES_ROOT\WOW6432Node\CLSID\{6C5CFCDA-1F1A-4c9e-8D65-94771169D0B9}]
@="GameDetails Class"

[HKEY_CLASSES_ROOT\WOW6432Node\CLSID\{6C5CFCDA-1F1A-4c9e-8D65-94771169D0B9}\InprocServer32]
@="C:\\Windows\\SysWOW64\\gameux.dll"
"ThreadingModel"="Apartment"

[HKEY_CLASSES_ROOT\WOW6432Node\CLSID\{709E2729-F883-441e-A877-ED3CEFC975E6}]
@="ProfileNotifyHandler Class"
"AppID"="{E10F6C3A-F1AE-4adc-AA9D-2FE65525666E}"

[HKEY_CLASSES_ROOT\WOW6432Node\CLSID\{709E2729-F883-441e-A877-ED3CEFC975E6}\InprocServer32]
@="C:\\Windows\\SysWOW64\\gameux.dll"
"ThreadingModel"="Apartment"

[HKEY_CLASSES_ROOT\WOW6432Node\CLSID\{9A5EA990-3034-4D6F-9128-01F3C61022BC}]
@="GameExplorer Class"

[HKEY_CLASSES_ROOT\WOW6432Node\CLSID\{9A5EA990-3034-4D6F-9128-01F3C61022BC}\InprocServer32]
@="C:\\Windows\\SysWOW64\\gameux.dll"
"ThreadingModel"="Both"

[HKEY_CLASSES_ROOT\WOW6432Node\CLSID\{9A5EA990-3034-4D6F-9128-01F3C61022BC}\Programmable]

[HKEY_CLASSES_ROOT\WOW6432Node\CLSID\{CA22F5B1-E06F-4A2B-94FC-21E87FE53781}]
@="GameUpdateTask Class"

[HKEY_CLASSES_ROOT\WOW6432Node\CLSID\{CA22F5B1-E06F-4A2B-94FC-21E87FE53781}\InprocServer32]
@="C:\\Windows\\SysWOW64\\gameux.dll"
"ThreadingModel"="Both"

[HKEY_CLASSES_ROOT\WOW6432Node\CLSID\{DBC85A2C-C0DC-4961-B6E2-D28B62C11AD4}]
@="GameStatistics Class"

[HKEY_CLASSES_ROOT\WOW6432Node\CLSID\{DBC85A2C-C0DC-4961-B6E2-D28B62C11AD4}\InprocServer32]
@="C:\\Windows\\SysWOW64\\gameux.dll"
"ThreadingModel"="Apartment"

[HKEY_CLASSES_ROOT\WOW6432Node\CLSID\{E7B2FB72-D728-49B3-A5F2-18EBF5F1349E}]
@="PSFactoryBuffer"

[HKEY_CLASSES_ROOT\WOW6432Node\CLSID\{E7B2FB72-D728-49B3-A5F2-18EBF5F1349E}\InProcServer32]
@="C:\\Windows\\SysWOW64\\gameux.dll"
"ThreadingModel"="Both"

[HKEY_CLASSES_ROOT\WOW6432Node\CLSID\{ED228FDF-9EA8-4870-83b1-96b02CFE0D52}]
@="Games Explorer"
"InfoTip"="Play and Manage Games."
"LocalizedString"=hex(2):40,00,25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,\
  6f,00,6f,00,74,00,25,00,5c,00,73,00,79,00,73,00,74,00,65,00,6d,00,33,00,32,\
  00,5c,00,73,00,68,00,65,00,6c,00,6c,00,33,00,32,00,2e,00,64,00,6c,00,6c,00,\
  2c,00,2d,00,33,00,30,00,35,00,37,00,39,00,00,00
"System.AppUserModel.ID"="Microsoft.Windows.GamesExplorer"
"System.AppUserModel.RelaunchCommand"="%SystemRoot%\\explorer.exe shell:::{ED228FDF-9EA8-4870-83b1-96b02CFE0D52}"
"System.AppUserModel.RelaunchDisplayNameResource"="@%SystemRoot%\\system32\\shell32.dll,-30579"
"System.AppUserModel.RelaunchIconResource"="%SystemRoot%\\system32\\imageres.dll,-14"

[HKEY_CLASSES_ROOT\WOW6432Node\CLSID\{ED228FDF-9EA8-4870-83b1-96b02CFE0D52}\DefaultIcon]
@="C:\\Windows\\SysWOW64\\imageres.dll,-14"

[HKEY_CLASSES_ROOT\WOW6432Node\CLSID\{ED228FDF-9EA8-4870-83b1-96b02CFE0D52}\InprocServer32]
@="C:\\Windows\\SysWOW64\\gameux.dll"
"ThreadingModel"="Apartment"

[HKEY_CLASSES_ROOT\WOW6432Node\CLSID\{ED228FDF-9EA8-4870-83b1-96b02CFE0D52}\Programmable]

[HKEY_CLASSES_ROOT\WOW6432Node\CLSID\{ED228FDF-9EA8-4870-83b1-96b02CFE0D52}\ShellFolder]
"Attributes"=dword:20100130
"FolderValueFlags"=dword:00000000

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{ED228FDF-9EA8-4870-83b1-96b02CFE0D52}]
"Removal Message"="@gameux.dll,-10038"

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{CAC52C1A-B53D-4edc-92D7-6B2E8AC19434}]
"Name"="Games"
"Category"=dword:00000001
"ParsingName"="::{ED228FDF-9EA8-4870-83b1-96b02CFE0D52}"

[HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\explorer\FolderDescriptions\{CAC52C1A-B53D-4edc-92D7-6B2E8AC19434}]
"Name"="Games"
"Category"=dword:00000001
"ParsingName"="::{ED228FDF-9EA8-4870-83b1-96b02CFE0D52}"

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\GameNewsFiles]
@="{06EEE695-542D-46F6-AEAB-FA2F1B2102D3}"
"Autorun"=dword:00000001
"IconPath"="C:\\Windows\\System32\\gameux.dll,-203"
"Priority"=dword:000000c8

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\GameStatisticsFiles]
@="{06EEE695-542D-46F6-AEAB-FA2F1B2102D3}"
"Autorun"=dword:00000001
"IconPath"="C:\\Windows\\System32\\gameux.dll,-203"
"Priority"=dword:000000c8

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\GameUpdateFiles]
@="{06EEE695-542D-46F6-AEAB-FA2F1B2102D3}"
"Autorun"=dword:00000001
"IconPath"="C:\\Windows\\System32\\gameux.dll,-203"
"Priority"=dword:000000c8

[HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{ED228FDF-9EA8-4870-83b1-96b02CFE0D52}]
"Removal Message"="@gameux.dll,-10038"

[HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\GameNewsFiles]
@="{06EEE695-542D-46F6-AEAB-FA2F1B2102D3}"
"Autorun"=dword:00000001
"IconPath"="C:\\Windows\\SysWOW64\\gameux.dll,-203"
"Priority"=dword:000000c8

[HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\GameStatisticsFiles]
@="{06EEE695-542D-46F6-AEAB-FA2F1B2102D3}"
"Autorun"=dword:00000001
"IconPath"="C:\\Windows\\SysWOW64\\gameux.dll,-203"
"Priority"=dword:000000c8

[HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\GameUpdateFiles]
@="{06EEE695-542D-46F6-AEAB-FA2F1B2102D3}"
"Autorun"=dword:00000001
"IconPath"="C:\\Windows\\SysWOW64\\gameux.dll,-203"
"Priority"=dword:000000c8
"@
New-Item __gameux_dll.reg -type file -Value $registry

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$global:7zrOnline = 0
$global:RHOnline = 0
if (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -like "7-Zip*"}) {
    $global:7z = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -like "7-Zip*"}).DisplayIcon.replace('7zFM.exe', '7z.exe')
} elseif (!(Test-Path "$PSScriptRoot\__7zr.exe")) {
    $global:7zrOnline = 1
    Write-Host "Downloading 7-Zip Reduced Standalone Console`n" -ForegroundColor Green;
    Invoke-WebRequest -UseBasicParsing -Uri 'https://www.7-zip.org/a/7zr.exe' -OutFile "$PSScriptRoot\__7zr.exe"
    $global:7z = "$PSScriptRoot\__7zr.exe"
}

if (!(Test-Path "ResourceHacker.exe")) {
    $global:RHOnline = 1
    Write-Host "Downloading Resource Hacker`n" -ForegroundColor Green;
    # Alternative: Resource Cracker https://www.pelock.com/products/resource-cracker
    Invoke-WebRequest -UseBasicParsing -Uri 'http://www.angusj.com/resourcehacker/resource_hacker.zip' -OutFile '__resource_hacker.zip'
    # Alternative: Resource Cracker https://www.pelock.com/download/resource-cracker.zip
    $objShell = New-Object -ComObject 'Shell.Application'
    $objFolder = $objShell.NameSpace($PSScriptRoot)
    $objFolder.CopyHere("$PSScriptRoot\__resource_hacker.zip\ResourceHacker.exe", 0x14)
    Remove-Item __resource_hacker.zip
}

Write-Host "Stopping explorer.exe`n" -ForegroundColor Green;
Stop-Process -Name explorer -Force
Start-Sleep -Seconds 1

<# REM :: Replace this with ISO/WIM/ESD fetching/mounting #>
Invoke-WebRequest -UseBasicParsing -Uri 'https://files.catbox.moe/47fez4.dll' -OutFile 'C:\Windows\System32\gameux.dll'
Invoke-WebRequest -UseBasicParsing -Uri 'https://files.catbox.moe/yao9vo.mui' -OutFile 'C:\Windows\System32\en-US\gameux.dll.mui'
Invoke-WebRequest -UseBasicParsing -Uri 'https://files.catbox.moe/pyl94e.dll' -OutFile 'C:\Windows\System32\GameUXLegacyGDFs.dll'
Invoke-WebRequest -UseBasicParsing -Uri 'https://files.catbox.moe/lbvly4.dll' -OutFile 'C:\Windows\System32\Migration\gameuxmig.dll'
Invoke-WebRequest -UseBasicParsing -Uri 'https://files.catbox.moe/rcpule.7z' -OutFile '32bit.7z'

if (!(Test-Path '__gameux_dll.reg')) { 
    Write-Host "Missing registry file (that we just attempted to create). No modifications have been made to your system.`n" -ForegroundColor Red;
    Exit 1
}

& $global:7z -aoa x '32bit.7z' -o 32bit | Out-Null

Push-Location 32bit
Copy-Item * -Destination 'C:\Windows\SysWOW64' -Recurse -Force
Pop-Location

if ($global:7zrOnline == 1) { Remove-Item "$PSScriptRoot\__7zr.exe" }
Remove-Item -Recurse '32bit.7z', '32bit'

Write-Host "Modifying Windows registry`n" -ForegroundColor Green;
& reg import __gameux_dll.reg

<# REM :: Modify imageres.dll.mun #>
Write-Host "Writing to imageres.dll.mun`n" -ForegroundColor Green;
$DLL_mun = [System.Environment]::ExpandEnvironmentVariables("%SystemRoot%\SystemResources\imageres.dll.mun")
$BACKUP_mun = $DLL_mun -replace ".mun$", "-ORIG.mun"
$OLD_mun = $DLL_mun -replace ".mun$", "-OLD.mun"

if (!(Test-Path $BACKUP_mun)) {
    Copy-Item $DLL_mun $BACKUP_mun
}

Start-Process "$PSScriptRoot\ResourceHacker.exe" -ArgumentList "-open $BACKUP_mun -save imageres.dll.mun -action addoverwrite -res IconGroup14.res -mask ICONGROUP,14," -Wait
if ($global:RHOnline == 1) { Remove-Item -Recurse 'ResourceHacker.exe', 'ResourceHacker.ini' }
Move-Item $DLL_mun $OLD_mun -Force
Move-Item "$PSScriptRoot\imageres.dll.mun" -Destination $DLL_mun -Force
Stop-Process -Name explorer -Force
Remove-Item $OLD_mun


<# TODO: Give all users access/control over HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\GameUX #>

& Start-Process "$SystemRoot\explorer.exe" -ArgumentList "shell:games"

foreach ($User in ((Get-CimInstance -ClassName Win32_ComputerSystem).UserName | Split-Path -Leaf)) {
    Write-Host "Creating Games Explorer shortcut on the Desktop of user $User`n" -ForegroundColor Green;
    $SID = (Get-WmiObject -Namespace root/cimv2 -Class Win32_UserAccount -Filter "LocalAccount=True AND Name='$User'").SID
    $UserProfile = (Get-WmiObject -Namespace root/cimv2 -Class Win32_UserProfile -Filter "SID='$SID'").LocalPath

    $ShortcutPath = "$UserProfile\Desktop\Games Explorer.lnk"

    $objShell = New-Object -ComObject ('WScript.Shell')
    $Shortcut = $objShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = 'C:\Windows\explorer.exe'
    $Shortcut.Arguments = 'shell:games'
    $Shortcut.IconLocation = 'C:\Windows\System32\gameux.dll,0'
    $Shortcut.Save()
}

if ($global:CFADisabled == 1) { 
    Write-Host "Almost done! Re-enabling Controlled folder access`n" -ForegroundColor Green;
    Set-MpPreference -EnableControlledFolderAccess Enabled
}

if ((Get-ChildItem 'C:\Windows\Performance\WinSAT\DataStore').Count -eq 0) {
    Write-Host "Almost done! Running the Windows System Assessment Tool to measure your Windows Experience Index (WEI) score`n" -ForegroundColor Green;
    & winsat formal
}
