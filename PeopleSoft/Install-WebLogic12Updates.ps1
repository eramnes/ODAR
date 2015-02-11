<#
.SYNOPSIS
Install-WebLogicUpdates will silently install the Oracle WebLogic server on a machine.

.INPUTS
None - the script contains all information required to run.

.OUTPUTS
Messages are logged to a file and sent via email.

.EXAMPLES
.\Install-WebLogicUpdates.ps1

.NOTES
The folder where the patch is stored must be named as the patch number.
#>

#Set the script variables:
$PatchLocation = "\\path.to.your\SoftwareShare\WLS12\patch"
$PatchID = Get-ChildItem $PatchLocation | Where-Object {$_.PSIsContainer -eq $true} | Select -ExpandProperty Name
$env:ORACLE_HOME = "F:\Oracle\Middleware\WebLogic"
$env:JAVA_HOME = "F:\Java"

#Set log location:
$LogLocation = "F:\OPatchInstall.txt"
if ((Test-Path $LogLocation) -eq $True)
{
    Remove-Item $LogLocation -Force
}

#Create e-mail notification function:
function SendPackageInstallLog
{
    $MailBody = Get-Content $LogLocation | Out-String
    Send-MailMessage -From "sccm@eample.com" -To "you@example.com" -Subject "WebLogic OPatch Install Attempt On $env:ComputerName" -Body "Below are the results of the OPatch install attempt: `n`n$MailBody" -SmtpServer "smtp.example.com"
}

#Copy patch files to machine - 260 character path length issue, needs robocopy:
$ArgumentList = "$PatchLocation F:\opatchtemp *.* /e"
Start-Process robocopy -ArgumentList $ArgumentList -Wait
if ($?)
{
    Add-Content $LogLocation "SUCCESS: Copied patch files to machine..."
}
else
{
    Add-Content $LogLocation "ERROR: Could not copy patch files to machine, exiting..."
}

#Apply the patch using OPatch:
try
{
    Set-Location "F:\opatchtemp\$PatchID"
    $OPatchArgs = "apply -silent -jdk $env:JAVA_HOME"
    #$OPatchArgs = "rollback -id $PatchID -silent -jdk $env:JAVA_HOME"
    Start-Process "$env:ORACLE_HOME\OPatch\opatch.bat" -ArgumentList $OPatchArgs -Wait
    Add-Content $LogLocation "SUCCESS: Started OPatch installer process..."
}
catch
{
    #TODO: Add operr check to this at some point to get error code info...
    Add-Content $LogLocation "ERROR: Could not apply patch, exiting..."
    SendPackageInstallLog
    exit
}

#Remove patch copy from local machine:
Set-Location "$env:ORACLE_HOME\OPatch"
Remove-Item "F:\opatchtemp" -Recurse -Force

#Check to see the patch installed correctly:
$PatchString = .\opatch.bat lsinventory | Select-String $PatchID | Select -First 1
$PatchCheck = $PatchString | Select-String "applied" -Quiet
if ($PatchCheck -ne $true)
{
    Add-Content $LogLocation "ERROR: Patch $PatchID not applied successfully..."
}
else
{
    Add-Content $LogLocation "SUCCESS: Patch $PatchID applied..."
}

#Send results:
SendPackageInstallLog
