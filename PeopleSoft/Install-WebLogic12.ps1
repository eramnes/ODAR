<#
.SYNOPSIS
Install-WebLogic will silently install the Oracle WebLogic server on a machine.

.INPUTS
None - the script contains all information required to run.

.OUTPUTS
Messages are printed to the console as the installation progresses.  A log file is created of the installation.

.EXAMPLES
.\Install-WebLogic.ps1

.NOTES
The location where the installer files and answer files are located must be accessible over the network on the machine
where WebLogic is to be installed.
#>

#Set the location of the installer and the answer file:
$InstallerLocation = "\\path.to.your\SoftwareShare\WLS12"
#Set location of OUI Inventory directory:
$OUIInventoryDir = "F:\Oracle\Inventory"
#Set Java Home:
$env:JAVA_HOME = "F:\Java"
#Set log location:
$LogLocation = "F:\WLS12Install.txt"
if ((Test-Path $LogLocation) -eq $True)
{
    Remove-Item $LogLocation -Force
}

#Create e-mail notification function:
function SendPackageInstallLog
{
    $MailBody = Get-Content $LogLocation | Out-String
    Send-MailMessage -From "sccm@example.com" -To "you@example.com" -Subject "WebLogic Install Attempt On $env:ComputerName" -Body "Below are the results of the WebLogic install attempt: `n`n$MailBody" -SmtpServer "smtp.example.com"
}

#Create required registry key for OUI configuration:
try
{
    New-Item -Path HKLM:\Software\Oracle\
    New-ItemProperty "HKLM:\Software\Oracle\" -Name "inst_loc" -Value $OUIInventoryDir
    Add-Content $LogLocation "SUCCESS: Created Oracle Inventory registry key..."
}
catch
{
    Add-Content $LogLocation "WARN: Could not create registry key - does key already exist?"
}

try
{
    #Copy the installer and answer files to the local system:
    Copy-Item -Path "$InstallerLocation\weblogic.jar" -Destination "F:\weblogic.jar"
    Copy-Item -Path "$InstallerLocation\silent.rsp" -Destination "F:\silent.rsp"
    Add-Content $LogLocation "SUCCESS: Copied installer files to machine..."
}
catch
{
    Add-Content $LogLocation "ERROR: Could not copy installer files, exiting..."
    SendPackageInstallLog
    exit
}

#Call the Java executable to install WebLogic silently using the answer file, writing a log of the install:
Set-Location $env:JAVA_HOME\bin
.\java.exe -jar F:\weblogic.jar -silent -response F:\silent.rsp -logFile F:\WLS12Inst.log -waitforcompletion
Add-Content $LogLocation "SUCCESS: Started WebLogic installer on $env:ComputerName..."

#Remove the installer and answer file to reclaim drive space:
try
{
    Remove-Item "F:\weblogic.jar" -Force
    Remove-Item "F:\silent.rsp" -Force
    Add-Content $LogLocation "SUCCESS: Removed patch files from machine..."
}
catch
{
    Add-Content $LogLocation "WARN: Failed to remove patch files from machine..."
}

SendPackageInstallLog
