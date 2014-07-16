<#
.SYNOPSIS
Install-WebLogicUpdates will install a PSU for WebLogic automatically.

.INPUTS
None - the script contains all information required to run.

.OUTPUTS
Log files are written to the patch installer directory for removal and installation. One is called remove and one is called install.

.EXAMPLES
.\Install-WebLogicUpdates.ps1

.NOTES
Ensure the proper patch is in the location where the new patch files are downloaded from.  All files must be copied.
#>

#Get the current computer name:
$WebServer = $env:COMPUTERNAME
#Set the log file location:
$LogLocation = "F:\WebLogicUpgrade.txt"
if ((Test-Path $LogLocation) -eq $True)
{
    Remove-Item $LogLocation -Force
}
#Create the e-mail function for the installation log:
function SendPackageInstallLog
{
    Send-MailMessage -From "cs-sccm@example.com" -To "you@example.com" -Subject "WebLogic Update Package Install Log from $WebServer" -Body "Attached is the SCCM WebLogic Update package installation log for $WebServer." -Attachments $LogLocation -SmtpServer "smtp.example.com"
}

#Figure out the PS Domain name based on the computer name:
switch -Wildcard ($WebServer) {
    "*dmo*" {$PSDomain = "CSDMO"}
    "*dev*" {$PSDomain = "CSDEV"}
    "*tst*" {$PSDomain = "CSTST"}
    "*stg*" {$PSDomain = "CSSTG"}
    "*prd*" {$PSDomain = "CSPRD"}
    "*rpt*" {$PSDomain = "CSRPT"}
    "*perfpt*" {$PSDomain = "PTPRD"}
    "*ldt*" {$PSDomain = "CSLDT"}
}

#Stop the WebLogic server:
$PIAService = Get-Service | Where-Object {$_.Name -like "*$PSDomain-PIA*"}
if ($PIAService)
{
    Stop-Service -InputObject $PIAService -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    $PIAService.WaitForStatus('Stopped','00:01:30')
    if ($PIAService.Status -eq "Stopped")
    {
        Add-Content $LogLocation "PIA service successfully stopped on $WebServer"
    }
    else
    {
        Add-Content $LogLocation "ERROR - PIA service did NOT successfully stop on $WebServer"
        SendPackageInstallLog
        exit
    }
}

#Change to the location of the current patch to get the patch name to remove:
if ((Test-Path "F:\Oracle\Middleware\utils\bsu\cache_dir") -eq $true)
{
    Set-Location "F:\Oracle\Middleware\utils\bsu\cache_dir"
}
else
{
    Add-Content $LogLocation "bsu Directory does not exist, creating..."
    New-Item "F:\Oracle\Middleware\utils\bsu\cache_dir" -ItemType Directory
    Set-Location "F:\Oracle\Middleware\utils\bsu\cache_dir"
}
if ((Test-Path ".\*.jar") -eq $true)
{
    $OldPatch = Get-ChildItem | Where-Object {$_.Name -like "*.jar"} | Select-Object -ExpandProperty BaseName
    #Change to the location of the patch installer and remove the old patch:
    Set-Location "F:\Oracle\Middleware\utils\bsu"
    Invoke-Expression ".\bsu.cmd -prod_dir=F:\Oracle\Middleware\wlserver_10.3 -patchlist=$OldPatch -verbose -remove -log=remove"
    Add-Content $LogLocation "Uninstalling old WebLogic patch..."
}
else
{
    Add-Content $LogLocation "No WebLogic patch is currently installed!"
}

#Remove the old patch files from the cache location:
Add-Content $LogLocation "Removing old WebLogic patch files..."
Set-Location "F:\Oracle\Middleware\utils\bsu\cache_dir"
Remove-Item * -Force -ErrorAction SilentlyContinue
if ((Get-ChildItem -Recurse) -eq $null)
{
    Add-Content $LogLocation "Old WebLogic patch files deleted..."
    #Copy the new patch files from a network location:
    Copy-Item "\\path.to.your\SoftwareShare\WebLogic\PSU\*" .
    if ((Test-Path ".\*.jar") -eq $true)
    {
        $NewPatch = Get-ChildItem | Where-Object {$_.Name -like "*.jar"} | Select-Object -ExpandProperty BaseName
        Add-Content $LogLocation "Patch copy completed successfully!"
    }
    else
    {
        Add-Content $LogLocation "ERROR - Patch copy did not complete successfully, exiting..."
        SendPackageInstallLog
        exit
    }
}
else
{
    Add-Content $LogLocation "ERROR - Old WebLogic patch files could not be deleted, exiting..."
    SendPackageInstallLog
    exit
}

#Change to the location of the patch installer and install the new patch:
Set-Location "F:\Oracle\Middleware\utils\bsu"
Invoke-Expression ".\bsu.cmd -prod_dir=F:\Oracle\Middleware\wlserver_10.3 -patchlist=$NewPatch -verbose -install -log=install"

#Check to see the patch installed correctly:
if ((Test-Path "F:\Oracle\Middleware\utils\bsu\cache_dir\README.txt") -eq $true)
{
    $NewVersionMatch = Get-Content F:\Oracle\Middleware\utils\bsu\cache_dir\README.txt | Select-String -SimpleMatch "PATCH_ID -"
    $NewVersionString = $NewVersionMatch.ToString()
    $NewVersion = $NewVersionString.Replace("PATCH_ID - ","")
    $NewVersionCheck = F:\Oracle\Middleware\utils\bsu\bsu.cmd -view -status=applied -prod_dir=F:\Oracle\Middleware\wlserver_10.3 | Select-String -SimpleMatch $NewVersion -Quiet
    if ($NewVersionCheck -eq $true)
    {
        Add-Content $LogLocation "WebLogic Patch $NewVersion applied successfully!"
    }
    else
    {
        Add-Content $LogLocation "ERROR - WebLogic Patch $NewVersion not applied successfully - please investigate!"
        SendPackageInstallLog
        exit
    }
}
else
{
    Add-Content $LogLocation "Current patch level could not be determined - update may have failed.  Please investigate!"
    SendPackageInstallLog
    exit
}

#Restart the WebLogic server:
if ($PIAService)
{
    Start-Service -InputObject $PIAService -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    $PIAService.WaitForStatus('Running','00:01:30')
    if ($PIAService.Status -eq "Running")
    {
        Add-Content $LogLocation "PIA service successfully started on $WebServer"
    }
    else
    {
        Add-Content $LogLocation "ERROR - PIA service did NOT successfully start on $WebServer, check for issues!"
        SendPackageInstallLog
    }
}
#Send the installation log:
SendPackageInstallLog
