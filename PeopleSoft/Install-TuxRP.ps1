<#
.SYNOPSIS
Install-TuxRP will install a Tuxedo RP for an application server, message server, or process scheduler
from a network share.

.INPUTS
None.  The script is self-contained.

.OUTPUTS
Install-TuxRP does not produce object output.  A log file is written with the script results.

.EXAMPLES
.\Install-TuxRP.ps1

.NOTES
This script does not restart the PSEM agent service if it was running when the script executed.
#>

#Set the script variables:
$env:Path = "F:\oracle\product\11.2.0.3\client_64\bin;$env:TUXDIR\bin;$env:TUXDIR\jre\bin;C:\Windows\system32;C:\Windows;C:\Windows\System32\Wbem;C:\Windows\System32\WindowsPowerShell\v1.0\"
$Server = $env:COMPUTERNAME
$TuxRPDir = "\\path.to.your\SoftwareShare\Tuxedo\RP"
$LogLocation = "F:\TuxRPInstallLog.txt"
if ((Test-Path $LogLocation) -eq $True)
{
    Remove-Item $LogLocation -Force
}
#Create the e-mail function for the installation log:
function SendPackageInstallLog
{
    Send-MailMessage -From "cs-sccm@example.com" -To "you@example.com" -Subject "Tuxedo RP Package Install Log from $Server" -Body "Attached is the SCCM Tuxedo RP package installation log for $Server" -Attachments $LogLocation -SmtpServer "smtp.example.com"
}

#Stop the app server services:
$PeopleSoftService = Get-Service | Where-Object {$_.Name -like "*PeopleSoft*"}
if ($PeopleSoftService)
{
    Stop-Service -InputObject $PeopleSoftService -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    $PeopleSoftService.WaitForStatus('Stopped','00:03:00')
    if ($PeopleSoftService.Status -eq "Stopped")
    {
        Add-Content $LogLocation "PeopleSoft service successfully stopped on $Server"
    }
    else
    {
        Add-Content $LogLocation "ERROR - PeopleSoft service did NOT successfully stop on $Server"
        SendPackageInstallLog
        exit
    }
}
$PSEMService = Get-Service | Where-Object {$_.Name -like "*PSEM*"}
if ($PSEMService)
{
    if ($PSEMService.Status -eq "Running")
    {
        Stop-Service -InputObject $PSEMService -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        $PSEMService.WaitForStatus('Stopped','00:03:00')
        if ($PSEMService.Status -eq "Stopped")
        {
            Add-Content $LogLocation "PSEM service successfully stopped on $Server"
        }
        else
        {
            Add-Content $LogLocation "ERROR - PSEM service did NOT successfully stop on $Server"
            SendPackageInstallLog
            exit
        }
    }
}
$TListenService = Get-Service | Where-Object {$_.Name -like "*Listener*"}
if ($TListenService)
{
    if ($TListenService.Status -eq "Running")
    {
        Stop-Service -InputObject $TListenService -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        $TListenService.WaitForStatus('Stopped','00:03:00')
        if ($TListenService.Status -eq "Stopped")
        {
            Add-Content $LogLocation "TListen service successfully stopped on $Server"
        }
        else
        {
            Add-Content $LogLocation "ERROR - TListen service did NOT successfully stop on $Server"
            SendPackageInstallLog
            exit
        }
    }
}
$TuxedoService = Get-Service | Where-Object {$_.Name -like "*ProcMGR*"}
if ($TuxedoService)
{
    Stop-Service -InputObject $TuxedoService -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    $TuxedoService.WaitForStatus('Stopped','00:03:00')
    if ($TuxedoService.Status -eq "Stopped")
    {
        Add-Content $LogLocation "Tuxedo service successfully stopped on $Server"
    }
    else
    {
        Add-Content $LogLocation "ERROR - Tuxedo service did NOT successfully stop on $Server"
        SendPackageInstallLog
        exit
    }
}

#Check to see if there is an uninstaller present, if not, skip to the RP installation:
$UninstallPath = Test-Path "$env:TUXDIR\RP_uninstaller"
if ($UninstallPath -eq $True)
{
    #Call the Tuxedo uninstaller:
    Set-Location "$env:TUXDIR\RP_uninstaller"
    $UninstallExecutable = Get-ChildItem | Where-Object {$_.Name -like "*uninstallMain.exe*"} | Select -ExpandProperty Name
    $UninstallArguments =  "-i silent"
    if ($UninstallExecutable -ne $null)
    {
        Start-Process $UninstallExecutable -ArgumentList $UninstallArguments -Wait -Verb runas
        Add-Content $LogLocation "Old RP uninstall process started on $Server"
    }
    else
    {
        Set-Location $env:TUXDIR
        Remove-Item "RP_uninstaller" -Recurse -Force
        if ($?)
        {
            Add-Content $LogLocation "Old RP_uninstaller removed from $Server"
        }
        else
        {
            Add-Content $LogLocation "ERROR - Old RP_uninstall NOT successfully removed from $Server"
            SendPackageInstallLog
            exit
        }
    }

    #Remove the leftover pieces from the old RP:
    if ((Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Oracle ProcMGR V11.1.1.2.0') -eq $True)
    {
        Remove-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Oracle ProcMGR V11.1.1.2.0' -Recurse -Force
        if ($?)
        {
            Add-Content $LogLocation "Old RP service registry key removed on $Server"
        }
        else
        {
            Add-Content $LogLocation "ERROR - Old RP service registry key could NOT be removed on $Server"
            SendPackageInstallLog
            exit
        }
    }
    if ((Test-Path 'HKLM:\SOFTWARE\ORACLE\Tuxedo v11.1.1.2.0_VS2010 Patch') -eq $True)
    {
        Remove-Item -Path 'HKLM:\SOFTWARE\ORACLE\Tuxedo v11.1.1.2.0_VS2010 Patch' -Recurse -Force
        if ($?)
        {
            Add-Content $LogLocation "Old RP patch registry key removed on $Server"
        }
        else
        {
            Add-Content $LogLocation "ERROR - Old RP patch registry key could NOT be removed on $Server"
            SendPackageInstallLog
            exit
        }
    }

    #Remove any remaining backup files from the previous installation if present:
    Set-Location "$env:TUXDIR\bin"
    $PBKBackupFiles = Get-ChildItem | Where-Object {$_.Extension -like "*pbk*"} | Select -ExpandProperty Name
    if ($PBKBackupFiles -ne $null)
    {
        foreach ($File in $PBKBackupFiles)
        {
            Remove-Item $File -Force -ErrorAction Stop
        }
        Add-Content $LogLocation "Tuxedo PBK backup files removed"
    }

    #Copy the new RP installer to a temporary directory on the server:
    if ((Test-Path "$env:TUXDIR\RPTempInstaller") -eq $false)
    {
        New-Item -ItemType Directory -Path "$env:TUXDIR\RPTempInstaller" | Out-Null
    }
    else
    {
        Remove-Item "$env:TUXDIR\RPTempInstaller" -Recurse -Force
        if ($?)
        {
            Add-Content $LogLocation "Old RPTempInstall directory successfully removed from $Server"
        }
        else
        {
            Add-Content $LogLocation "ERROR - Could not remove old RPTempInstall directory on $Server"
            SendPackageInstallLog
            exit
        }
    }
    Copy-Item -Path "$TuxRPDir\*" -Destination "$env:TUXDIR\RPTempInstaller\"
    if ($?)
    {
        Add-Content $LogLocation "Copy of new RP installer completed successfully on $Server"
    }
    else
    {
        Add-Content $LogLocation "ERROR - New RP installer could NOT be copied to $Server"
        SendPackageInstallLog
        exit
    }

    #Call the Tuxedo installer:
    Set-Location "$env:TUXDIR\RPTempInstaller"
    $InstallerName = Get-ChildItem | Where-Object {$_.Name -like "*RP*"} | Select -ExpandProperty Name
    $InstallArguments =  "-i silent"
    Start-Process $InstallerName -ArgumentList $InstallArguments -Wait -Verb runas
    Add-Content $LogLocation "New RP install starting on $Server..."
    Start-Sleep -Seconds 90

    #Remove the temporary directory:
    Set-Location F:\
    Remove-Item "$env:TUXDIR\RPTempInstaller" -Recurse -Force

    #Check to see that the RP installed correctly:
    $InstallLog = Test-Path "C:\RPinst_status"
    if ($InstallLog -eq $True)
    {
        $RPInstalled = Get-Content "C:\RPinst_status" | Select-String -SimpleMatch "SUCCESSFULLY" -Quiet
        if ($RPInstalled -eq $true)
        {
            Add-Content $LogLocation "Tuxedo RP installed successfully!"
        }
        else
        {
            Add-Content $LogLocation "ERROR - Tuxedo RP not installed successfully!"
        }
    }
    else
    {
        Add-Content $LogLocation "WARNING - No install log written - please verify install success manually!"
    }

    #Restart the server for the update to take effect:
    Add-Content $LogLocation "RP install attempt complete, restarting $Server"
    SendPackageInstallLog
    Restart-Computer -Force
}
else
{
    #Copy the new RP installer to a temporary directory on the server:
    if ((Test-Path "$env:TUXDIR\RPTempInstaller") -eq $false)
    {
        New-Item -ItemType Directory -Path "$env:TUXDIR\RPTempInstaller" | Out-Null
    }
    else
    {
        Remove-Item "$env:TUXDIR\RPTempInstaller" -Recurse -Force
        if ($?)
        {
            Add-Content $LogLocation "Old RPTempInstall directory successfully removed from $Server"
        }
        else
        {
            Add-Content $LogLocation "ERROR - Could not remove old RPTempInstall directory on $Server"
            SendPackageInstallLog
            exit
        }
    }
    Copy-Item -Path "$TuxRPDir\*" -Destination "$env:TUXDIR\RPTempInstaller\"
    if ($?)
    {
        Add-Content $LogLocation "Copy of new RP installer completed successfully on $Server"
    }
    else
    {
        Add-Content $LogLocation "ERROR - New RP installer could NOT be copied to $Server"
        SendPackageInstallLog
        exit
    }

    #Call the Tuxedo installer:
    Set-Location "$env:TUXDIR\RPTempInstaller"
    $InstallerName = Get-ChildItem | Where-Object {$_.Name -like "*RP*"} | Select -ExpandProperty Name
    $InstallArguments =  "-i silent"
    Start-Process $InstallerName -ArgumentList $InstallArguments -Wait -Verb runas
    Add-Content $LogLocation "New RP install starting on $Server..."
    Start-Sleep -Seconds 90

    #Remove the temporary directory:
    Set-Location F:\
    Remove-Item "$env:TUXDIR\RPTempInstaller" -Recurse -Force

    #Check to see that the RP installed correctly:
    $InstallLog = Test-Path "C:\RPinst_status"
    if ($InstallLog -eq $True)
    {
        $RPInstalled = Get-Content "C:\RPinst_status" | Select-String -SimpleMatch "SUCCESSFULLY" -Quiet
        if ($RPInstalled -eq $true)
        {
            Add-Content $LogLocation "Tuxedo RP installed successfully!"
        }
        else
        {
            Add-Content $LogLocation "ERROR - Tuxedo RP not installed successfully!"
        }
    }
    else
    {
        Add-Content $LogLocation "WARNING - No install log written - please verify install success manually!"
    }

    #Restart the server for the update to take effect:
    Add-Content $LogLocation "RP install attempt complete, restarting $Server"
    SendPackageInstallLog
    Restart-Computer -Force
}
