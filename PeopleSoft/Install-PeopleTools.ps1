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
$LogLocation = "F:\ToolsInstall.txt"
#Check to see if there is a current log file for removal:
if ((Test-Path $LogLocation) -eq $True)
{
    Remove-Item $LogLocation -Force
}

#Function to send results e-mail:
function SendPackageInstallLog
{
    Send-MailMessage -From "cs-sccm@example.com" -To "you@example.com" -Subject "PeopleTools Package Install Log from $env:ComputerName" -Body "Attached is the PeopleTools installation log for $env:ComputerName." -Attachments $LogLocation -SmtpServer "smtp.example.com"
}

#Get the location of the installer executable:
$InstallExecutable = Get-ChildItem "\\path.to.your\SoftwareShare\PeopleTools\Disk1\InstData\" | Where-Object {$_.Name -like "*.exe*"} | Select -ExpandProperty PSPath
#Set the arguments to the installer:
$InstallArguments =  "-f installer.properties"
#Start the installer with the unattended installation file:
$StartTime = Get-Date
Add-Content $LogLocation "INFO: PeopleTools install process started on $env:ComputerName at $StartTime"
Start-Process $InstallExecutable -ArgumentList $InstallArguments -Wait -Verb runas
$StopTime = Get-Date
Add-Content $LogLocation "INFO: PeopleTools install attempt completed on $env:ComputerName at $StopTime"

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
Add-Content $LogLocation "`nIMPORTANT: Please ensure the installer.properties file is modified for the install type and environment before deploying PIA install package!"

SendPackageInstallLog
