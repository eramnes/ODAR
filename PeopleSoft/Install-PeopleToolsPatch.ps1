<#
.SYNOPSIS
Install-PeopleToolsPatch will install a PeopleTools patch silently on a server.

.INPUTS
None.  The script is self-contained.

.OUTPUTS
Install-PeopleTools does not produce object output.  A log file is written with the script results.
The script log is at $LogLocation and there is a Tools installation log at F:\PSOFT\PT853\PeopleTools_InstallLog.txt.

.EXAMPLES
.\Install-PeopleToolsPatch.ps1

.NOTES
This script requires quite a while to install over the network.  It can run up to 25-30 minutes.
#>

#Set the script variables:
$LogLocation = "F:\ToolsPatchInstall.txt"
#Check to see if there is a current log file for removal:
if ((Test-Path $LogLocation) -eq $True)
{
    Remove-Item $LogLocation -Force
}

#Function to send results e-mail:
function SendPackageInstallLog
{
    Send-MailMessage -From "cs-sccm@example.com" -To "you@example.com" -Subject "Tools Version Update Package Install Log from $env:ComputerName" -Body "Attached is the PeopleTools update package installation log for $env:ComputerName." -Attachments $LogLocation -SmtpServer "smtp.example.com"
}

#Stop services before attempting the Tools update:
$PeopleSoftService = Get-Service | Where-Object {$_.Name -like "*PeopleSoft*"}
if ($PeopleSoftService)
{
    Stop-Service -InputObject $PeopleSoftService -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    $PeopleSoftService.WaitForStatus('Stopped','00:03:00')
    if ($PeopleSoftService.Status -eq "Stopped")
    {
        Add-Content $LogLocation "SUCCESS: PeopleSoft services successfully stopped on $env:ComputerName"
    }
    else
    {
        Add-Content $LogLocation "ERROR: PeopleSoft services did NOT successfully stop on $env:ComputerName, exiting"
        SendPackageInstallLog
        exit
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
            Add-Content $LogLocation "SUCCESS: TListen service stopped on $env:ComputerName"
        }
        else
        {
            Add-Content $LogLocation "ERROR: TListen service did NOT stop on $env:ComputerName, exiting!"
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
        Add-Content $LogLocation "SUCCESS: Tuxedo service stopped on $env:ComputerName"
    }
    else
    {
        Write-Host "ERROR: Tuxedo service did NOT successfully stop on $env:ComputerName, exiting"
        SendPackageInstallLog
        exit
    }
}
$OEMService = Get-Service | Where-Object {$_.Name -like "*ConfigurationManager*"}
if ($OEMService)
{
    Stop-Service -InputObject $OEMService -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    $EMService.WaitForStatus('Stopped','00:03:00')
    if ($OEMService.Status -eq "Stopped")
    {
        Add-Content $LogLocation "SUCCESS: OEM service stopped on $env:ComputerName"
    }
    else
    {
        Add-Content $LogLocation "ERROR: OEM service did NOT stop on $env:ComputerName, exiting"
        SendPackageInstallLog
        exit
    }
}

#Get the location of the installer executable:
$InstallExecutable = Get-ChildItem "\\path.to.your\SoftwareShare\PeopleTools\patch\Disk1\InstData\" | Where-Object {$_.Name -like "*.exe*"} | Select -ExpandProperty PSPath
#Set the arguments to the installer:
$InstallArguments =  "-f installer.properties"
#Start the installer with the unattended installation file:
$StartTime = Get-Date
Add-Content $LogLocation "INFO: PeopleTools patch install process started on $env:ComputerName at $StartTime"
Start-Process $InstallExecutable -ArgumentList $InstallArguments -Wait -Verb runas
$StopTime = Get-Date
Add-Content $LogLocation "INFO: PeopleTools patch install attempt completed on $env:ComputerName at $StopTime"

#Copy the new PIA installer to the PIA package installer directory for deployment:
Copy-Item -Path "\\path.to.your\SoftwareShare\PIA\InstData\installer.properties" -Destination "\\path.to.your\SoftwareShare\PIA\"
$ConfigCopyCheck = Test-Path "\\path.to.your\SoftwareShare\PIA\installer.properties"
if ($ConfigCopyCheck -eq $true)
{
    Add-Content $LogLocation "SUCCESS: installer.properties archived!"
}
else
{
    Add-Content $LogLocation "ERROR: installer.properties not archived!"
    SendPackageInstallLog
    exit
}

#Remove old PIA installer...maybe autoarchive this later?
$OldDirectories = Get-ChildItem "\\path.to.your\SoftwareShare\PIA" | Where-Object {($_.PSIsContainer -eq $true) -and ($_.Name -notmatch "version")}
foreach ($Directory in $OldDirectories)
{
    $FullPath = $Directory.FullName
    Remove-Item $Directory.FullName -Recurse -Force
    if ($?)
    {
        Add-Content $LogLocation "SUCCESS: $FullPath deleted!"
    }
    else
    {
        Add-Content $LogLocation "ERROR: $FullPath not deleted, exiting!"
        SendPackageInstallLog
        exit
    }
}

#Copy new PIA installer:
$NewDirectories = Get-ChildItem "F:\PSOFT\PT853\setup\PsMpPIAInstall" | Where-Object {$_.PSIsContainer -eq $true}
foreach ($Directory in $NewDirectories)
{
    $Path = $Directory.Name
    Copy-Item -Path $Directory.FullName -Destination "\\path.to.your\SoftwareShare\PIA" -Recurse
    $CopyCheck = Test-Path "\\path.to.your\SoftwareShare\PIA\$Path"
    if ($CopyCheck -eq $true)
    {
        Add-Content $LogLocation "SUCCESS: $Path copied to server!"
    }
    else
    {
        Add-Content $LogLocation "ERROR: $Path not copied to server, exiting!"
        SendPackageInstallLog
        exit
    }
}

#Restore configuration file to proper location:
Copy-Item -Path "\\path.to.your\SoftwareShare\PIA\installer.properties" -Destination "\\path.to.your\SoftwareShare\PIA\InstData\installer.properties"
$ConfigRestoreCheck = Test-Path "\\path.to.your\SoftwareShare\PIA\InstData\installer.properties"
if ($ConfigRestoreCheck -eq $true)
{
    Add-Content $LogLocation "SUCCESS: installer.properties restored!"
    #Remove archive copy of installer.properties:
    Remove-Item "\\path.to.your\SoftwareShare\PIA\installer.properties" -Force
}
else
{
    Add-Content $LogLocation "ERROR: installer.properties not restored, exiting!"
    SendPackageInstallLog
    exit
}

#Remind user to configure installer.properties before using PIA install package:
Add-Content $LogLocation "`nIMPORTANT: Please ensure the installer.properties file is modified for the install type and environment before redeploying PIA install package!"

SendPackageInstallLog
